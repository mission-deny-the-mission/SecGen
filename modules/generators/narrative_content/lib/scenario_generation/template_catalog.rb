require_relative 'intent'
require_relative 'template_metadata'

module ScenarioGeneration
  class CatalogError < StandardError; end

  # Loads every approved vulnerable-software template under a catalog root into
  # TemplateMetadata objects and answers compatibility queries against an Intent.
  #
  # A template that fails to parse or fails validation (including approved != true,
  # which TemplateMetadata rejects in its constructor) is recorded in #load_errors
  # rather than aborting the whole catalog, so one bad template never blocks the rest.
  class TemplateCatalog
    DEFAULT_ROOT = File.expand_path('../../scenario_generation/templates', __dir__)

    attr_reader :templates, :load_errors

    def self.load(root = DEFAULT_ROOT)
      raise CatalogError, "Template catalog root not found: #{root}" unless Dir.exist?(root)

      templates = []
      load_errors = []
      template_files(root).each do |path|
        templates << TemplateMetadata.load(path)
      rescue TemplateMetadataError => e
        load_errors << { 'path' => path, 'message' => e.message }
      end

      new(templates: templates, load_errors: load_errors)
    end

    def self.template_files(root)
      patterns = %w[yml yaml json].map { |ext| File.join(root, '**', "*.#{ext}") }
      Dir[*patterns].uniq.sort
    end

    def initialize(templates:, load_errors: [])
      @templates = templates
      @load_errors = load_errors
    end

    def approved
      @templates.select(&:approved?)
    end

    def vulnerability_classes
      @templates.map { |template| template['vulnerability_class'] }.uniq.sort
    end

    def by_vulnerability_class(canonical)
      key = normalize_vulnerability_class(canonical)
      @templates.select { |template| template['vulnerability_class'] == key }
    end

    # Templates that are approved AND match the requested canonical vulnerability
    # class, support the requested platform, and offer the requested difficulty.
    # Both sides are normalized through the Intent vocabulary so a single source of
    # truth governs matching.
    def compatible(vulnerability_class:, platform:, difficulty:)
      key = normalize_vulnerability_class(vulnerability_class)
      plat = normalize_token(platform)
      diff = normalize_token(difficulty)

      @templates.select do |template|
        template.approved? &&
          template['vulnerability_class'] == key &&
          Array(template['supported_platforms']).include?(plat) &&
          Array(template['difficulties']).include?(diff)
      end
    end

    private

    def normalize_vulnerability_class(value)
      key = normalize_token(value)
      Intent::VULNERABILITY_ALIASES[key] || key
    end

    def normalize_token(value)
      value.to_s.strip.downcase.tr('-', '_').gsub(/\s+/, '_')
    end
  end
end
