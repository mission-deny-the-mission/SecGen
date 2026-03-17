#!/usr/bin/ruby
require 'json'
require_relative '../../../../../lib/objects/local_string_encoder.rb'
require_relative '../../lib/llm_narrative_generator.rb'

class LlmCtfNarrativeGeneratorLocal < StringEncoder
  attr_accessor :organisation
  attr_accessor :theme
  attr_accessor :cybok_ka
  attr_accessor :cybok_topic
  attr_accessor :seed
  attr_accessor :llm_model
  attr_accessor :characters

  def initialize
    super
    self.module_name = 'LLM CTF Narrative Generator'
    self.organisation = '{}'
    self.theme = 'espionage'
    self.cybok_ka = ''
    self.cybok_topic = ''
    self.seed = nil
    self.llm_model = ''
    self.characters = []
  end

  def encode_all
    org_data = JSON.parse(self.organisation) rescue {}

    options = {
      'seed' => self.seed,
      'model' => self.llm_model.empty? ? nil : self.llm_model,
      'theme' => self.theme,
      'organisation' => org_data,
      'content_type' => 'ctf_narrative',
      'cybok_ka' => self.cybok_ka.empty? ? nil : self.cybok_ka,
      'cybok_topic' => self.cybok_topic.empty? ? nil : self.cybok_topic
    }

    generator = LlmCtfNarrativeNarrativeGenerator.new(options)
    content = generator.generate_content({
      'characters' => build_characters(org_data)
    })

    self.outputs << content
  end

  def get_options_array
    super + [['--organisation', GetoptLong::REQUIRED_ARGUMENT],
             ['--theme', GetoptLong::REQUIRED_ARGUMENT],
             ['--cybok_ka', GetoptLong::OPTIONAL_ARGUMENT],
             ['--cybok_topic', GetoptLong::OPTIONAL_ARGUMENT],
             ['--seed', GetoptLong::OPTIONAL_ARGUMENT],
             ['--llm_model', GetoptLong::OPTIONAL_ARGUMENT],
             ['--characters', GetoptLong::OPTIONAL_ARGUMENT]]
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
    when '--seed'
      self.seed = arg.to_i
    when '--llm_model'
      self.llm_model = arg
    when '--characters'
      self.characters << JSON.parse(arg)
    end
  end

  private

  def build_characters(org_data)
    return self.characters unless self.characters.empty?
    result = []
    if org_data['manager']
      result << {
        'name' => org_data['manager']['name'],
        'role' => 'Manager',
        'description' => "Head of #{org_data['industry'] || 'operations'}"
      }
    end
    if org_data['employees'].is_a?(Array)
      org_data['employees'].each do |emp|
        result << {
          'name' => emp['name'],
          'role' => 'Employee',
          'description' => "Staff member at #{org_data['business_name'] || 'the organisation'}"
        }
      end
    end
    result
  end
end

class LlmCtfNarrativeNarrativeGenerator < LlmNarrativeGenerator
  def build_prompt(extra_variables = {})
    vars = template_variables(extra_variables)
    prompt = LlmPromptTemplate.load_and_render('ctf_narrative', vars)
    append_cybok_alignment(prompt)
  end

  def parse_response(raw_content)
    # Generate CyBOK XML tags if aligned
    if @cybok_ka
      xml_tags = LlmCybok.xml_tags(@cybok_ka, @cybok_topic)
      raw_content + "\n\n<!-- CyBOK Alignment -->\n" + xml_tags unless xml_tags.empty?
    else
      raw_content
    end
  end
end

LlmCtfNarrativeGeneratorLocal.new.run
