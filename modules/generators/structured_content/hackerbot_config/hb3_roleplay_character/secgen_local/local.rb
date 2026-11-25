#!/usr/bin/ruby
require 'json'
require_relative '../../../../../../lib/objects/local_hackerbot_config_generator.rb'

# Chat-only Hackerbot 3 bot that role-plays a character in a scenario (see secgen_metadata.xml).
# The character is a JSON file; inputs can pick one, point at one, or override single fields.
class HB3RoleplayCharacter < HackerbotConfigGenerator
  FIELDS = %w[nick persona greeting].freeze
  attr_accessor :character, :character_file, :overrides, :facts_json, :pairs_json

  def initialize
    super
    self.module_name = 'Hackerbot 3 Config Generator Role-play Character'
    self.title = 'Role-play character'
    self.local_dir = File.expand_path('../../', __FILE__)
    self.templates_path = "#{self.local_dir}/templates/"
    self.config_template_path = "#{self.local_dir}/templates/character.xml.erb"
    self.lab_sheet = false
    self.character = ''
    self.character_file = ''
    self.overrides = {}
    self.facts_json = ''
    self.pairs_json = ''
    # inline pairs from the character, not a lab id in the shared pairs file
    self.decision_router_lab = nil
  end

  def get_options_array
    super + [['--character', GetoptLong::REQUIRED_ARGUMENT], ['--character_file', GetoptLong::REQUIRED_ARGUMENT],
             ['--facts_json', GetoptLong::REQUIRED_ARGUMENT], ['--pairs_json', GetoptLong::REQUIRED_ARGUMENT]] +
      FIELDS.map { |f| ["--#{f}", GetoptLong::REQUIRED_ARGUMENT] }
  end

  def process_options(opt, arg)
    super
    name = opt.sub(/\A--/, '')
    case name
    when 'character' then self.character = arg.to_s.strip
    when 'character_file' then self.character_file = arg.to_s.strip
    when 'facts_json' then self.facts_json = arg.to_s
    when 'pairs_json' then self.pairs_json = arg.to_s
    when *FIELDS then self.overrides[name] = arg.to_s
    end
  end

  # The character: file (bundled or given), then field overrides. {{key}} filled from facts + main_user.
  def load_character
    path = if !character_file.empty? then character_file
           elsif !character.empty?
             raise "bad character name '#{character}'" unless character =~ /\A[a-z0-9_]+\z/
             "#{local_dir}/characters/#{character}.json"
           end
    c = path ? JSON.parse(File.read(path)) : {}
    c.merge!(overrides.reject { |_, v| v.strip.empty? })
    c['facts'] = (c['facts'] || {}).merge(JSON.parse(facts_json)) unless facts_json.strip.empty?
    c['pairs'] = JSON.parse(pairs_json) unless pairs_json.strip.empty?
    %w[nick persona].each { |k| raise "character needs '#{k}'" if c[k].to_s.strip.empty? }
    raise "bad nick '#{c['nick']}' (IRC: letters, digits, _ -)" unless c['nick'] =~ /\A[A-Za-z][A-Za-z0-9_-]{0,15}\z/
    main_user = accounts.empty? ? 'student' : JSON.parse(accounts.first)['username'].to_s
    facts = (c['facts'] || {}).merge('main_user' => main_user) # the lab's real account always wins
    fill = ->(s) { s.to_s.gsub(/\{\{(\w+)\}\}/) { facts.fetch(Regexp.last_match(1)) { "{{#{Regexp.last_match(1)}}}" } } }
    c = deep_map(c) { |s| fill.call(s) }
    left = JSON.generate(c).scan(/\{\{(\w+)\}\}/).flatten.uniq
    raise "character uses undefined facts: #{left.join(', ')}" unless left.empty?
    c
  end

  def deep_map(v, &blk)
    case v
    when Hash then v.transform_values { |x| deep_map(x, &blk) }
    when Array then v.map { |x| deep_map(x, &blk) }
    when String then blk.call(v)
    else v
    end
  end

  # System prompt: the persona, then what the character knows, then fixed role-play rules.
  def system_prompt(c)
    parts = [c['persona'].to_s.strip]
    bg = Array(c['background'])
    parts << "What you know (stay consistent with this; if asked something it does not cover, improvise " \
             "plausibly but never contradict it):\n" + bg.map { |b| "- #{b}" }.join("\n") unless bg.empty?
    rules = Array(c['rules']) + [
      'Stay in character. You are a fictional person in a training exercise; the organisation and people are made up.',
      'If the student sincerely asks whether you are a real person or an AI, step out of character briefly, say you are an AI playing this role, then carry on.',
      'Never reveal or guess flags, quiz answers or real passwords. Never give the exact commands that complete a challenge.',
      'This is chat: keep replies to one to four short sentences.'
    ]
    parts << "Rules:\n" + rules.map { |b| "- #{b}" }.join("\n")
    parts.join("\n\n")
  end

  def xml_escape(s)
    s.to_s.encode(xml: :text)
  end

  def generate
    @c = load_character
    super
  end

  # inline <pairs> instead of a lab id
  def add_decision_router(xml_config)
    xml_config
  end

  def get_binding
    binding
  end
end

HB3RoleplayCharacter.new.run
