require_relative 'spec_helper'
require 'llm_cybok'

class TestLlmCybok < Minitest::Test
  def test_alignment_prompt_mat
    prompt = LlmCybok.alignment_prompt('MAT')
    assert_includes prompt, 'Malicious Activities and Techniques'
    assert_includes prompt, 'MAT'
    assert_includes prompt, 'Learning objectives'
  end

  def test_alignment_prompt_soim
    prompt = LlmCybok.alignment_prompt('SOIM')
    assert_includes prompt, 'Security Operations and Incident Management'
  end

  def test_alignment_prompt_nsca
    prompt = LlmCybok.alignment_prompt('NSCA')
    assert_includes prompt, 'Network Security and Countermeasures'
  end

  def test_alignment_prompt_with_topic
    prompt = LlmCybok.alignment_prompt('MAT', 'Exploitation techniques')
    assert_includes prompt, 'Exploitation techniques'
  end

  def test_alignment_prompt_unknown_ka
    prompt = LlmCybok.alignment_prompt('UNKNOWN')
    assert_equal '', prompt
  end

  def test_xml_tags_mat
    xml = LlmCybok.xml_tags('MAT')
    assert_includes xml, 'KA="MAT"'
    assert_includes xml, '<keyword>'
    assert_includes xml, '</CyBOK>'
  end

  def test_xml_tags_with_topic
    xml = LlmCybok.xml_tags('SOIM', 'Incident Response')
    assert_includes xml, 'topic="Incident Response"'
  end

  def test_xml_tags_unknown_ka
    xml = LlmCybok.xml_tags('UNKNOWN')
    assert_equal '', xml
  end

  def test_assessment_prompt_comprehension
    prompt = LlmCybok.assessment_prompt('MAT', 'comprehension')
    assert_includes prompt, 'comprehension'
    assert_includes prompt, 'Malicious Activities'
  end

  def test_assessment_prompt_application
    prompt = LlmCybok.assessment_prompt('MAT', 'application')
    assert_includes prompt, 'application'
    assert_includes prompt, 'apply'
  end

  def test_assessment_prompt_analysis
    prompt = LlmCybok.assessment_prompt('MAT', 'analysis')
    assert_includes prompt, 'analysis'
    assert_includes prompt, 'analytical'
  end

  def test_assessment_prompt_with_context
    prompt = LlmCybok.assessment_prompt('MAT', 'comprehension', 'email phishing scenario')
    assert_includes prompt, 'email phishing scenario'
  end

  def test_validate_coverage_good
    content = "The malware exploit was used to attack the system via a vulnerability. " \
              "The payload was delivered through phishing, a common technique in APT campaigns."
    result = LlmCybok.validate_coverage(content, 'MAT')
    assert result['valid']
    assert result['coverage_percent'] > 0
    refute_empty result['found_keywords']
  end

  def test_validate_coverage_poor
    content = "The weather is nice today."
    result = LlmCybok.validate_coverage(content, 'MAT')
    refute result['valid']
    assert_equal 0.0, result['coverage_percent']
  end

  def test_validate_coverage_unknown_ka
    result = LlmCybok.validate_coverage('any content', 'UNKNOWN')
    refute result['valid']
    assert_equal 'Unknown knowledge area', result['reason']
  end

  def test_knowledge_areas_contain_required_fields
    LlmCybok::KNOWLEDGE_AREAS.each do |code, ka|
      assert ka.key?('name'), "#{code} missing name"
      assert ka.key?('topics'), "#{code} missing topics"
      assert ka.key?('learning_objectives'), "#{code} missing learning_objectives"
      assert ka.key?('keywords'), "#{code} missing keywords"
      refute_empty ka['topics'], "#{code} has empty topics"
      refute_empty ka['learning_objectives'], "#{code} has empty learning_objectives"
      refute_empty ka['keywords'], "#{code} has empty keywords"
    end
  end
end
