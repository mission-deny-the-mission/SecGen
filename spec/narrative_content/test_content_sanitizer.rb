require_relative 'spec_helper'
require 'llm_content_sanitizer'

class TestLlmContentSanitizer < Minitest::Test
  def test_sanitize_removes_private_keys
    content = "Some text\n-----BEGIN RSA PRIVATE KEY-----\nMIIE...key content...\n-----END RSA PRIVATE KEY-----\nMore text"
    result = LlmContentSanitizer.sanitize(content)
    assert_includes result, '[REDACTED - PRIVATE KEY]'
    refute_includes result, 'BEGIN RSA PRIVATE KEY'
  end

  def test_sanitize_preserves_normal_content
    content = "This is a normal email about a security incident."
    result = LlmContentSanitizer.sanitize(content)
    assert_equal content, result
  end

  def test_validate_quality_empty_content
    issues = LlmContentSanitizer.validate_quality('')
    assert_includes issues, 'Content is empty'
  end

  def test_validate_quality_too_short
    issues = LlmContentSanitizer.validate_quality('Short', min_length: 50)
    assert issues.any? { |i| i.include?('too short') }
  end

  def test_validate_quality_too_long
    long_content = 'x' * 60000
    issues = LlmContentSanitizer.validate_quality(long_content, max_length: 50000)
    assert issues.any? { |i| i.include?('too long') }
  end

  def test_validate_quality_ai_refusal
    content = "I cannot help with that request as it involves..."
    issues = LlmContentSanitizer.validate_quality(content)
    assert issues.any? { |i| i.include?('refusal') }
  end

  def test_validate_quality_ai_meta_commentary
    content = "As an AI language model, I will generate the following content..."
    issues = LlmContentSanitizer.validate_quality(content)
    assert issues.any? { |i| i.include?('AI') }
  end

  def test_validate_quality_good_content
    content = "Welcome to SecureCorp, a leading financial services provider. " * 5
    issues = LlmContentSanitizer.validate_quality(content)
    assert_empty issues
  end

  def test_check_student_data_detects_edu_email
    issues = LlmContentSanitizer.check_student_data('Send to student@university.edu')
    assert issues.any? { |i| i.include?('email') }
  end

  def test_check_student_data_detects_student_id
    issues = LlmContentSanitizer.check_student_data('student_id: 12345678')
    assert issues.any? { |i| i.include?('student ID') }
  end

  def test_check_student_data_safe_prompt
    issues = LlmContentSanitizer.check_student_data('Generate an email for employee@company.com')
    assert_empty issues
  end

  def test_check_inappropriate_clean_content
    issues = LlmContentSanitizer.check_inappropriate('A normal cybersecurity training scenario')
    assert_empty issues
  end
end
