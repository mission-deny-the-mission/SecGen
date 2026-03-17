#!/usr/bin/ruby
require 'json'
require_relative '../../../../../lib/objects/local_string_encoder.rb'
require_relative '../../lib/llm_narrative_generator.rb'

class LlmEmailChainGeneratorLocal < StringEncoder
  attr_accessor :organisation
  attr_accessor :theme
  attr_accessor :num_emails
  attr_accessor :seed
  attr_accessor :llm_model
  attr_accessor :participants

  def initialize
    super
    self.module_name = 'LLM Email Chain Generator'
    self.organisation = '{}'
    self.theme = 'insider_threat'
    self.num_emails = '5'
    self.seed = nil
    self.llm_model = ''
    self.participants = []
  end

  def encode_all
    org_data = JSON.parse(self.organisation) rescue {}

    options = {
      'seed' => self.seed,
      'model' => self.llm_model.empty? ? nil : self.llm_model,
      'theme' => self.theme,
      'organisation' => org_data,
      'content_type' => 'email_chain'
    }

    generator = LlmEmailChainNarrativeGenerator.new(options)
    content = generator.generate_content({
      'num_emails' => self.num_emails,
      'participants' => build_participants(org_data)
    })

    self.outputs << content
  end

  def get_options_array
    super + [['--organisation', GetoptLong::REQUIRED_ARGUMENT],
             ['--theme', GetoptLong::REQUIRED_ARGUMENT],
             ['--num_emails', GetoptLong::OPTIONAL_ARGUMENT],
             ['--seed', GetoptLong::OPTIONAL_ARGUMENT],
             ['--llm_model', GetoptLong::OPTIONAL_ARGUMENT],
             ['--participants', GetoptLong::OPTIONAL_ARGUMENT]]
  end

  def process_options(opt, arg)
    super
    case opt
    when '--organisation'
      self.organisation = arg
    when '--theme'
      self.theme = arg
    when '--num_emails'
      self.num_emails = arg
    when '--seed'
      self.seed = arg.to_i
    when '--llm_model'
      self.llm_model = arg
    when '--participants'
      self.participants << JSON.parse(arg)
    end
  end

  private

  def build_participants(org_data)
    return self.participants unless self.participants.empty?
    result = []
    if org_data['manager']
      result << org_data['manager'].merge('role' => 'Manager')
    end
    if org_data['employees'].is_a?(Array)
      org_data['employees'].each do |emp|
        result << emp.merge('role' => 'Employee')
      end
    end
    result
  end
end

class LlmEmailChainNarrativeGenerator < LlmNarrativeGenerator
  def build_prompt(extra_variables = {})
    vars = template_variables(extra_variables)
    prompt = LlmPromptTemplate.load_and_render('email_chain', vars)
    append_cybok_alignment(prompt)
  end
end

LlmEmailChainGeneratorLocal.new.run
