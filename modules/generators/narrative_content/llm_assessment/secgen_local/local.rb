#!/usr/bin/ruby
require 'json'
require_relative '../../../../../lib/objects/local_string_encoder.rb'
require_relative '../../lib/llm_narrative_generator.rb'

class LlmAssessmentGeneratorLocal < StringEncoder
  attr_accessor :organisation
  attr_accessor :theme
  attr_accessor :cybok_ka
  attr_accessor :cybok_topic
  attr_accessor :question_type
  attr_accessor :context
  attr_accessor :seed
  attr_accessor :llm_model

  def initialize
    super
    self.module_name = 'LLM Assessment Generator'
    self.organisation = '{}'
    self.theme = 'investigation'
    self.cybok_ka = 'MAT'
    self.cybok_topic = ''
    self.question_type = 'comprehension'
    self.context = ''
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
      'content_type' => 'assessment',
      'cybok_ka' => self.cybok_ka,
      'cybok_topic' => self.cybok_topic.empty? ? nil : self.cybok_topic
    }

    generator = LlmAssessmentNarrativeGenerator.new(options)
    content = generator.generate_content({
      'question_type' => self.question_type,
      'context' => self.context
    })

    self.outputs << content
  end

  def get_options_array
    super + [['--organisation', GetoptLong::REQUIRED_ARGUMENT],
             ['--theme', GetoptLong::REQUIRED_ARGUMENT],
             ['--cybok_ka', GetoptLong::REQUIRED_ARGUMENT],
             ['--cybok_topic', GetoptLong::OPTIONAL_ARGUMENT],
             ['--question_type', GetoptLong::OPTIONAL_ARGUMENT],
             ['--context', GetoptLong::OPTIONAL_ARGUMENT],
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
    when '--cybok_ka'
      self.cybok_ka = arg
    when '--cybok_topic'
      self.cybok_topic = arg
    when '--question_type'
      self.question_type = arg
    when '--context'
      self.context = arg
    when '--seed'
      self.seed = arg.to_i
    when '--llm_model'
      self.llm_model = arg
    end
  end
end

class LlmAssessmentNarrativeGenerator < LlmNarrativeGenerator
  def build_prompt(extra_variables = {})
    question_type = extra_variables['question_type'] || 'comprehension'
    context = extra_variables['context'] || ''

    prompt = LlmCybok.assessment_prompt(@cybok_ka, question_type, context)

    if @organisation_data && !@organisation_data.empty?
      prompt += "\nOrganisation context: #{@organisation_data['business_name']} (#{@organisation_data['industry']})\n"
    end

    prompt += "\nTheme: #{@narrative_theme}\n"
    prompt
  end
end

LlmAssessmentGeneratorLocal.new.run
