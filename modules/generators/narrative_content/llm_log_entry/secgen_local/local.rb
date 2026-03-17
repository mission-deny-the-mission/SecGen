#!/usr/bin/ruby
require 'json'
require_relative '../../../../../lib/objects/local_string_encoder.rb'
require_relative '../../lib/llm_narrative_generator.rb'

class LlmLogEntryGeneratorLocal < StringEncoder
  attr_accessor :organisation
  attr_accessor :theme
  attr_accessor :log_type
  attr_accessor :system_name
  attr_accessor :time_range
  attr_accessor :seed
  attr_accessor :llm_model

  def initialize
    super
    self.module_name = 'LLM Log Entry Generator'
    self.organisation = '{}'
    self.theme = 'insider_threat'
    self.log_type = 'authentication'
    self.system_name = 'web-server-01'
    self.time_range = '24 hours'
    self.seed = nil
    self.llm_model = ''
  end

  def encode_all
    org_data = JSON.parse(self.organisation) rescue {}

    options = {
      'seed' => self.seed,
      'model' => self.llm_model.empty? ? nil : self.llm_model,
      'theme' => self.theme,
      'organisation' => org_data,
      'content_type' => 'log_entry'
    }

    generator = LlmLogEntryNarrativeGenerator.new(options)
    content = generator.generate_content({
      'log_type' => self.log_type,
      'system_name' => self.system_name,
      'time_range' => self.time_range
    })

    self.outputs << content
  end

  def get_options_array
    super + [['--organisation', GetoptLong::REQUIRED_ARGUMENT],
             ['--theme', GetoptLong::REQUIRED_ARGUMENT],
             ['--log_type', GetoptLong::OPTIONAL_ARGUMENT],
             ['--system_name', GetoptLong::OPTIONAL_ARGUMENT],
             ['--time_range', GetoptLong::OPTIONAL_ARGUMENT],
             ['--seed', GetoptLong::OPTIONAL_ARGUMENT],
             ['--llm_model', GetoptLong::OPTIONAL_ARGUMENT]]
  end

  def process_options(opt, arg)
    super
    case opt
    when '--organisation'
      self.organisation = arg
    when '--theme'
      self.theme = arg
    when '--log_type'
      self.log_type = arg
    when '--system_name'
      self.system_name = arg
    when '--time_range'
      self.time_range = arg
    when '--seed'
      self.seed = arg.to_i
    when '--llm_model'
      self.llm_model = arg
    end
  end
end

class LlmLogEntryNarrativeGenerator < LlmNarrativeGenerator
  def build_prompt(extra_variables = {})
    vars = template_variables(extra_variables)
    prompt = LlmPromptTemplate.load_and_render('log_entry', vars)
    append_cybok_alignment(prompt)
  end
end

LlmLogEntryGeneratorLocal.new.run
