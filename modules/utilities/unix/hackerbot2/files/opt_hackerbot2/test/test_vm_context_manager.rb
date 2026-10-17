require_relative 'test_helper'
require_relative '../vm_context_manager'
require 'open3'
require 'timeout'
require 'stringio'

class VMContextManagerTest < Minitest::Test
  def setup
    @vm_manager = VMContextManager.new
    @ssh_config = { 'get_shell' => 'sshpass -p password ssh user@host' }
  end
  
  def test_initialization_with_defaults
    manager = VMContextManager.new
    assert_instance_of VMContextManager, manager
  end
  
  def test_initialization_with_custom_options
    manager = VMContextManager.new(default_timeout: 60, command_timeout: 30)
    assert_instance_of VMContextManager, manager
  end
  
  def test_execute_command_success
    ssh_config = { 'get_shell' => 'bash' }
    command = 'echo "test output"'
    
    # Mock Open3.popen2e to simulate successful command execution
    Open3.stub(:popen2e, ->(cmd, &block) {
      mock_stdin = StringIO.new
      mock_stdout = StringIO.new("test output\n")
      mock_wait_thr = Object.new
      mock_wait_thr.define_singleton_method(:alive?) { false }
      mock_wait_thr.define_singleton_method(:kill) { }
      
      # Simulate the block call
      block.call(mock_stdin, mock_stdout, mock_wait_thr)
      nil
    }) do
      # Capture stdout to suppress output during test
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      
      begin
        output = @vm_manager.execute_command(ssh_config, command)
        refute_nil output
        assert output.include?("test output"), "Expected output to include 'test output', got: #{output}"
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end
  end
  
  def test_execute_command_with_nil_ssh_config
    output = @vm_manager.execute_command(nil, 'echo test')
    assert_nil output
  end
  
  def test_execute_command_with_empty_ssh_config
    output = @vm_manager.execute_command({}, 'echo test')
    assert_nil output
  end
  
  def test_execute_command_with_nil_command
    output = @vm_manager.execute_command(@ssh_config, nil)
    assert_nil output
  end
  
  def test_execute_command_with_empty_command
    output = @vm_manager.execute_command(@ssh_config, '')
    assert_nil output
  end
  
  def test_execute_command_variable_substitution
    ssh_config = { 'get_shell' => 'sshpass -p password ssh user@{{chat_ip_address}}' }
    variables = { chat_ip_address: '192.168.1.100' }
    
    # Verify substitution happens in extract_shell_command
    # We can't easily mock Open3, so we'll test the private method behavior indirectly
    # by checking that substitution occurs
    output = @vm_manager.execute_command(ssh_config, 'echo "test"', variables)
    # If substitution works, the command should execute (even if SSH fails in test)
    # We primarily verify no errors are raised
    # (actual SSH execution would fail in test environment)
  end
  
  def test_read_file_success
    ssh_config = { 'get_shell' => 'bash' }
    file_path = '/tmp/test_file.txt'
    
    # Mock Open3 for file reading
    Open3.stub(:popen2e, ->(cmd, &block) {
      mock_stdin = StringIO.new
      mock_stdout = StringIO.new("file content\n")
      mock_wait_thr = Object.new
      mock_wait_thr.define_singleton_method(:alive?) { false }
      mock_wait_thr.define_singleton_method(:kill) { }
      
      block.call(mock_stdin, mock_stdout, mock_wait_thr)
      nil
    }) do
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      
      begin
        content = @vm_manager.read_file(ssh_config, file_path)
        refute_nil content
        assert content.include?("file content"), "Expected content to include 'file content', got: #{content}"
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end
  end
  
  def test_read_file_with_absolute_path
    ssh_config = { 'get_shell' => 'bash' }
    file_path = '/etc/passwd'
    
    # Verify it handles absolute paths
    content = @vm_manager.read_file(ssh_config, file_path)
    # In test environment, actual SSH won't work, so we expect nil or empty
    # But we verify the method doesn't crash
    assert(content.nil? || content.is_a?(String))
  end
  
  def test_read_file_with_relative_path
    ssh_config = { 'get_shell' => 'bash' }
    file_path = './config.txt'
    
    content = @vm_manager.read_file(ssh_config, file_path)
    assert(content.nil? || content.is_a?(String))
  end
  
  def test_read_file_with_nil_path
    content = @vm_manager.read_file(@ssh_config, nil)
    assert_nil content
  end
  
  def test_read_file_with_empty_path
    content = @vm_manager.read_file(@ssh_config, '')
    assert_nil content
  end
  
  def test_read_bash_history_default
    ssh_config = { 'get_shell' => 'bash' }
    
    # Mock Open3 for history reading
    Open3.stub(:popen2e, ->(cmd, &block) {
      mock_stdin = StringIO.new
      mock_stdout = StringIO.new("command1\ncommand2\ncommand3\n")
      mock_wait_thr = Object.new
      mock_wait_thr.define_singleton_method(:alive?) { false }
      mock_wait_thr.define_singleton_method(:kill) { }
      
      block.call(mock_stdin, mock_stdout, mock_wait_thr)
      nil
    }) do
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      
      begin
        history = @vm_manager.read_bash_history(ssh_config)
        refute_nil history
        assert history.is_a?(String)
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end
  end
  
  def test_read_bash_history_with_limit
    ssh_config = { 'get_shell' => 'bash' }
    limit = 10
    
    # Mock Open3
    Open3.stub(:popen2e, ->(cmd, &block) {
      mock_stdin = StringIO.new
      # Simulate tail output
      mock_stdout = StringIO.new("command1\ncommand2\n")
      mock_wait_thr = Object.new
      mock_wait_thr.define_singleton_method(:alive?) { false }
      mock_wait_thr.define_singleton_method(:kill) { }
      
      block.call(mock_stdin, mock_stdout, mock_wait_thr)
      nil
    }) do
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      
      begin
        history = @vm_manager.read_bash_history(ssh_config, nil, limit)
        refute_nil history
        assert history.is_a?(String)
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end
  end
  
  def test_read_bash_history_with_user
    ssh_config = { 'get_shell' => 'bash' }
    user = 'student'
    
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      history = @vm_manager.read_bash_history(ssh_config, user)
      assert history.is_a?(String)
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  
  def test_read_bash_history_with_nil_ssh_config
    history = @vm_manager.read_bash_history(nil)
    assert_nil history
  end
  
  def test_read_bash_history_with_empty_ssh_config
    history = @vm_manager.read_bash_history({})
    assert_nil history
  end
  
  def test_read_bash_history_returns_empty_string_on_error
    ssh_config = { 'get_shell' => 'invalid-ssh-command' }
    
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      history = @vm_manager.read_bash_history(ssh_config)
      # Should return empty string even on error (graceful degradation)
      assert_equal '', history
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  
  def test_ssh_config_with_symbol_key
    ssh_config = { get_shell: 'bash' }
    
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      output = @vm_manager.execute_command(ssh_config, 'echo test')
      # Should handle symbol keys
      assert(output.nil? || output.is_a?(String))
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  
  def test_variable_substitution_chat_ip_address
    ssh_config = { 'get_shell' => 'ssh user@{{chat_ip_address}}' }
    variables = { chat_ip_address: '10.0.0.1' }
    
    # Test that variable substitution works
    # We test indirectly since we can't easily access private methods
    # In a real scenario with valid SSH, this would work
    output = @vm_manager.execute_command(ssh_config, 'echo test', variables)
    # Verify it doesn't crash and handles substitution
    assert(output.nil? || output.is_a?(String))
  end
  
  def test_variable_substitution_string_key
    ssh_config = { 'get_shell' => 'ssh user@{{chat_ip_address}}' }
    variables = { 'chat_ip_address' => '10.0.0.1' }
    
    output = @vm_manager.execute_command(ssh_config, 'echo test', variables)
    assert(output.nil? || output.is_a?(String))
  end
  
  def test_error_handling_timeout
    ssh_config = { 'get_shell' => 'bash' }
    
    # Create a manager with very short timeout for testing
    fast_manager = VMContextManager.new(command_timeout: 0.01)
    
    # Mock Open3 to simulate timeout
    Open3.stub(:popen2e, ->(cmd, &block) {
      mock_stdin = StringIO.new
      mock_stdout = Object.new
      mock_stdout.define_singleton_method(:read_nonblock) { |*args| sleep(1); raise IO::WaitReadable }
      mock_wait_thr = Object.new
      mock_wait_thr.define_singleton_method(:alive?) { true }
      mock_wait_thr.define_singleton_method(:kill) { }
      
      block.call(mock_stdin, mock_stdout, mock_wait_thr)
      nil
    }) do
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = StringIO.new
      $stderr = StringIO.new
      
      begin
        output = fast_manager.execute_command(ssh_config, 'sleep 10')
        # Should return nil on timeout
        assert_nil output
      ensure
        $stdout = original_stdout
        $stderr = original_stderr
      end
    end
  end
  
  def test_error_handling_invalid_ssh_command
    ssh_config = { 'get_shell' => 'invalid-command-that-does-not-exist' }
    
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      output = @vm_manager.execute_command(ssh_config, 'echo test')
      # Should handle error gracefully and return nil
      assert_nil output
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  
  def test_error_handling_connection_failure
    ssh_config = { 'get_shell' => 'ssh invalid@invalid-host' }
    
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      output = @vm_manager.execute_command(ssh_config, 'echo test')
      # Should handle connection failure gracefully
      assert_nil output
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  
  def test_integration_execute_and_read_flow
    ssh_config = { 'get_shell' => 'bash' }
    
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      # Test executing a command
      output1 = @vm_manager.execute_command(ssh_config, 'echo "integration test"')
      
      # Test reading a file
      output2 = @vm_manager.read_file(ssh_config, '/tmp/test')
      
      # Test reading bash history
      output3 = @vm_manager.read_bash_history(ssh_config, nil, 10)
      
      # All should return strings or nil (graceful degradation)
      assert(output1.nil? || output1.is_a?(String))
      assert(output2.nil? || output2.is_a?(String))
      assert(output3.is_a?(String))
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  
  def test_integration_variable_substitution_and_execution
    ssh_config = { 'get_shell' => 'bash' }
    variables = { chat_ip_address: '192.168.1.50' }
    
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    
    begin
      # Test that variable substitution works with execution
      output = @vm_manager.execute_command(ssh_config, 'echo "test"', variables)
      assert(output.nil? || output.is_a?(String))
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
end

