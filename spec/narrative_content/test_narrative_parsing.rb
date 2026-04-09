require_relative 'spec_helper'
require 'nokogiri'

# Tests for NarrativeConfig and SystemReader narrative parsing.
# These test the integration of narrative XML parsing into the SecGen pipeline.
#
# Note: SystemReader requires the full SecGen lib path, so we test the
# narrative parsing logic in isolation by testing NarrativeConfig and
# the XML parsing patterns directly.

class TestNarrativeParsing < Minitest::Test

  # --- NarrativeConfig object tests ---

  def test_narrative_config_initialization
    # Load the NarrativeConfig class directly
    require_relative '../../lib/objects/narrative_config'

    config = NarrativeConfig.new
    assert_nil config.theme
    assert_nil config.cybok_ka
    assert_nil config.cybok_topic
    assert_equal [], config.generators
  end

  def test_narrative_config_attributes
    require_relative '../../lib/objects/narrative_config'

    config = NarrativeConfig.new
    config.theme = 'espionage'
    config.cybok_ka = 'MAT'
    config.cybok_topic = 'Exploitation'

    assert_equal 'espionage', config.theme
    assert_equal 'MAT', config.cybok_ka
    assert_equal 'Exploitation', config.cybok_topic
  end

  def test_narrative_config_generators_structure
    require_relative '../../lib/objects/narrative_config'

    config = NarrativeConfig.new
    config.generators << {
      datastore_key: 'narrative_introduction',
      module_selector: nil, # would be a Module instance in production
      document_type: 'introduction',
      document_name: 'introduction'
    }
    config.generators << {
      datastore_key: 'narrative_document_emails',
      module_selector: nil,
      document_type: 'email_chain',
      document_name: 'emails'
    }

    assert_equal 2, config.generators.length
    assert_equal 'narrative_introduction', config.generators[0][:datastore_key]
    assert_equal 'email_chain', config.generators[1][:document_type]
  end

  # --- XML narrative element parsing tests ---
  # These test the XML structure that system_reader.rb's read_narratives method parses.

  def test_narrative_xml_structure_with_introduction
    xml = <<~XML
      <scenario>
        <narrative theme="espionage" cybok_ka="MAT">
          <introduction>
            <generator type="llm_ctf_narrative">
              <input into="theme"><value>espionage</value></input>
            </generator>
          </introduction>
        </narrative>
      </scenario>
    XML

    doc = Nokogiri::XML(xml)
    narrative = doc.at_xpath('/scenario/narrative')

    refute_nil narrative
    assert_equal 'espionage', narrative.xpath('@theme').to_s
    assert_equal 'MAT', narrative.xpath('@cybok_ka').to_s

    intro_gen = narrative.at_xpath('introduction/generator')
    refute_nil intro_gen
    assert_equal 'llm_ctf_narrative', intro_gen.xpath('@type').to_s
  end

  def test_narrative_xml_structure_with_documents
    xml = <<~XML
      <scenario>
        <narrative theme="investigation">
          <documents>
            <document type="email_chain" name="suspicious_emails">
              <generator type="llm_email_chain">
                <input into="theme"><value>insider_threat</value></input>
                <input into="num_emails"><value>5</value></input>
              </generator>
            </document>
            <document type="memo" name="security_policy">
              <generator type="llm_memo">
                <input into="memo_type"><value>policy_announcement</value></input>
              </generator>
            </document>
          </documents>
        </narrative>
      </scenario>
    XML

    doc = Nokogiri::XML(xml)
    documents = doc.xpath('/scenario/narrative/documents/document')

    assert_equal 2, documents.length

    # First document
    doc1 = documents[0]
    assert_equal 'email_chain', doc1.xpath('@type').to_s
    assert_equal 'suspicious_emails', doc1.xpath('@name').to_s
    gen1 = doc1.at_xpath('generator')
    assert_equal 'llm_email_chain', gen1.xpath('@type').to_s

    # Second document
    doc2 = documents[1]
    assert_equal 'memo', doc2.xpath('@type').to_s
    assert_equal 'security_policy', doc2.xpath('@name').to_s
  end

  def test_narrative_xml_literal_values
    xml = <<~XML
      <scenario>
        <narrative theme="investigation">
          <introduction>
            <value>This is a literal introduction text.</value>
          </introduction>
          <documents>
            <document type="email_chain" name="static_emails">
              <value>Static email content here.</value>
            </document>
          </documents>
        </narrative>
      </scenario>
    XML

    doc = Nokogiri::XML(xml)

    intro_value = doc.at_xpath('/scenario/narrative/introduction/value')
    refute_nil intro_value
    assert_equal 'This is a literal introduction text.', intro_value.text

    doc_value = doc.at_xpath('/scenario/narrative/documents/document/value')
    refute_nil doc_value
    assert_equal 'Static email content here.', doc_value.text
  end

  def test_narrative_datastore_key_naming
    # Test the datastore key naming convention used in system_reader.rb
    doc_type = 'email_chain'
    doc_name = 'suspicious_emails'
    datastore_key = doc_name.empty? ? "narrative_document_#{doc_type}" : "narrative_document_#{doc_name}"

    assert_equal 'narrative_document_suspicious_emails', datastore_key

    # When name is empty
    doc_name_empty = ''
    datastore_key_empty = doc_name_empty.empty? ? "narrative_document_#{doc_type}" : "narrative_document_#{doc_name_empty}"
    assert_equal 'narrative_document_email_chain', datastore_key_empty
  end

  def test_multiple_narratives_in_scenario
    xml = <<~XML
      <scenario>
        <narrative theme="espionage" cybok_ka="MAT">
          <introduction>
            <generator type="llm_ctf_narrative"/>
          </introduction>
        </narrative>
        <narrative theme="investigation" cybok_ka="SOIM">
          <documents>
            <document type="log_entry" name="auth_logs">
              <generator type="llm_log_entry"/>
            </document>
          </documents>
        </narrative>
      </scenario>
    XML

    doc = Nokogiri::XML(xml)
    narratives = doc.xpath('/scenario/narrative')

    assert_equal 2, narratives.length
    assert_equal 'espionage', narratives[0].xpath('@theme').to_s
    assert_equal 'investigation', narratives[1].xpath('@theme').to_s
  end

  def test_narrative_generator_inputs_parsing
    xml = <<~XML
      <scenario>
        <narrative theme="espionage">
          <documents>
            <document type="email_chain" name="emails">
              <generator type="llm_email_chain">
                <input into="theme"><value>insider_threat</value></input>
                <input into="num_emails"><value>5</value></input>
                <input into="organisation"><datastore>organisation</datastore></input>
              </generator>
            </document>
          </documents>
        </narrative>
      </scenario>
    XML

    doc = Nokogiri::XML(xml)
    gen = doc.at_xpath('/scenario/narrative/documents/document/generator')

    # Parse literal inputs
    literal_inputs = {}
    gen.xpath('input/value').each do |val|
      variable = val.xpath('../@into').to_s
      literal_inputs[variable] = val.text
    end

    assert_equal({ 'theme' => 'insider_threat', 'num_emails' => '5' }, literal_inputs)

    # Parse datastore inputs
    datastore_inputs = []
    gen.xpath('input/datastore').each do |ds|
      variable = ds.xpath('../@into').to_s
      datastore_inputs << { variable => ds.text }
    end

    assert_equal([{ 'organisation' => 'organisation' }], datastore_inputs)
  end
end
