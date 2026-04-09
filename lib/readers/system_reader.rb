require 'nokogiri'
require 'digest'

require_relative '../objects/system'
require_relative '../objects/module'
require_relative '../objects/narrative_config'
require_relative 'xml_reader.rb'

class SystemReader < XMLReader

  # uses nokogiri to extract all system information from scenario.xml
  # This includes module filters, which are module objects that contain filters for selecting
  # from the actual modules that are available
  # @return [Array] Array containing Systems objects
  def self.read_scenario(scenario_file, options)
    systems = []
    # Parse and validate the schema
    doc = parse_doc(scenario_file, SCENARIO_SCHEMA_FILE, 'scenario')

    # for each CyBOK in the module
    doc.xpath("/scenario/CyBOK").each do |cybok_doc|
      $cybok_coverage.push(cybok_doc.clone)
    end

    # Parse narrative elements (scenario-level, not system-level)
    # Narrative generators produce content stored in $datastore for cross-system access
    $narrative_configs = read_narratives(doc)

    doc.xpath('/scenario/system').each_with_index do |system_node, system_index|
      module_selectors = []

      system_name = system_node.at_xpath('system_name').text
      Print.verbose "system: #{system_name}"

      # system attributes, such as basebox selection
      system_attributes = read_attributes(system_node)

      # literal values to store directly in a datastore
      system_node.xpath('*[@into_datastore]/value').each do |value|
        name = value.xpath('../@into_datastore').to_s
        ($datastore[name] ||= []).push(value.text)
      end

      # datastore in a datastore
      if system_node.xpath('//*[@into_datastore]/datastore').to_s != ""
        Print.err "WARNING: a datastore cannot capture the values from another datastore (this will be ignored)"
        Print.err "The scenario has datastore(s) that try to save directly into another datastore -- currently this is only possible via an encoder"
        sleep 2
      end

      # for each module selection
      system_node.xpath('.//vulnerability | .//service | .//utility | .//build | .//network | .//base | .//encoder | .//generator').each do |module_node|
        # create a selector module, which is a regular module instance used as a placeholder for matching requirements
        module_selector = Module.new(module_node.name)

        # create a unique id for tracking variables between modules
        module_selector.unique_id = module_node.path.gsub(/[^a-zA-Z0-9]/, '')
        # check if we need to be sending the module output to another module
        module_node.xpath('parent::input').each do |input|
          # Parent is input -- track that we need to send write value somewhere
          # if we need to feed results to parent module
          if input.xpath('@into').to_s
            input.xpath('..').each do |input_parent|
              module_selector.write_output_variable = input.xpath('@into').to_s
              module_selector.write_to_module_with_id = input_parent.path.gsub(/[^a-zA-Z0-9]/, '')
            end
          end
          # check if we need to send the module output to a datastore
          if input.xpath('@into_datastore').to_s != ''
            module_selector.write_to_datastore = input.xpath('@into_datastore').to_s
          end
          # check if we need to send the module path to a datastore (to ensure unique module selection)
          if input.xpath('@unique_module_list').to_s != ''
            module_selector.write_module_path_to_datastore = input.xpath('@unique_module_list').to_s
          end

        end

        # check if we are being passed an input *literal value*
        module_node.xpath('input/value').each do |input_value|
          variable = input_value.xpath('../@into').to_s
          value = input_value.text
          Print.verbose "  -- literal value: #{variable} = #{value}"
          (module_selector.received_inputs[variable] ||= []).push(value)
        end

        # check if we are being passed a datastore as input
        module_node.xpath('input/datastore').each do |input_value|
          access = input_value.xpath('@access').to_s
          if access == ''
            access = 'all'
          end
          access_json = input_value.xpath('@access_json').to_s
          variable = input_value.xpath('../@into').to_s
          value = input_value.text
          Print.verbose "  -- datastore: #{variable} = #{value}"
          (module_selector.received_datastores[variable] ||= []).push('variablename'   => value,
                                                                      'access'         => access,
                                                                      'access_json'    => access_json)
        end

        module_node.xpath('@*').each do |attr|
          module_selector.attributes["#{attr.name}"] = [attr.text] unless attr.text.nil? || attr.text == ''
        end
        Print.verbose " #{module_node.name} (#{module_selector.unique_id}), selecting based on:"
        module_selector.attributes.each do |attr|
          if attr[0] && attr[1] && attr[0].to_s != "module_type"
            Print.verbose "  - #{attr[0].to_s} ~= #{attr[1].to_s}"
          end
        end

        # If this module is for this system
        if module_selector.system_number == (system_index + 1)
          # insert into module list
          # if this module feeds output to another, ensure list order makes sense for processing...
          if module_selector.write_output_variable != nil
            Print.verbose "  -- writes to: #{module_selector.write_to_module_with_id} - #{module_selector.write_output_variable}"
            # insert into module list before the module we are writing to
            insert_pos = -1 # end of list
            for i in 0..module_selectors.size-1
              if module_selector.write_to_module_with_id == module_selectors[i].unique_id
                # found position of earlier module this one feeds into, so put this one first
                insert_pos = i
              end
            end
            module_selectors.insert(insert_pos, module_selector)
          else
            # otherwise just append module to end of list
            module_selectors << module_selector
          end
        end

      end
      systems << System.new(system_name, system_attributes, module_selectors, scenario_file, options)
    end

    return systems
  end

  # Parses <narrative> elements from the scenario XML.
  # Narrative elements are scenario-level (peers of <system>), containing
  # introduction generators and document generators. Their output is stored
  # in $datastore for cross-system access.
  #
  # @param doc [Nokogiri::XML::Document] the parsed scenario document
  # @return [Array<NarrativeConfig>] array of parsed narrative configurations
  def self.read_narratives(doc)
    narratives = []

    doc.xpath('/scenario/narrative').each_with_index do |narrative_node, narrative_index|
      config = NarrativeConfig.new

      # Extract narrative-level attributes
      config.theme = narrative_node.xpath('@theme').to_s
      config.cybok_ka = narrative_node.xpath('@cybok_ka').to_s
      config.cybok_topic = narrative_node.xpath('@cybok_topic').to_s

      Print.verbose "Narrative ##{narrative_index + 1}: theme=#{config.theme}, cybok_ka=#{config.cybok_ka}"

      # Parse <introduction> generator
      narrative_node.xpath('introduction/generator').each do |gen_node|
        module_selector = build_narrative_module_selector(gen_node, "narrative_introduction_#{narrative_index}", narrative_index)
        config.generators << {
          :datastore_key => "narrative_introduction",
          :module_selector => module_selector,
          :document_type => 'introduction',
          :document_name => 'introduction'
        }
        Print.verbose "  Narrative introduction generator: type=#{module_selector.attributes['type']}"
      end

      # Parse <documents>/<document> generators
      narrative_node.xpath('documents/document').each do |doc_node|
        doc_type = doc_node.xpath('@type').to_s
        doc_name = doc_node.xpath('@name').to_s
        datastore_key = doc_name.empty? ? "narrative_document_#{doc_type}" : "narrative_document_#{doc_name}"

        doc_node.xpath('generator').each do |gen_node|
          module_selector = build_narrative_module_selector(gen_node, "narrative_doc_#{doc_name}_#{narrative_index}", narrative_index)
          config.generators << {
            :datastore_key => datastore_key,
            :module_selector => module_selector,
            :document_type => doc_type,
            :document_name => doc_name
          }
          Print.verbose "  Narrative document generator: name=#{doc_name}, type=#{doc_type}, datastore=#{datastore_key}"
        end

        # Handle literal <value> content in documents (no generator)
        doc_node.xpath('value').each do |value_node|
          ($datastore[datastore_key] ||= []).push(value_node.text)
          Print.verbose "  Narrative document literal value: name=#{doc_name}, datastore=#{datastore_key}"
        end
      end

      # Handle literal <value> content in introduction (no generator)
      narrative_node.xpath('introduction/value').each do |value_node|
        ($datastore['narrative_introduction'] ||= []).push(value_node.text)
        Print.verbose "  Narrative introduction literal value"
      end

      narratives << config unless config.generators.empty? && $datastore['narrative_introduction'].nil?
    end

    narratives
  end

  # Builds a Module selector from a narrative <generator> XML node.
  # The selector will be used to find a matching generator module during resolution.
  #
  # @param gen_node [Nokogiri::XML::Element] the <generator> XML element
  # @param base_id [String] base string for the unique identifier
  # @param narrative_index [Integer] the index of the parent narrative element
  # @return [Module] a module selector instance
  def self.build_narrative_module_selector(gen_node, base_id, narrative_index)
    module_selector = Module.new('generator')

    # Create a unique ID for tracking
    module_selector.unique_id = "#{base_id}_#{gen_node.path.gsub(/[^a-zA-Z0-9]/, '')}"

    # Narrative generators write their output to $datastore
    module_selector.write_to_datastore = nil # Will be set by the caller via the datastore_key

    # Copy XML attributes as module filter attributes
    gen_node.xpath('@*').each do |attr|
      module_selector.attributes["#{attr.name}"] = [attr.text] unless attr.text.nil? || attr.text == ''
    end

    # Parse literal value inputs
    gen_node.xpath('input/value').each do |input_value|
      variable = input_value.xpath('../@into').to_s
      value = input_value.text
      Print.verbose "    -- narrative input: #{variable} = #{value}"
      (module_selector.received_inputs[variable] ||= []).push(value)
    end

    # Parse datastore inputs
    gen_node.xpath('input/datastore').each do |input_value|
      access = input_value.xpath('@access').to_s
      access = 'all' if access == ''
      access_json = input_value.xpath('@access_json').to_s
      variable = input_value.xpath('../@into').to_s
      value = input_value.text
      Print.verbose "    -- narrative datastore input: #{variable} = #{value}"
      (module_selector.received_datastores[variable] ||= []).push('variablename' => value,
                                                                    'access' => access,
                                                                    'access_json' => access_json)
    end

    module_selector
  end
end
