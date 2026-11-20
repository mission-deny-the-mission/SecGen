#!/usr/bin/ruby
require_relative '../../../../../../lib/objects/local_hackerbot_config_generator.rb'

# Hackerbot 3 version of the hb2_siem lab: the same bot (attacks, quizzes, flags) rendered from the
# hb2_siem template, plus a <decision_router> so the hackerbot3 utility answers common lab questions
# with curated canned answers (decision/pairs/labhelp_pairs.json, lab id "hb2_siem") before the LLM.
class HB3SIEM < HackerbotConfigGenerator

  def initialize
    super
    self.module_name = 'Hackerbot 3 Config Generator SIEM'
    self.title = 'SIEM'

    self.local_dir = File.expand_path('../../../hb2_siem', __FILE__)
    self.templates_path = "#{self.local_dir}/templates/"
    self.config_template_path = "#{self.local_dir}/templates/lab.xml.erb"
    self.decision_router_lab = 'hb2_siem'
  end

end

HB3SIEM.new.run
