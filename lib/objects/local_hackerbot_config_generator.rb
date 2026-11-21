#!/usr/bin/ruby
require_relative 'local_string_generator.rb'
require 'erb'
require 'fileutils'

class HackerbotConfigGenerator < StringGenerator
  attr_accessor :accounts
  attr_accessor :flags
  attr_accessor :root_password
  attr_accessor :title

  attr_accessor :local_dir
  attr_accessor :templates_path
  attr_accessor :config_template_path
  # No longer rendered (lab sheets are not hosted from the bot any more), but the hb2_* generators
  # still set it, and without the accessor they die with NoMethodError before writing any config.
  attr_accessor :html_template_path
  # Hackerbot 3: when set, a <decision_router> naming this lab (a lab id in the bot's
  # decision/pairs/labhelp_pairs.json) is added to the rendered bot XML, so an hb3_* generator can
  # reuse an hb2_* template unchanged. Hackerbot 2 ignores the element.
  attr_accessor :decision_router_lab
  def initialize
    super
    self.module_name = 'Hackerbot Config Generator'
    self.title = ''
    self.accounts = []
    self.flags = []
    self.root_password = ''

    self.local_dir = File.expand_path('../../', __FILE__)
    self.templates_path = "#{self.local_dir}/templates/"
    self.config_template_path = "#{self.local_dir}/templates/integrity_lab.xml.erb"

  end

  def get_options_array
    super + [['--root_password', GetoptLong::REQUIRED_ARGUMENT],
             ['--accounts', GetoptLong::REQUIRED_ARGUMENT],
             ['--flags', GetoptLong::REQUIRED_ARGUMENT]]
  end

  def process_options(opt, arg)
    super
    case opt
      when '--root_password'
        self.root_password << arg;
      when '--accounts'
        self.accounts << arg;
      when '--flags'
        self.flags << arg;
    end
  end

  def generate
    # Print.debug self.accounts.to_s
    xml_template_out = ERB.new(File.read(self.config_template_path), trim_mode: '<>-')
    xml_config = xml_template_out.result(self.get_binding)
    xml_config = add_decision_router(xml_config) if self.decision_router_lab
    # Hackerbot 3 serves its lab sheet from the bot server (hackerbot3 utility, apache on 'port'), as
    # Hackerbot 1 did. The hb2_* generators (no decision_router_lab) keep upstream's externally hosted sheets.
    html_lab_sheet = render_lab_sheet(xml_config) if self.decision_router_lab

    # Lab sheets are hosted externally upstream (HTML generation removed); only the
    # fork's hb2_env (per-bot LLM settings for the hackerbot2 service) is kept.
    hb2_env = {
      'HB2_LLM_PROVIDER'    => ENV['HB2_LLM_PROVIDER'],
      'HB2_LLM_HOST'        => ENV['HB2_LLM_HOST'],
      'HB2_LLM_PORT'        => ENV['HB2_LLM_PORT'],
      'HB2_LLM_MODEL'       => ENV['HB2_LLM_MODEL'],
      'HB2_OPENAI_API_KEY'  => ENV['HB2_OPENAI_API_KEY'],
      'HB2_OPENAI_BASE_URL' => ENV['HB2_OPENAI_BASE_URL'],
      'HB2_EMBEDDING_MODEL' => ENV['HB2_EMBEDDING_MODEL'],
    }.compact

    # Hackerbot 3: decision router servers. Ignored by the hackerbot2 utility; the hackerbot3 utility writes
    # them (with hb2_env, which carries the LLM fallback) into /opt/hackerbot3/config/hb3.env.
    hb3_env = {
      'HB3_DECISION_URL'       => ENV['HB3_DECISION_URL'],
      'HB3_DECISION_MODEL'     => ENV['HB3_DECISION_MODEL'],
      'HB3_DECISION_STRATEGY'  => ENV['HB3_DECISION_STRATEGY'],
      'HB3_DECISION_THRESHOLD' => ENV['HB3_DECISION_THRESHOLD'],
      'HB3_EMBED_URL'          => ENV['HB3_EMBED_URL'],
      'HB3_EMBED_MODEL'        => ENV['HB3_EMBED_MODEL'],
      'HB3_API_KEY'            => ENV['HB3_API_KEY'],
    }.compact

    out = {'xml_config' => xml_config.force_encoding('UTF-8'), 'hb2_env' => hb2_env, 'hb3_env' => hb3_env}
    out['html_lab_sheet'] = html_lab_sheet.force_encoding('UTF-8') if html_lab_sheet
    json = out.to_json.force_encoding('UTF-8')
    self.outputs << json.to_s
  end

  # Lab sheet markdown from the rendered bot XML: the intro tutorial, each attack's tutorial snippets and a
  # challenge box, then the footer (restored from Hackerbot 1's generate_lab_sheet).
  def lab_sheet_markdown(xml_config)
    require 'nokogiri'
    doc = Nokogiri::XML(xml_config)
    doc.remove_namespaces!
    hackerbot = doc.xpath('/hackerbot')
    name = hackerbot.xpath('name').first.content
    md = "#{hackerbot.xpath('tutorial_info/tutorial').first&.content}\n"
    doc.xpath('//attack').each_with_index do |attack, index|
      attack.xpath('tutorial').each { |snippet| md += snippet.content + "\n" }
      md += "#### #{name} Attack ##{index + 1}\n"
      md += "Use what you have learned to complete the bot's challenge. You can skip the bot to here, by saying '**goto #{index + 1}**'\n\n"
      md += "> #{name}: \"#{attack.xpath('prompt').first.content}\" \n\n"
      md += "Do any necessary preparation, then when you are ready for the bot to complete the action/attack, ==say 'ready'==\n\n"
      md += "There is a quiz to complete. Once Hackerbot asks you the question you can =='answer *YOURANSWER*'==\n\n" if attack.xpath('quiz').size > 0
      md += "Don't forget to ==save and submit any flags!==\n\n"
    end
    md + "#{hackerbot.xpath('tutorial_info/footer').first&.content}\n"
  rescue StandardError => e
    abort "Failed to generate lab sheet: #{e.message}"
  end

  # Full HTML page: markdown rendered with redcarpet into the generator's labsheet.html.erb
  # (which reads html_rendered / html_TOC_rendered), assets from the hackerbot3 utility's files/www.
  def render_lab_sheet(xml_config)
    require 'redcarpet'
    md = lab_sheet_markdown(xml_config)
    body = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(prettify: true, hard_wrap: true, with_toc_data: true),
                                   footnotes: true, fenced_code_blocks: true, no_intra_emphasis: true, autolink: true,
                                   highlight: true, lax_spacing: true, tables: true)
    @html_rendered = body.render(md).force_encoding('UTF-8')
    @html_TOC_rendered = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC.new).render(md).force_encoding('UTF-8')
    template = "#{self.templates_path}labsheet.html.erb"
    raise "no lab sheet template at #{template}" unless File.exist?(template)
    ERB.new(File.read(template), trim_mode: '<>-').result(self.get_binding)
  end
  attr_reader :html_rendered, :html_TOC_rendered

  # Insert <decision_router> straight after the bot's top-level <name> (first </name> in the file).
  def add_decision_router(xml_config)
    block = "\n  <!-- Hackerbot 3 canned-response decision router (servers come from HB3_* in hb3.env) -->\n" \
            "  <decision_router>\n    <enabled>true</enabled>\n    <lab>#{self.decision_router_lab}</lab>\n  </decision_router>\n"
    raise "no </name> in rendered bot XML; cannot add <decision_router>" unless xml_config.include?('</name>')
    xml_config.sub('</name>', "</name>\n#{block}")
  end

  # Returns binding for erb files (access to variables in this classes scope)
  # @return binding
  def get_binding
    binding
  end
end
