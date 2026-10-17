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

    json = {'xml_config' => xml_config.force_encoding('UTF-8'), 'hb2_env' => hb2_env}.to_json.force_encoding('UTF-8')
    self.outputs << json.to_s
  end

  # Returns binding for erb files (access to variables in this classes scope)
  # @return binding
  def get_binding
    binding
  end
end
