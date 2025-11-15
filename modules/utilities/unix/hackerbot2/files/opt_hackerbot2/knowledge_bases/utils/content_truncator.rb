#!/usr/bin/env ruby

# Utility module for intelligently truncating document content
# to avoid exceeding maximum length limits in RAG systems
module ContentTruncator
  # Truncation strategies
  SECTION_BREAK = :section_break  # Look for \n\n (double newline)
  SENTENCE_BREAK = :sentence_break  # Look for sentence endings [.!?]
  WORD_BREAK = :word_break  # Look for whitespace boundaries

  # Truncate content intelligently to avoid exceeding maximum length
  #
  # @param content [String] Document content to truncate
  # @param max_length [Integer] Maximum content length (default: 7000)
  # @param strategy [Symbol] Truncation strategy (:section_break, :sentence_break, :word_break)
  # @param truncation_note [String] Note to append when content is truncated
  # @return [String] Truncated content with note if truncated
  #
  # @example
  #   # Section break strategy (default, good for structured documents)
  #   truncated = ContentTruncator.truncate(content, max_length: 7000)
  #
  #   # Sentence break strategy (good for prose/paragraphs)
  #   truncated = ContentTruncator.truncate(content, max_length: 3000, strategy: :sentence_break)
  #
  #   # Word break strategy (most aggressive, preserves words)
  #   truncated = ContentTruncator.truncate(content, max_length: 3000, strategy: :word_break)
  #
  def self.truncate(content, max_length: 7000, strategy: :section_break, truncation_note: nil)
    return content if content.length <= max_length

    truncated_content = content[0...max_length]
    truncation_note ||= "\n\n[Note: Document truncated for length]"

    case strategy
    when :section_break
      # Look for section breaks (double newline)
      last_break = truncated_content.rindex(/\n\n/)
      if last_break && last_break > max_length - 500
        return truncated_content[0...last_break] + truncation_note
      end

    when :sentence_break
      # Look for sentence boundaries (sentence endings followed by newline)
      last_sentence = truncated_content.rindex(/[.!?]\s*\n/)
      if last_sentence && last_sentence > max_length - 200
        return truncated_content[0...last_sentence + 1] + truncation_note
      end

    when :word_break
      # Look for word boundaries (whitespace)
      last_space = truncated_content.rindex(/\s/)
      if last_space && last_space > max_length - 100
        return truncated_content[0...last_space] + truncation_note
      end
    end

    # Fallback: truncate at exact max_length
    truncated_content + truncation_note
  end

  # Truncate using multiple fallback strategies
  # Tries section breaks first, then sentence breaks, then word breaks
  #
  # @param content [String] Document content to truncate
  # @param max_length [Integer] Maximum content length
  # @param truncation_note [String] Note to append when content is truncated
  # @return [String] Truncated content with note if truncated
  def self.truncate_with_fallback(content, max_length:, truncation_note: nil)
    return content if content.length <= max_length

    truncation_note ||= "\n\n[Note: Document truncated for length]"

    # Try section break first
    truncated = truncate(content, max_length: max_length, strategy: :section_break, truncation_note: truncation_note)
    return truncated if truncated.length <= max_length + truncation_note.length

    # Try sentence break next
    truncated = truncate(content, max_length: max_length, strategy: :sentence_break, truncation_note: truncation_note)
    return truncated if truncated.length <= max_length + truncation_note.length

    # Fall back to word break
    truncate(content, max_length: max_length, strategy: :word_break, truncation_note: truncation_note)
  end
end

