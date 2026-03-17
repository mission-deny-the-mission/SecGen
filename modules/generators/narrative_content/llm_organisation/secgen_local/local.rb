#!/usr/bin/ruby
require 'json'
require_relative '../../../../../lib/objects/local_string_encoder.rb'
require_relative '../../lib/llm_narrative_generator.rb'

class LlmOrganisationGeneratorLocal < StringEncoder
  attr_accessor :industry
  attr_accessor :theme
  attr_accessor :seed
  attr_accessor :llm_provider
  attr_accessor :llm_model
  attr_accessor :business_name
  attr_accessor :num_employees

  def initialize
    super
    self.module_name = 'LLM Organisation Generator'
    self.industry = ''
    self.theme = 'investigation'
    self.seed = nil
    self.llm_provider = ''
    self.llm_model = ''
    self.business_name = ''
    self.num_employees = '5'
  end

  def encode_all
    options = {
      'seed' => self.seed,
      'model' => self.llm_model.empty? ? nil : self.llm_model,
      'theme' => self.theme,
      'content_type' => 'organisation'
    }

    generator = LlmOrganisationNarrativeGenerator.new(options)
    content = generator.generate_content({
      'industry' => self.industry,
      'business_name' => self.business_name,
      'num_employees' => self.num_employees
    })

    self.outputs << content
  end

  def get_options_array
    super + [['--industry', GetoptLong::REQUIRED_ARGUMENT],
             ['--theme', GetoptLong::REQUIRED_ARGUMENT],
             ['--seed', GetoptLong::OPTIONAL_ARGUMENT],
             ['--llm_provider', GetoptLong::OPTIONAL_ARGUMENT],
             ['--llm_model', GetoptLong::OPTIONAL_ARGUMENT],
             ['--business_name', GetoptLong::OPTIONAL_ARGUMENT],
             ['--num_employees', GetoptLong::OPTIONAL_ARGUMENT]]
  end

  def process_options(opt, arg)
    super
    case opt
    when '--industry'
      self.industry = arg
    when '--theme'
      self.theme = arg
    when '--seed'
      self.seed = arg.to_i
    when '--llm_provider'
      self.llm_provider = arg
    when '--llm_model'
      self.llm_model = arg
    when '--business_name'
      self.business_name = arg
    when '--num_employees'
      self.num_employees = arg
    end
  end
end

# Narrative generator subclass for organisation generation
class LlmOrganisationNarrativeGenerator < LlmNarrativeGenerator
  def build_prompt(extra_variables = {})
    vars = template_variables(extra_variables)
    prompt = LlmPromptTemplate.load_and_render('organisation', vars)
    append_cybok_alignment(prompt)
  end

  def parse_response(raw_content)
    # Extract JSON from response (LLM may include surrounding text)
    json_match = raw_content.match(/\{[\s\S]*\}/)
    if json_match
      json_str = json_match[0]
      # Validate it's parseable JSON
      parsed = JSON.parse(json_str)
      # Ensure required fields
      required = %w[business_name business_motto domain industry manager employees]
      missing = required - parsed.keys
      unless missing.empty?
        raise "Generated organisation missing required fields: #{missing.join(', ')}"
      end
      # Ensure passwords are empty for security
      parsed['manager']['password'] = '' if parsed['manager']
      if parsed['employees'].is_a?(Array)
        parsed['employees'].each { |e| e['password'] = '' }
      end
      parsed.to_json
    else
      raise "LLM did not return valid JSON for organisation generation"
    end
  end
end

LlmOrganisationGeneratorLocal.new.run
