require_relative 'spec_helper'
require 'json'
require 'open3'

class TestScenarioGenerationOpenCodeCli < Minitest::Test
  def opencode_bin
    ENV['OPENCODE_BIN'] || 'opencode'
  end

  def capture_opencode(*args)
    stdout, stderr, status = Open3.capture3(opencode_bin, *args)
    skip "OpenCode is not available: #{stderr}" if status.exitstatus == 127
    [stdout, stderr, status]
  rescue Errno::ENOENT
    skip 'OpenCode is not available'
  end

  def test_opencode_version_is_available
    stdout, stderr, status = capture_opencode('--version')

    assert status.success?, stderr
    assert_match(/\A\d+\.\d+\.\d+/, stdout.strip)
  end

  def test_opencode_run_supports_required_noninteractive_flags
    stdout, stderr, status = capture_opencode('run', '--help')
    output = stdout + stderr

    assert status.success?, stderr
    assert_includes output, '--dir'
    assert_includes output, '--agent'
    assert_includes output, '--format'
    assert_includes output, '--model'
    assert_includes output, '--title'
  end

  def test_opencode_plan_agent_is_read_only
    stdout, stderr, status = capture_opencode('--pure', 'debug', 'agent', 'plan')

    assert status.success?, stderr
    agent = JSON.parse(stdout)
    assert_equal 'plan', agent['name']
    assert_equal 'primary', agent['mode']
    assert_equal true, agent.dig('tools', 'read')
    assert_equal true, agent.dig('tools', 'bash')
    assert agent['permission'].any? { |permission| permission['permission'] == 'edit' && permission['action'] == 'deny' }
  end

  def test_opencode_build_agent_supports_editing
    stdout, stderr, status = capture_opencode('--pure', 'debug', 'agent', 'build')

    assert status.success?, stderr
    agent = JSON.parse(stdout)
    assert_equal 'build', agent['name']
    assert_equal 'primary', agent['mode']
    assert_equal true, agent.dig('tools', 'apply_patch')
    assert_equal true, agent.dig('tools', 'bash')
    assert agent['permission'].any? { |permission| permission['permission'] == '*' && permission['action'] == 'allow' }
  end
end
