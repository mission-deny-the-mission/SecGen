require_relative 'test_helper'
require 'fileutils'
require 'nori'

class TestXMLContextConfig < BotManagerTest
  def setup
    super
    # Create temporary config directory for test fixtures
    @test_config_dir = File.join(Dir.tmpdir, "hackerbot_test_configs_#{Time.now.to_i}")
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
  def parse_attack_with_context_config(config_content)
    doc = Nokogiri::XML(config_content)
    doc.remove_namespaces!
    
    bot_manager = create_bot_manager
    attacks = []
    
    doc.xpath('/hackerbot/attack').each do |attack_node|
      attack_data = Nori.new.parse(attack_node.to_s)['attack']
      
      # Parse context_config using private method
      context_config = bot_manager.send(:parse_context_config, attack_node)
      if context_config
        attack_data['context_config'] = context_config
      elsif attack_data.key?('context_config')
        # Remove context_config key if Nori parsed an empty element (creates nil value)
        attack_data.delete('context_config')
      end
      
      attacks << attack_data
    end
    
    attacks
  end

  def test_parse_comma_separated_man_pages
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
          <context_config>
            <man_pages>nmap,netcat,tcpdump</man_pages>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['nmap', 'netcat', 'tcpdump'], attack['context_config'][:man_pages]
  end

  def test_parse_individual_page_elements
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
          <context_config>
            <man_pages>
              <page>nmap</page>
              <page>netcat</page>
              <page>tcpdump</page>
            </man_pages>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['nmap', 'netcat', 'tcpdump'], attack['context_config'][:man_pages]
  end

  def test_parse_comma_separated_documents
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
          <context_config>
            <documents>attack-guide.md,docs/pentest.md</documents>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['attack-guide.md', 'docs/pentest.md'], attack['context_config'][:documents]
  end

  def test_parse_individual_doc_elements
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
          <context_config>
            <documents>
              <doc>attack-guide.md</doc>
              <doc>docs/pentest.md</doc>
            </documents>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['attack-guide.md', 'docs/pentest.md'], attack['context_config'][:documents]
  end

  def test_parse_comma_separated_mitre_techniques
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
          <context_config>
            <mitre_techniques>T1003,T1059.001</mitre_techniques>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['T1003', 'T1059.001'], attack['context_config'][:mitre_techniques]
  end

  def test_parse_individual_technique_elements
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
          <context_config>
            <mitre_techniques>
              <technique>T1003</technique>
              <technique>T1059.001</technique>
            </mitre_techniques>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['T1003', 'T1059.001'], attack['context_config'][:mitre_techniques]
  end

  def test_missing_context_config
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

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    refute attack.key?('context_config'), "Context config should not be present when missing"
  end

  def test_empty_context_config
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
          <context_config></context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    refute attack.key?('context_config'), "Context config should not be present when empty"
  end

  def test_self_closing_empty_context_config
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
          <context_config/>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    refute attack.key?('context_config'), "Context config should not be present when self-closing empty"
  end

  def test_whitespace_handling
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
          <context_config>
            <man_pages>  nmap  ,  netcat  ,  tcpdump  </man_pages>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['nmap', 'netcat', 'tcpdump'], attack['context_config'][:man_pages]
  end

  def test_duplicate_handling
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
          <context_config>
            <man_pages>nmap,nmap,netcat,nmap</man_pages>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['nmap', 'netcat'], attack['context_config'][:man_pages]
  end

  def test_mixed_formats
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
          <context_config>
            <man_pages>nmap,netcat</man_pages>
            <documents>
              <doc>attack-guide.md</doc>
            </documents>
            <mitre_techniques>T1003,T1059.001</mitre_techniques>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    assert attack.key?('context_config'), "Context config should be present"
    assert_equal ['nmap', 'netcat'], attack['context_config'][:man_pages]
    assert_equal ['attack-guide.md'], attack['context_config'][:documents]
    assert_equal ['T1003', 'T1059.001'], attack['context_config'][:mitre_techniques]
  end

  def test_multiple_attacks_with_different_context_configs
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
          <prompt>Attack 1</prompt>
          <context_config>
            <man_pages>nmap</man_pages>
          </context_config>
        </attack>
        <attack>
          <prompt>Attack 2</prompt>
          <context_config>
            <man_pages>netcat</man_pages>
            <documents>guide.md</documents>
          </context_config>
        </attack>
        <attack>
          <prompt>Attack 3</prompt>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)

    assert_equal 3, attacks.length
    assert attacks[0].key?('context_config'), "Attack 1 should have context_config"
    assert_equal ['nmap'], attacks[0]['context_config'][:man_pages]
    assert attacks[1].key?('context_config'), "Attack 2 should have context_config"
    assert_equal ['netcat'], attacks[1]['context_config'][:man_pages]
    assert_equal ['guide.md'], attacks[1]['context_config'][:documents]
    refute attacks[2].key?('context_config'), "Attack 3 should not have context_config"
  end

  def test_context_config_storage_accessibility
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
          <context_config>
            <man_pages>nmap,netcat</man_pages>
            <documents>guide.md</documents>
            <mitre_techniques>T1003</mitre_techniques>
          </context_config>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    
    # Verify accessible via expected path
    context_config = attacks[0]['context_config']
    
    refute_nil context_config
    assert_equal [:documents, :man_pages, :mitre_techniques], context_config.keys.sort
    assert_equal ['nmap', 'netcat'], context_config[:man_pages]
    assert_equal ['guide.md'], context_config[:documents]
    assert_equal ['T1003'], context_config[:mitre_techniques]
  end

  def test_backward_compatibility_existing_configs
    # Test that existing configs without context_config still work
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
          <quiz>
            <question>What is 2+2?</question>
            <answer>4</answer>
          </quiz>
        </attack>
      </hackerbot>
    XML

    attacks = parse_attack_with_context_config(config)
    attack = attacks[0]

    # Should have prompt and quiz, but no context_config
    assert attack.key?('prompt')
    assert attack.key?('quiz')
    refute attack.key?('context_config'), "Existing configs should not have context_config"
  end
end

