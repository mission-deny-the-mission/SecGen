#!/usr/bin/ruby
require 'json'
require_relative '../../../../../lib/objects/local_string_encoder.rb'
require_relative '../../lib/llm_narrative_generator.rb'

class LlmMemoGeneratorLocal < StringEncoder
  attr_accessor :organisation
  attr_accessor :theme
  attr_accessor :memo_type
  attr_accessor :seed
  attr_accessor :llm_model

  def initialize
    super
    self.module_name = 'LLM Memo Generator'
    self.organisation = '{}'
    self.theme = 'insider_threat'
    self.memo_type = 'policy_announcement'
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
      'content_type' => 'memo'
    }

    generator = LlmMemoNarrativeGenerator.new(options)

    author = org_data['manager'] ? org_data['manager'].merge('role' => 'Manager') : nil
    content = generator.generate_content({
      'memo_type' => self.memo_type,
      'author' => author,
      'recipients' => 'All Staff'
    })

    self.outputs << content
  end

  def get_options_array
    super + [['--organisation', GetoptLong::REQUIRED_ARGUMENT],
             ['--theme', GetoptLong::REQUIRED_ARGUMENT],
             ['--memo_type', GetoptLong::OPTIONAL_ARGUMENT],
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
    when '--memo_type'
      self.memo_type = arg
    when '--seed'
      self.seed = arg.to_i
    when '--llm_model'
      self.llm_model = arg
    end
  end
end

class LlmMemoNarrativeGenerator < LlmNarrativeGenerator
  def build_prompt(extra_variables = {})
    vars = template_variables(extra_variables)
    prompt = LlmPromptTemplate.load_and_render('memo', vars)
    append_cybok_alignment(prompt)
  end
end

LlmMemoGeneratorLocal.new.run
