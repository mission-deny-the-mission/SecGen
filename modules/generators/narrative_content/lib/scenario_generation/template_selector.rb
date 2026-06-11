require 'digest'
require_relative 'intent'
require_relative 'template_catalog'

module ScenarioGeneration
  class TemplateSelectionError < StandardError; end

  # Maps each requested vulnerability class in a normalized Intent to exactly one
  # approved, compatible template. Selection is deterministic for a given seed and
  # FAILS FAST (raising TemplateSelectionError) before any artifact is written when
  # no approved template supports a requested class/platform/difficulty.
  class TemplateSelector
    def initialize(intent:, catalog:)
      @intent = intent
      @catalog = catalog
    end

    # Array of string-keyed Hashes:
    #   { 'vulnerability_class' => canonical, 'template' => TemplateMetadata,
    #     'template_id' => id, 'template_version' => version }
    def select
      platform = @intent.normalized['target_platform']
      difficulty = @intent.normalized['difficulty']
      seed = @intent.normalized['seed']
      requested = Array(@intent.normalized['vulnerability_classes'])

      selections = []
      unsatisfiable = []

      requested.each do |vulnerability_class|
        candidates = @catalog.compatible(
          vulnerability_class: vulnerability_class,
          platform: platform,
          difficulty: difficulty
        )

        if candidates.empty?
          unsatisfiable << {
            'vulnerability_class' => vulnerability_class,
            'platform' => platform,
            'difficulty' => difficulty
          }
          next
        end

        template = deterministic_pick(candidates, seed, vulnerability_class)
        selections << {
          'vulnerability_class' => vulnerability_class,
          'template' => template,
          'template_id' => template['id'],
          'template_version' => template['version']
        }
      end

      raise TemplateSelectionError, selection_error_message(unsatisfiable) unless unsatisfiable.empty?

      selections
    end

    # Reproducibility-friendly summary (no TemplateMetadata objects) for the manifest.
    def selection_summary
      select.map do |entry|
        {
          'vulnerability_class' => entry['vulnerability_class'],
          'template_id' => entry['template_id'],
          'template_version' => entry['template_version']
        }
      end
    end

    private

    # When more than one template matches, pick deterministically from the
    # id-sorted candidates using a digest of (seed, vulnerability_class) so the
    # choice is reproducible and varies sensibly per requested class.
    def deterministic_pick(candidates, seed, vulnerability_class)
      sorted = candidates.sort_by { |template| template['id'].to_s }
      return sorted.first if sorted.length == 1

      digest = Digest::SHA256.hexdigest("#{seed}:#{vulnerability_class}")
      sorted[digest.to_i(16) % sorted.length]
    end

    def selection_error_message(unsatisfiable)
      details = unsatisfiable.map do |entry|
        "#{entry['vulnerability_class']} (platform=#{entry['platform']}, difficulty=#{entry['difficulty']})"
      end
      message = "No approved template supports: #{details.join('; ')}."

      available = @catalog.vulnerability_classes
      message += " Available vulnerability classes: #{available.join(', ')}." unless available.empty?
      message
    end
  end
end
