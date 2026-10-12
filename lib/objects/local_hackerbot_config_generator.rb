#!/usr/bin/ruby
require_relative 'local_string_generator.rb'
require_relative 'zeroclaw_config_builder.rb'
require 'erb'
require 'fileutils'

class HackerbotConfigGenerator < StringGenerator
  attr_accessor :accounts
  attr_accessor :flags
  attr_accessor :root_password
  attr_accessor :title
  attr_accessor :zeroclaw_toml_rendered

  attr_accessor :local_dir
  attr_accessor :templates_path
  attr_accessor :config_template_path
  attr_accessor :zeroclaw_config_builder

  def initialize
    super
    self.module_name = 'Hackerbot Config Generator'
    self.title = ''
    self.accounts = []
    self.flags = []
    self.root_password = ''
    self.zeroclaw_toml_rendered = ''
    self.zeroclaw_config_builder = ZeroClawConfigBuilder.new

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

    # Generate ZeroClaw TOML configuration for parallel deployment
    self.zeroclaw_config_builder.accounts = self.accounts
    self.zeroclaw_config_builder.flags = self.flags
    self.zeroclaw_config_builder.root_password = self.root_password
    self.zeroclaw_config_builder.scenario_id = self.title
    
    begin
      self.zeroclaw_toml_rendered = self.zeroclaw_config_builder.generate_toml_config
    rescue => e
      # Use stderr so status/warning text does not contaminate stdout module outputs.
      Print.err "Warning: Failed to generate ZeroClaw config: #{e.message}"
      self.zeroclaw_toml_rendered = "# ZeroClaw config generation failed: #{e.message}"
    end

    # Output both Ruby XML and ZeroClaw TOML configs
    json = {
      'xml_config' => xml_config.force_encoding('UTF-8'),
      'zeroclaw_toml_config' => self.zeroclaw_toml_rendered.force_encoding('UTF-8')
    }.to_json.force_encoding('UTF-8')
    self.outputs << json.to_s
  end

  # Returns binding for erb files (access to variables in this classes scope)
  # @return binding
  def get_binding
    binding
  end
end
