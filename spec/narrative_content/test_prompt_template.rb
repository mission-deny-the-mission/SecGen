require_relative 'spec_helper'
require 'llm_prompt_template'

class TestLlmPromptTemplate < Minitest::Test
  def test_simple_variable_substitution
    template = 'Hello, {{name}}! Welcome to {{company}}.'
    result = LlmPromptTemplate.render(template, { 'name' => 'Alice', 'company' => 'SecGen' })
    assert_equal 'Hello, Alice! Welcome to SecGen.', result
  end

  def test_nested_variable_substitution
    template = 'Manager: {{organisation.manager.name}}'
    vars = { 'organisation' => { 'manager' => { 'name' => 'Bob' } } }
    result = LlmPromptTemplate.render(template, vars)
    assert_equal 'Manager: Bob', result
  end

  def test_each_block
    template = "Employees:{{#each employees}}\n- {{name}} ({{role}}){{/each}}"
    vars = {
      'employees' => [
        { 'name' => 'Alice', 'role' => 'Developer' },
        { 'name' => 'Bob', 'role' => 'Manager' }
      ]
    }
    result = LlmPromptTemplate.render(template, vars)
    assert_includes result, '- Alice (Developer)'
    assert_includes result, '- Bob (Manager)'
  end

  def test_if_block_truthy
    template = '{{#if name}}Hello, {{name}}!{{/if}}'
    result = LlmPromptTemplate.render(template, { 'name' => 'Alice' })
    assert_equal 'Hello, Alice!', result
  end

  def test_if_block_falsy
    template = '{{#if name}}Hello, {{name}}!{{/if}}'
    result = LlmPromptTemplate.render(template, {})
    assert_equal '', result
  end

  def test_missing_variable_returns_empty
    template = 'Hello, {{name}}!'
    result = LlmPromptTemplate.render(template, {})
    assert_equal 'Hello, !', result
  end

  def test_validate_valid_template
    template = '{{#each items}}{{name}}{{/each}}'
    errors = LlmPromptTemplate.validate(template)
    assert_empty errors
  end

  def test_validate_unmatched_each
    template = '{{#each items}}{{name}}'
    errors = LlmPromptTemplate.validate(template)
    refute_empty errors
    assert_match(/Unmatched/, errors.first)
  end

  def test_validate_unmatched_if
    template = '{{#if condition}}text'
    errors = LlmPromptTemplate.validate(template)
    refute_empty errors
  end

  def test_load_existing_template
    # Should be able to load one of our templates
    content = LlmPromptTemplate.load('scenario_introduction')
    refute_nil content
    refute_empty content
    assert_includes content, '{{business_name}}'
  end

  def test_load_nonexistent_template
    assert_raises(RuntimeError) { LlmPromptTemplate.load('nonexistent_template_xyz') }
  end

  def test_load_and_render
    result = LlmPromptTemplate.load_and_render('scenario_introduction', {
      'business_name' => 'TestCorp',
      'industry' => 'Technology',
      'domain' => 'testcorp.com',
      'theme' => 'investigation'
    })
    assert_includes result, 'TestCorp'
    assert_includes result, 'Technology'
  end

  def test_cache_clearing
    LlmPromptTemplate.load('scenario_introduction')
    LlmPromptTemplate.clear_cache
    # Should still load successfully after cache clear
    content = LlmPromptTemplate.load('scenario_introduction')
    refute_nil content
  end
end
