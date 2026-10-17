require_relative 'test_helper'
require 'fileutils'
require 'nori'

class TestVMContextConfig < BotManagerTest
  def setup
    super
    # Create temporary config directory for test fixtures
    @test_config_dir = File.join(Dir.tmpdir, "hackerbot_test_vm_context_#{Time.now.to_i}")
    FileUtils.mkdir_p(@test_config_dir) unless File.exist?(@test_config_dir)
  end

  def teardown
    super
    # Clean up test config directory
    FileUtils.rm_rf(@test_config_dir) if File.exist?(@test_config_dir)
  end

  # Helper method to create a test config file
  def create_test_config(content)
    file_path = File.join(@test_config_dir, "test_bot_#{Time.now.to_f}.xml")
    File.write(file_path, content)
    file_path
  end

  # Helper method to parse test config and return parsed attack data
  def parse_attack_with_vm_context(config_content)
    doc = Nokogiri::XML(config_content)
    doc.remove_namespaces!
    
    bot_manager = create_bot_manager
    attacks = []
    
    # Use //attack to find all attack elements regardless of structure (attack or attacks/attack)
    doc.xpath('//attack').each do |attack_node|
      attack_data = Nori.new.parse(attack_node.to_s)['attack']
      
      # Parse vm_context using private method
      vm_context = bot_manager.send(:parse_vm_context, attack_node)
      if vm_context
        attack_data['vm_context'] = vm_context
      elsif attack_data.key?('vm_context')
        # Remove vm_context key if Nori parsed an empty element
        attack_data.delete('vm_context')
      end
      
      attacks << attack_data
    end
    
    attacks
  end

  # Test bash_history parsing with all attributes
  def test_parse_bash_history_with_all_attributes
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <bash_history path="~/.zsh_history" limit="100" user="admin"/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert attack['vm_context'].key?(:bash_history), "Bash history should be present"
    assert_equal '~/.zsh_history', attack['vm_context'][:bash_history][:path]
    assert_equal 100, attack['vm_context'][:bash_history][:limit]
    assert_equal 'admin', attack['vm_context'][:bash_history][:user]
  end

  # Test bash_history with default path
  def test_parse_bash_history_defaults
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <bash_history/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert attack['vm_context'].key?(:bash_history), "Bash history should be present"
    assert_equal '~/.bash_history', attack['vm_context'][:bash_history][:path]
  end

  # Test bash_history with limit only
  def test_parse_bash_history_with_limit_only
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <bash_history limit="50"/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert_equal '~/.bash_history', attack['vm_context'][:bash_history][:path]
    assert_equal 50, attack['vm_context'][:bash_history][:limit]
    refute attack['vm_context'][:bash_history].key?(:user), "User should not be present"
  end

  # Test bash_history with user only
  def test_parse_bash_history_with_user_only
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <bash_history user="student"/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert_equal '~/.bash_history', attack['vm_context'][:bash_history][:path]
    assert_equal 'student', attack['vm_context'][:bash_history][:user]
    refute attack['vm_context'][:bash_history].key?(:limit), "Limit should not be present"
  end

  # Test commands parsing with multiple commands
  def test_parse_commands_multiple
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <commands>
              <command>ps aux</command>
              <command>netstat -tuln</command>
              <command>whoami</command>
            </commands>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert attack['vm_context'].key?(:commands), "Commands should be present"
    assert_equal ['ps aux', 'netstat -tuln', 'whoami'], attack['vm_context'][:commands]
  end

  # Test commands parsing with single command
  def test_parse_commands_single
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <commands>
              <command>ps aux</command>
            </commands>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert_equal ['ps aux'], attack['vm_context'][:commands]
  end

  # Test commands with empty element
  def test_parse_commands_empty
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <commands/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    # Empty commands should result in nil vm_context (all sub-elements empty)
    refute attack.key?('vm_context'), "VM context should not be present for empty config"
  end

  # Test files parsing with multiple file paths
  def test_parse_files_with_paths
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <files>
              <file path="/etc/passwd"/>
              <file path="./config.txt"/>
            </files>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert attack['vm_context'].key?(:files), "Files should be present"
    assert_equal ['/etc/passwd', './config.txt'], attack['vm_context'][:files]
  end

  # Test files parsing with single file path
  def test_parse_files_single
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <files>
              <file path="/etc/passwd"/>
            </files>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert_equal ['/etc/passwd'], attack['vm_context'][:files]
  end

  # Test files with empty element
  def test_parse_files_empty
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <files/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    # Empty files should result in nil vm_context (all sub-elements empty)
    refute attack.key?('vm_context'), "VM context should not be present for empty config"
  end

  # Test complete vm_context with all elements
  def test_parse_complete_vm_context
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <bash_history path="~/.zsh_history" limit="50" user="student"/>
            <commands>
              <command>ps aux</command>
              <command>netstat -tuln</command>
            </commands>
            <files>
              <file path="/etc/passwd"/>
              <file path="./config.txt"/>
            </files>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    vm_context = attack['vm_context']
    
    assert vm_context.key?(:bash_history), "Bash history should be present"
    assert_equal '~/.zsh_history', vm_context[:bash_history][:path]
    assert_equal 50, vm_context[:bash_history][:limit]
    assert_equal 'student', vm_context[:bash_history][:user]
    
    assert vm_context.key?(:commands), "Commands should be present"
    assert_equal ['ps aux', 'netstat -tuln'], vm_context[:commands]
    
    assert vm_context.key?(:files), "Files should be present"
    assert_equal ['/etc/passwd', './config.txt'], vm_context[:files]
  end

  # Test partial vm_context configuration
  def test_parse_partial_vm_context
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <bash_history path="~/.bash_history" limit="100"/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert attack['vm_context'].key?(:bash_history), "Bash history should be present"
    refute attack['vm_context'].key?(:commands), "Commands should not be present"
    refute attack['vm_context'].key?(:files), "Files should not be present"
  end

  # Test empty vm_context element (returns nil)
  def test_parse_empty_vm_context
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context/>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    # Empty vm_context should result in nil
    refute attack.key?('vm_context'), "VM context should not be present for empty element"
  end

  # Test missing vm_context element (default behavior)
  def test_parse_attack_without_vm_context
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    # Attack without vm_context should work unchanged
    assert_equal 'Test attack', attack['prompt']
    refute attack.key?('vm_context'), "VM context should not be present when not specified"
  end

  # Test multiple attacks with different VM configs
  def test_multiple_attacks_with_different_vm_contexts
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Attack 1</prompt>
            <vm_context>
              <bash_history limit="50"/>
            </vm_context>
          </attack>
          <attack>
            <prompt>Attack 2</prompt>
            <vm_context>
              <commands>
                <command>ps aux</command>
              </commands>
            </vm_context>
          </attack>
          <attack>
            <prompt>Attack 3</prompt>
            <!-- No vm_context -->
          </attack>
        </attacks>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)

    assert_equal 3, attacks.length
    
    # Attack 1 has bash_history only
    assert attacks[0].key?('vm_context'), "Attack 1 should have VM context"
    assert attacks[0]['vm_context'].key?(:bash_history), "Attack 1 should have bash_history"
    
    # Attack 2 has commands only
    assert attacks[1].key?('vm_context'), "Attack 2 should have VM context"
    assert attacks[1]['vm_context'].key?(:commands), "Attack 2 should have commands"
    
    # Attack 3 has no VM context
    refute attacks[2].key?('vm_context'), "Attack 3 should not have VM context"
  end

  # Test integration - verify vm_context parsing produces correct structure
  def test_vm_context_storage_accessibility
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attacks>
          <attack>
            <prompt>Test attack with VM context</prompt>
            <vm_context>
              <bash_history path="~/.bash_history" limit="50" user="student"/>
              <commands>
                <command>ps aux</command>
                <command>whoami</command>
              </commands>
              <files>
                <file path="/etc/passwd"/>
              </files>
            </vm_context>
          </attack>
        </attacks>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    assert_equal 1, attacks.length
    
    attack = attacks[0]
    assert attack.key?('vm_context'), "VM context should be stored in attack data"
    
    vm_context = attack['vm_context']
    assert vm_context.is_a?(Hash), "VM context should be a hash"
    assert vm_context.key?(:bash_history), "Bash history should be present"
    assert vm_context.key?(:commands), "Commands should be present"
    assert vm_context.key?(:files), "Files should be present"
    
    # Verify the structure matches what VMContextManager expects
    assert_equal '~/.bash_history', vm_context[:bash_history][:path]
    assert_equal 50, vm_context[:bash_history][:limit]
    assert_equal 'student', vm_context[:bash_history][:user]
    assert_equal ['ps aux', 'whoami'], vm_context[:commands]
    assert_equal ['/etc/passwd'], vm_context[:files]
  end

  # Test that commands with empty text are filtered out
  def test_parse_commands_filter_empty
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <commands>
              <command>ps aux</command>
              <command></command>
              <command>   </command>
              <command>whoami</command>
            </commands>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert_equal ['ps aux', 'whoami'], attack['vm_context'][:commands], "Empty commands should be filtered out"
  end

  # Test that file paths with empty values are filtered out
  def test_parse_files_filter_empty_paths
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <files>
              <file path="/etc/passwd"/>
              <file path=""/>
              <file path="   "/>
              <file path="./config.txt"/>
            </files>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert_equal ['/etc/passwd', './config.txt'], attack['vm_context'][:files], "Empty file paths should be filtered out"
  end

  # Test invalid limit attribute (non-numeric or zero)
  def test_parse_bash_history_invalid_limit
    config = <<~XML
      <hackerbot>
        <name>TestBot</name>
        <llm_provider>ollama</llm_provider>
        <ollama_model>gemma3:1b</ollama_model>
        <get_shell>bash</get_shell>
        <messages>
          <greeting>Hello</greeting>
        </messages>
        <attack>
          <prompt>Test attack</prompt>
          <vm_context>
            <bash_history path="~/.bash_history" limit="0"/>
          </vm_context>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_vm_context(config)
    attack = attacks[0]

    assert attack.key?('vm_context'), "VM context should be present"
    assert attack['vm_context'].key?(:bash_history), "Bash history should be present"
    refute attack['vm_context'][:bash_history].key?(:limit), "Zero limit should not be stored"
  end
end

