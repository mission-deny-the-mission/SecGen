require_relative '../helpers/constants.rb'

# Represents a parsed narrative element from a scenario XML.
# Narrative elements are scenario-level (peers of <system>), containing
# introduction generators and document generators that produce LLM content
# stored in $datastore for cross-system access.
class NarrativeConfig
  attr_accessor :theme
  attr_accessor :cybok_ka
  attr_accessor :cybok_topic
  # Array of hashes, each containing:
  #   :datastore_key - the key under which to store generated content in $datastore
  #   :module_selector - a Module instance used as a filter for selecting the generator
  #   :document_type - the type attribute from <document> (e.g., 'email_chain', 'memo')
  #   :document_name - the name attribute from <document> (e.g., 'suspicious_emails')
  attr_accessor :generators

  def initialize
    self.generators = []
  end
end
