#!/usr/bin/ruby
require 'json'
require_relative '../../../../../lib/objects/local_string_encoder.rb'
require_relative '../../lib/llm_narrative_generator.rb'

class LlmHackerbotScriptGeneratorLocal < StringEncoder
  attr_accessor :organisation
  attr_accessor :theme
  attr_accessor :investigation_type
  attr_accessor :seed
  attr_accessor :llm_model
  attr_accessor :evidence_items
  attr_accessor :investigation_steps

  def initialize
    super
    self.module_name = 'LLM Hackerbot Script Generator'
    self.organisation = '{}'
    self.theme = 'investigation'
    self.investigation_type = 'live_analysis'
    self.seed = nil
    self.llm_model = ''
    self.evidence_items = []
    self.investigation_steps = []
  end

  def encode_all
    org_data = JSON.parse(self.organisation) rescue {}

    options = {
      'seed' => self.seed,
      'model' => self.llm_model.empty? ? nil : self.llm_model,
      'theme' => self.theme,
      'organisation' => org_data,
      'content_type' => 'hackerbot_script'
    }

    generator = LlmHackerbotScriptNarrativeGenerator.new(options)
    content = generator.generate_content({
      'investigation_type' => self.investigation_type,
      'evidence_items' => self.evidence_items,
      'investigation_steps' => self.investigation_steps
    })

    self.outputs << content
  end

  def get_options_array
    super + [['--organisation', GetoptLong::REQUIRED_ARGUMENT],
             ['--theme', GetoptLong::REQUIRED_ARGUMENT],
             ['--investigation_type', GetoptLong::OPTIONAL_ARGUMENT],
             ['--seed', GetoptLong::OPTIONAL_ARGUMENT],
             ['--llm_model', GetoptLong::OPTIONAL_ARGUMENT],
             ['--evidence_items', GetoptLong::OPTIONAL_ARGUMENT],
             ['--investigation_steps', GetoptLong::OPTIONAL_ARGUMENT]]
  end

  def process_options(opt, arg)
    super
    case opt
    when '--organisation'
      self.organisation = arg
    when '--theme'
      self.theme = arg
    when '--investigation_type'
      self.investigation_type = arg
    when '--seed'
      self.seed = arg.to_i
    when '--llm_model'
      self.llm_model = arg
    when '--evidence_items'
      self.evidence_items << JSON.parse(arg)
    when '--investigation_steps'
      self.investigation_steps << JSON.parse(arg)
    end
  end
end

class LlmHackerbotScriptNarrativeGenerator < LlmNarrativeGenerator
  def build_prompt(extra_variables = {})
    vars = template_variables(extra_variables)
    prompt = LlmPromptTemplate.load_and_render('hackerbot_script', vars)
    append_cybok_alignment(prompt)
  end
end

LlmHackerbotScriptGeneratorLocal.new.run
