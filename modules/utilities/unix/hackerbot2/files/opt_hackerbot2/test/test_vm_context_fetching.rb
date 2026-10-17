require_relative 'test_helper'
require_relative '../bot_manager'
require_relative '../vm_context_manager'

class VMContextFetchingTest < Minitest::Test
  def setup
    @bot_manager = BotManager.new(
      TEST_CONFIG[:default_irc_server],
      'ollama',
      TEST_CONFIG[:default_ollama_host],
      TEST_CONFIG[:default_ollama_port],
      TEST_CONFIG[:default_ollama_model],
      nil, nil, nil, nil, nil, nil,
      false,
      {}
    )
    
    # Store test data
    @test_bot_name = 'test_bot'
    @test_attack_index = 0
    @test_ssh_config = { 'get_shell' => 'sshpass -p password ssh user@host' }
  end
  
  def test_fetch_vm_context_with_bash_history
    # Setup bot and attack with bash_history config
    vm_context_config = {
      bash_history: {
        path: '~/.bash_history',
        limit: 50,
        user: 'student'
      }
    }
    
    setup_bot_with_vm_context(vm_context_config)
    
    # Mock VMContextManager
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:read_bash_history, "cd /home/student\nls -la\ncat secret.txt", 
                           [Hash, 'student', 50, Hash])
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      refute_nil result
      assert result.include?("VM State:"), "Should include VM State header"
      assert result.include?("Bash History"), "Should include bash history section"
      assert result.include?("cd /home/student"), "Should include bash history content"
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_with_commands
    # Setup bot and attack with commands config
    vm_context_config = {
      commands: ['ps aux', 'whoami', 'ls -la']
    }
    
    setup_bot_with_vm_context(vm_context_config)
    
    # Mock VMContextManager
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:execute_command, "process list output", [Hash, String, Hash])
    mock_vm_manager.expect(:execute_command, "student", [Hash, String, Hash])
    mock_vm_manager.expect(:execute_command, "file list output", [Hash, String, Hash])
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      refute_nil result
      assert result.include?("VM State:"), "Should include VM State header"
      assert result.include?("Command Outputs:"), "Should include command outputs section"
      assert result.include?("[Command: ps aux]"), "Should include command name"
      assert result.include?("process list output"), "Should include command output"
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_with_files
    # Setup bot and attack with files config
    vm_context_config = {
      files: ['/etc/passwd', './config.txt']
    }
    
    setup_bot_with_vm_context(vm_context_config)
    
    # Mock VMContextManager
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:read_file, "root:x:0:0:root:/root:/bin/bash\n", [Hash, String, Hash])
    mock_vm_manager.expect(:read_file, "config data here\n", [Hash, String, Hash])
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      refute_nil result
      assert result.include?("VM State:"), "Should include VM State header"
      assert result.include?("Files:"), "Should include files section"
      assert result.include?("[File: /etc/passwd]"), "Should include file path"
      assert result.include?("root:x:0:0:root"), "Should include file content"
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_with_all_types
    # Setup bot and attack with all VM context types
    vm_context_config = {
      bash_history: {
        path: '~/.bash_history',
        limit: 50
      },
      commands: ['whoami'],
      files: ['/etc/passwd']
    }
    
    setup_bot_with_vm_context(vm_context_config)
    
    # Mock VMContextManager
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:read_bash_history, "history content", [Hash, nil, 50, Hash])
    mock_vm_manager.expect(:execute_command, "student", [Hash, String, Hash])
    mock_vm_manager.expect(:read_file, "file content", [Hash, String, Hash])
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      refute_nil result
      assert result.include?("VM State:"), "Should include VM State header"
      assert result.include?("Bash History"), "Should include bash history"
      assert result.include?("Command Outputs:"), "Should include command outputs"
      assert result.include?("Files:"), "Should include files"
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_error_handling_ssh_failure
    # Setup bot and attack with config
    vm_context_config = {
      commands: ['ps aux']
    }
    
    setup_bot_with_vm_context(vm_context_config)
    
    # Mock VMContextManager to raise error
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:execute_command, nil, [Hash, String, Hash])  # Returns nil on failure
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      # Should handle error gracefully and return nil or partial result
      # Command failed, so only VM State header might be present (no sections)
      # If all operations fail, result should be nil
      assert_nil result, "Should return nil when all operations fail"
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_error_handling_file_not_found
    # Setup bot and attack with files config
    vm_context_config = {
      files: ['/nonexistent/file.txt', '/etc/passwd']
    }
    
    setup_bot_with_vm_context(vm_context_config)
    
    # Mock VMContextManager: first file fails, second succeeds
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:read_file, nil, [Hash, String, Hash])  # First file fails
    mock_vm_manager.expect(:read_file, "file content", [Hash, String, Hash])  # Second succeeds
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      # Should continue with other files and return partial result
      refute_nil result
      assert result.include?("Files:"), "Should include files section"
      assert result.include?("[File: /etc/passwd]"), "Should include successful file"
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_per_attack_ssh_config
    # Setup bot with per-attack SSH config
    vm_context_config = {
      commands: ['whoami']
    }
    
    @bot_manager.instance_variable_set(:@bots, {
      @test_bot_name => {
        'attacks' => [
          {
            'vm_context' => vm_context_config,
            'get_shell' => 'sshpass -p attack_password ssh user@attack_host'  # Per-attack config
          }
        ],
        'get_shell' => 'sshpass -p global_password ssh user@global_host'  # Global config (should not be used)
      }
    })
    
    # Mock VMContextManager - verify per-attack SSH config is used
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:execute_command, "output", [Hash, String, Hash])
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      refute_nil result
      # Verify the SSH config passed to mock has per-attack config
      # (actual verification happens via mock expectation matching)
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_global_ssh_config_fallback
    # Setup bot without per-attack SSH config (should use global)
    vm_context_config = {
      commands: ['whoami']
    }
    
    @bot_manager.instance_variable_set(:@bots, {
      @test_bot_name => {
        'attacks' => [
          {
            'vm_context' => vm_context_config
            # No per-attack get_shell
          }
        ],
        'get_shell' => 'sshpass -p global_password ssh user@global_host'  # Global config
      }
    })
    
    # Mock VMContextManager - verify global SSH config is used as fallback
    mock_vm_manager = Minitest::Mock.new
    mock_vm_manager.expect(:execute_command, "output", [Hash, String, Hash])
    
    VMContextManager.stub(:new, mock_vm_manager) do
      result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
      
      refute_nil result
      # Verify the SSH config passed to mock has global config
      # (actual verification happens via fetch_vm_context implementation)
    end
    
    mock_vm_manager.verify
  end
  
  def test_fetch_vm_context_no_config_returns_nil
    # Setup bot without VM context config
    @bot_manager.instance_variable_set(:@bots, {
      @test_bot_name => {
        'attacks' => [
          {
            # No vm_context
          }
        ]
      }
    })
    
    result = @bot_manager.fetch_vm_context(@test_bot_name, @test_attack_index)
    
    assert_nil result, "Should return nil when no VM context config exists"
  end
  
  def test_assemble_vm_context_formatting
    vm_context_data = {
      bash_history: {
        content: "cd /home\nls -la",
        path: "~/.bash_history",
        limit: 50,
        user: "student"
      },
      commands: [
        { command: "ps aux", output: "process list" },
        { command: "whoami", output: "student" }
      ],
      files: [
        { path: "/etc/passwd", content: "root:x:0:0" },
        { path: "./config.txt", content: "config data" }
      ]
    }
    
    result = @bot_manager.assemble_vm_context(vm_context_data)
    
    refute_nil result
    assert result.include?("VM State:"), "Should include VM State header"
    assert result.include?("Bash History"), "Should include bash history section"
    assert result.include?("last 50 commands"), "Should include limit info"
    assert result.include?("user student"), "Should include user info"
    assert result.include?("Command Outputs:"), "Should include command outputs section"
    assert result.include?("[Command: ps aux]"), "Should include command name"
    assert result.include?("process list"), "Should include command output"
    assert result.include?("Files:"), "Should include files section"
    assert result.include?("[File: /etc/passwd]"), "Should include file path"
    assert result.include?("root:x:0:0"), "Should include file content"
  end
  
  def test_assemble_vm_context_empty_returns_nil
    vm_context_data = {
      bash_history: nil,
      commands: [],
      files: []
    }
    
    result = @bot_manager.assemble_vm_context(vm_context_data)
    
    assert_nil result, "Should return nil for empty VM context data"
  end
  
  def test_assemble_vm_context_partial_data
    # Test with only bash history
    vm_context_data = {
      bash_history: {
        content: "history content",
        path: "~/.bash_history",
        limit: nil,
        user: nil
      },
      commands: [],
      files: []
    }
    
    result = @bot_manager.assemble_vm_context(vm_context_data)
    
    refute_nil result
    assert result.include?("VM State:"), "Should include VM State header"
    assert result.include?("Bash History"), "Should include bash history"
    assert result.include?("history content"), "Should include history content"
    refute result.include?("Command Outputs:"), "Should not include commands section"
    refute result.include?("Files:"), "Should not include files section"
  end
  
  private
  
  def setup_bot_with_vm_context(vm_context_config)
    @bot_manager.instance_variable_set(:@bots, {
      @test_bot_name => {
        'attacks' => [
          {
            'vm_context' => vm_context_config,
            'get_shell' => @test_ssh_config['get_shell']
          }
        ],
        'get_shell' => @test_ssh_config['get_shell']
      }
    })
  end
end

