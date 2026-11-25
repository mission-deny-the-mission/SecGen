#!/usr/bin/ruby
require_relative '../../../../../../lib/objects/local_hackerbot_config_generator.rb'

# Chat-only Hackerbot 3 bot that role-plays a member of teaching staff for the integrity protection lab.
# No attacks, flags or quizzes: canned staff answers (decision/pairs/labhelp_pairs.json, lab id
# "staff_integrity_protection") before the LLM, which gets a staff-tutor system prompt. No lab sheet of its own.
class HB3StaffTutorIntegrity < HackerbotConfigGenerator

  def initialize
    super
    self.module_name = 'Hackerbot 3 Config Generator Staff Tutor Integrity'
    self.title = 'Integrity Protection lab tutor'

    self.local_dir = File.expand_path('../../', __FILE__)
    self.templates_path = "#{self.local_dir}/templates/"
    self.config_template_path = "#{self.local_dir}/templates/tutor.xml.erb"
    self.decision_router_lab = 'staff_integrity_protection'
    self.lab_sheet = false
  end

end

HB3StaffTutorIntegrity.new.run
