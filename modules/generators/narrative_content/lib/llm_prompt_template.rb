# Loads and renders Handlebars-style prompt templates with variable substitution.
# Supports {{variable}}, {{object.property}}, and {{#each array}}...{{/each}} blocks.
class LlmPromptTemplate
  PROMPTS_DIR = File.expand_path('../../prompts', __FILE__)

  @@template_cache = {}

  # Load a template by name from the prompts directory
  def self.load(template_name, custom_dir = nil)
    search_dirs = []
    search_dirs << custom_dir if custom_dir
    search_dirs << PROMPTS_DIR

    template_content = nil
    search_dirs.each do |dir|
      path = File.join(dir, template_name)
      path += '.txt' unless path.end_with?('.txt')
      if File.exist?(path)
        template_content = @@template_cache[path] ||= File.read(path)
        break
      end
    end

    unless template_content
      available = Dir.glob(File.join(PROMPTS_DIR, '*.txt')).map { |f| File.basename(f, '.txt') }
      raise "Template '#{template_name}' not found. Available templates: #{available.join(', ')}"
    end

    template_content
  end

  # Render a template with variable substitution
  def self.render(template_content, variables = {})
    result = template_content.dup

    # Process {{#each key}}...{{/each}} blocks
    result.gsub!(/\{\{#each\s+(\w+)\}\}(.*?)\{\{\/each\}\}/m) do |_match|
      key = $1
      block = $2
      items = resolve_variable(key, variables)
      if items.is_a?(Array)
        items.map { |item| render_block(block, item, variables) }.join
      else
        ''
      end
    end

    # Process {{#if key}}...{{/if}} blocks
    result.gsub!(/\{\{#if\s+(\S+)\}\}(.*?)\{\{\/if\}\}/m) do |_match|
      key = $1
      block = $2
      value = resolve_variable(key, variables)
      (value && value != '' && value != false && value != []) ? render_variables(block, variables) : ''
    end

    # Process simple variables {{key}} and {{object.property}}
    render_variables(result, variables)
  end

  # Load and render a template in one step
  def self.load_and_render(template_name, variables = {}, custom_dir = nil)
    template = load(template_name, custom_dir)
    render(template, variables)
  end

  # Validate template syntax - check for unmatched blocks
  def self.validate(template_content)
    errors = []

    # Check for unmatched {{#each}}
    each_opens = template_content.scan(/\{\{#each\s+\w+\}\}/).length
    each_closes = template_content.scan(/\{\{\/each\}\}/).length
    if each_opens != each_closes
      errors << "Unmatched {{#each}} blocks: #{each_opens} opens, #{each_closes} closes"
    end

    # Check for unmatched {{#if}}
    if_opens = template_content.scan(/\{\{#if\s+\S+\}\}/).length
    if_closes = template_content.scan(/\{\{\/if\}\}/).length
    if if_opens != if_closes
      errors << "Unmatched {{#if}} blocks: #{if_opens} opens, #{if_closes} closes"
    end

    errors
  end

  # Clear the template cache
  def self.clear_cache
    @@template_cache.clear
  end

  private

  def self.resolve_variable(key, variables)
    parts = key.split('.')
    value = variables
    parts.each do |part|
      if value.is_a?(Hash)
        value = value[part] || value[part.to_sym]
      else
        return nil
      end
    end
    value
  end

  def self.render_variables(text, variables)
    text.gsub(/\{\{(\w+(?:\.\w+)*)\}\}/) do |_match|
      key = $1
      value = resolve_variable(key, variables)
      value.nil? ? '' : value.to_s
    end
  end

  def self.render_block(block, item, parent_variables)
    if item.is_a?(Hash)
      merged = parent_variables.merge(item)
      # Also allow {{this.key}} syntax
      merged['this'] = item
      render_variables(block, merged)
    else
      render_variables(block.gsub('{{this}}', item.to_s), parent_variables)
    end
  end
end
