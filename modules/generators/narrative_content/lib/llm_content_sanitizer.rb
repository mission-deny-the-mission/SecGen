# Content sanitization for LLM-generated narratives.
# Ensures generated content is safe for deployment in educational VMs.
class LlmContentSanitizer
  # Patterns that should never appear in generated content
  BLOCKED_PATTERNS = [
    /\b(?:real|actual)\s+(?:password|credential|api.?key|secret)\b/i,
    /\b(?:ssh-rsa|ssh-ed25519)\s+[A-Za-z0-9+\/=]{20,}/,  # Real SSH keys
    /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/,              # Private keys
    /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z]{2,}\b/i,   # Removed - allow emails for scenarios
  ].freeze

  SENSITIVE_PATTERNS = [
    /-----BEGIN (?:RSA |EC )?PRIVATE KEY-----/,
    /\bpasswd\s*:\s*\S+/,
    /\bsudo\s+rm\s+-rf\s+\//,
  ].freeze

  # Sanitize generated content for VM deployment
  def self.sanitize(content)
    result = content.dup

    # Remove any accidentally included real private keys
    result.gsub!(/-----BEGIN (?:RSA |EC )?PRIVATE KEY-----.*?-----END (?:RSA |EC )?PRIVATE KEY-----/m, '[REDACTED - PRIVATE KEY]')

    # Remove potential shell injection in generated scripts
    result.gsub!(/`[^`]*`/) { |match| match.gsub(/[;&|$]/, '') }

    result
  end

  # Check content for quality issues
  def self.validate_quality(content, min_length: 50, max_length: 50000)
    issues = []

    issues << 'Content is empty' if content.nil? || content.strip.empty?
    issues << "Content too short (#{content.length} chars, min #{min_length})" if content && content.length < min_length
    issues << "Content too long (#{content.length} chars, max #{max_length})" if content && content.length > max_length

    # Check for common LLM failure modes
    issues << 'Content appears to be a refusal' if content =~ /\bI (?:cannot|can't|am unable to|refuse to)\b/i
    issues << 'Content contains meta-commentary about being an AI' if content =~ /\bAs an? (?:AI|language model|LLM)\b/i

    issues
  end

  # Check that content doesn't contain student-identifiable information
  def self.check_student_data(prompt)
    issues = []
    # Check for patterns that might be real student data
    issues << 'Prompt may contain real email addresses' if prompt =~ /\b[A-Za-z0-9._%+-]+@(?:edu|ac\.uk|university)\b/i
    issues << 'Prompt may contain student ID numbers' if prompt =~ /\bstudent.?id\s*[:=]\s*\d{5,}/i
    issues
  end

  # Detect inappropriate content in generated narratives
  def self.check_inappropriate(content)
    issues = []
    # Basic checks - extend as needed
    issues << 'Content may contain graphic violence' if content =~ /\b(?:graphic|explicit)\s+(?:violence|gore)\b/i
    issues
  end
end
