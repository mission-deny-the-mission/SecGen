require 'nokogiri'
require 'nori'
require 'cinch'
require_relative './print.rb'
require_relative './providers/llm_client_factory.rb'
require_relative './rag_manager.rb'
require_relative './vm_context_manager.rb'

class BotManager
  def initialize(irc_server_ip_address, llm_provider = 'ollama', ollama_host = 'localhost', ollama_port = 11434, ollama_model = 'gemma3:1b', openai_api_key = nil, openai_base_url = nil, vllm_host = 'localhost', vllm_port = 8000, sglang_host = 'localhost', sglang_port = 30000, enable_rag = false, rag_config = {})
    @irc_server_ip_address = irc_server_ip_address
    @llm_provider = llm_provider
    @ollama_host = ollama_host
    @ollama_port = ollama_port
    @ollama_model = ollama_model
    @openai_api_key = openai_api_key
    @openai_base_url = openai_base_url
    @vllm_host = vllm_host
    @vllm_port = vllm_port
    @sglang_host = sglang_host
    @sglang_port = sglang_port
    @bots = {}
    @user_chat_histories = Hash.new { |h, k| h[k] = {} } # {bot_name => {user_id => [history]}}
    # Enhanced IRC message history for full context capture
    # Structure: {bot_name => {channel => [messages]}} or {bot_name => {user_id => [messages]}}
    # Each message: {user: string, content: string, timestamp: Time, type: symbol, channel: string}
    @irc_message_history = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
    # Default history lengths (can be overridden per-bot via XML config)
    @max_history_length = 10  # For traditional chat history (user/assistant pairs)
    @max_irc_message_history = 20  # For enhanced IRC message history (configurable window)
    @enable_rag = enable_rag
    @rag_config = rag_config
    @rag_manager = nil
    # Configuration for message storage (per_channel or per_user)
    @message_storage_mode = :per_user # or :per_channel

    # Set default offline mode
    @rag_config[:offline_mode] ||= 'auto'  # Default to auto-detect
    @rag_config[:enable_rag] = rag_config.fetch(:enable_rag, true)  # Default to enabled
    
    # Explicit context can work independently of RAG (similarity search)
    # Explicit context uses direct lookups via knowledge sources, not vector similarity
    @enable_explicit_context = rag_config.fetch(:enable_explicit_context, nil)  # nil = auto-detect: true if RAG enabled
    @knowledge_source_manager = nil

    # Initialize RAG manager if enabled (includes knowledge sources if enabled)
    if @enable_rag
      initialize_rag_manager
    elsif explicit_context_enabled?
      # Initialize knowledge sources only if explicit context enabled without RAG
      initialize_knowledge_sources_only
    end
  end

  def initialize_rag_manager
    Print.info "Initializing RAG Manager..."

    # Determine if we should use offline mode
    use_offline = case @rag_config[:offline_mode]
                  when 'offline'
                    true
                  when 'online'
                    false
                  else # 'auto'
                    # Simple connectivity check
                    begin
                      require 'socket'
                      Socket.getaddrinfo('localhost', nil)
                      use_offline = false
                    rescue
                      use_offline = true
                    end
                  end

    Print.info "Using #{use_offline ? 'offline' : 'online'} mode for RAG system"

    # Default RAG configuration with offline as default
    rag_settings = if use_offline
      {
        vector_db: {
          provider: 'chromadb',
          storage_path: './knowledge_bases/offline/vector_db',
          persist_embeddings: true,
          compression_enabled: true
        },
        embedding_service: {
          provider: 'ollama',
          model: 'nomic-embed-text',
          cache_embeddings: true,
          cache_path: './cache/embeddings',
          fallback_to_random: true
        },
        rag_settings: {
          max_results: 5,
          similarity_threshold: 0.7,
          enable_caching: true
        }
      }
    else
      {
        vector_db: {
          provider: 'chromadb',
          host: 'localhost',
          port: 8000
        },
        embedding_service: {
          provider: 'ollama',
          host: @ollama_host,
          port: @ollama_port,
          model: 'nomic-embed-text'
        },
        rag_settings: {
          max_results: 5,
          similarity_threshold: 0.7,
          enable_caching: true
        }
      }
    end

    # Override with user-provided configuration
    if @rag_config[:rag]
      rag_settings[:vector_db] = rag_settings[:vector_db].merge(@rag_config[:rag][:vector_db] || {})
      rag_settings[:embedding_service] = rag_settings[:embedding_service].merge(@rag_config[:rag][:embedding_service] || {})
      rag_settings[:rag_settings] = rag_settings[:rag_settings].merge(@rag_config[:rag][:rag_settings] || {})
    end

    config = {
      enable_rag: @rag_config[:enable_rag],
      max_context_length: @rag_config.fetch(:max_context_length, 4000),
      knowledge_base_name: @rag_config.fetch(:knowledge_base_name, 'cybersecurity'),
      enable_caching: @rag_config.fetch(:enable_caching, true),
      auto_initialization: @rag_config.fetch(:auto_initialization, true),
      enable_knowledge_sources: @rag_config.fetch(:enable_knowledge_sources, true),
      knowledge_sources_config: @rag_config.fetch(:knowledge_sources_config, []),
      max_results: @rag_config.fetch(:max_results, 5),
      similarity_threshold: @rag_config.fetch(:similarity_threshold, 0.7)
    }

    Print.info "Creating RAGOnlyManager with config knowledge_base_name: #{config[:knowledge_base_name].inspect}"
    @rag_manager = RAGOnlyManager.new(rag_settings, config)

    Print.info "Setting up RAGOnlyManager..."
    unless @rag_manager.setup
      Print.err "Failed to initialize RAG Manager"
      @rag_manager = nil
    else
      Print.info "✓ RAGOnlyManager setup successful"
    end
    
    # Store knowledge source manager reference for explicit context access
    @knowledge_source_manager = @rag_manager.knowledge_source_manager if @rag_manager
  end

  # Initialize knowledge sources only (without RAG similarity search)
  # Used when explicit context is enabled but RAG is disabled
  def initialize_knowledge_sources_only
    Print.info "Initializing Knowledge Sources (without RAG)..."
    
    require_relative './knowledge_bases/knowledge_source_manager.rb'
    
    config = {
      enable_knowledge_sources: true,
      knowledge_sources_config: @rag_config.fetch(:knowledge_sources_config, []),
      knowledge_base_name: @rag_config.fetch(:knowledge_base_name, 'cybersecurity')
    }
    
    @knowledge_source_manager = KnowledgeSourceManager.new(config)
    
    sources_config = @rag_config[:knowledge_sources_config] || default_knowledge_sources_config
    unless @knowledge_source_manager.initialize_sources(sources_config)
      Print.err "Failed to initialize Knowledge Source Manager"
      @knowledge_source_manager = nil
      return false
    end
    
    Print.info "✓ Knowledge Source Manager initialized successfully (explicit context enabled)"
    true
  end
  
  # Default knowledge sources config for explicit context only mode
  def default_knowledge_sources_config
    [
      {
        type: 'mitre_attack',
        name: 'mitre_attack',
        enabled: true,
        priority: 1
      },
      {
        type: 'man_pages',
        name: 'man_pages',
        enabled: true,
        priority: 2,
        config: {
          man_page_paths: ['/usr/share/man', '/usr/local/share/man'],
          sections: [1, 8],
          cache_enabled: true
        }
      },
      {
        type: 'markdown_files',
        name: 'markdown_files',
        enabled: true,
        priority: 3,
        config: {
          directory_paths: ['docs', 'knowledge_bases'],
          file_patterns: ['*.md', '*.markdown'],
          cache_enabled: true
        }
      }
    ]
  end
  
  # Check if explicit context is enabled
  def explicit_context_enabled?
    return true if @enable_explicit_context == true
    return false if @enable_explicit_context == false
    # Auto-detect: enabled if RAG is enabled (for backward compatibility)
    @enable_rag
  end

  def add_to_history(bot_name, user_id, user_message, assistant_response)
    @user_chat_histories[bot_name][user_id] ||= []
    @user_chat_histories[bot_name][user_id] << { user: user_message, assistant: assistant_response }
    # Get bot-specific max history length if configured, otherwise use default
    max_length = @bots.dig(bot_name, 'max_history_length') || @max_history_length
    if @user_chat_histories[bot_name][user_id].length > max_length
      @user_chat_histories[bot_name][user_id] = @user_chat_histories[bot_name][user_id].last(max_length)
    end
  end

  # Get chat context for LLM prompts
  #
  # Returns complete conversation thread from IRC message history, formatted for LLM consumption.
  # Supports configurable message filtering and context length management.
  #
  # Message type filtering uses bot-specific configuration from XML (message_type_filter element),
  # with a default of including user messages, bot LLM responses, and bot command responses
  # (excluding system messages).
  #
  # @param bot_name [String] The bot name
  # @param user_id [String] The user ID to get context for
  # @param options [Hash] Configuration options
  # @option options [Array<Symbol>] :include_types Message types to include (overrides bot-specific configuration if provided)
  # @option options [Integer] :max_context_length Maximum context length in characters (nil = no limit)
  # @option options [Boolean] :include_timestamps Include timestamps in formatted messages (default: false)
  # @option options [String] :exclude_message Content of message to exclude (typically the current message being processed)
  # @return [String] Formatted conversation context
  def get_chat_context(bot_name, user_id, options = {})
    # Default options: use bot-specific configuration if available, otherwise use default
    default_include_types = @bots.dig(bot_name, 'message_type_filter') || [:user_message, :bot_llm_response, :bot_command_response]
    include_types = options.fetch(:include_types, default_include_types)
    max_context_length = options.fetch(:max_context_length, nil)
    include_timestamps = options.fetch(:include_timestamps, false)
    exclude_message = options[:exclude_message]
    
    # Get IRC message history
    # In per_user mode: merge messages from both user and bot (bot messages stored under bot_name)
    # In per_channel mode: get messages from channel
    irc_history = []
    if @message_storage_mode == :per_channel
      channel_key = "##{bot_name}"
      irc_history = get_irc_message_history(bot_name, channel_key)
    else
      # per_user mode: merge user messages and bot messages
      user_history = get_irc_message_history(bot_name, user_id)
      bot_history = get_irc_message_history(bot_name, bot_name)
      # Merge and sort by timestamp to maintain chronological order
      irc_history = (user_history + bot_history).sort_by { |msg| msg[:timestamp] }
    end
    
    # Filter by message type if specified
    filtered_history = irc_history.select { |msg| include_types.include?(msg[:type]) }
    
    # Exclude the current message if specified (to avoid duplication in prompt)
    if exclude_message
      filtered_history = filtered_history.reject { |msg| msg[:content] == exclude_message }
    end
    
    # If no IRC history, fall back to traditional chat history for backward compatibility
    if filtered_history.empty?
      history = @user_chat_histories[bot_name][user_id] || []
      return '' if history.empty?
      context_parts = history.map do |exchange|
        "User: #{exchange[:user]}\nAssistant: #{exchange[:assistant]}"
      end
      context = context_parts.join("\n\n")
      
      # Apply length management if specified
      if max_context_length && context.length > max_context_length
        # Truncate from the beginning (oldest messages)
        context = context[-max_context_length..-1]
      end
      
      return context
    end
    
    # Format messages with clear speaker identification
    formatted_messages = filtered_history.map do |msg|
      speaker = case msg[:type]
                when :user_message
                  "User #{msg[:user]}:"
                when :bot_llm_response, :bot_command_response
                  "Bot:"
                when :system_message
                  "System:"
                else
                  "#{msg[:user]}:"
                end
      
      timestamp_str = include_timestamps ? " [#{msg[:timestamp].strftime('%H:%M:%S')}]" : ""
      "#{speaker}#{timestamp_str} #{msg[:content]}"
    end
    
    context = formatted_messages.join("\n")
    
    # Apply context length management if specified
    if max_context_length && context.length > max_context_length
      # Truncate from the beginning (oldest messages)
      # Try to truncate at message boundaries if possible
      truncated = context[-max_context_length..-1]
      # Find first newline to avoid cutting in the middle of a message
      first_newline = truncated.index("\n")
      if first_newline
        truncated = truncated[first_newline + 1..-1]
      end
      context = "... (earlier messages truncated) ...\n" + truncated
    end
    
    context
  end

  def clear_user_history(bot_name, user_id)
    @user_chat_histories[bot_name].delete(user_id)
  end

  # Classify message type based on message content and context
  #
  # @param message_text [String] The message content
  # @param is_from_bot [Boolean] Whether the message is from the bot itself
  # @param bot_responses [Array] Recent bot responses (for identifying LLM responses)
  # @return [Symbol] One of :user_message, :bot_llm_response, :bot_command_response, :system_message
  def classify_message_type(message_text, is_from_bot = false, bot_responses = [])
    if is_from_bot
      # Check if this is a bot command response (simple responses like "next", "ready", etc.)
      command_responses = /^(next|ready|hello|help|list|previous|clear_history|show_history|personalities|personality)$/i
      bot_command_patterns = /^(Moving to|Going to|Gaining shell|Shell access|Ready when|Try again|Correct!|Incorrect!|No quiz|Invalid)/
      
      if message_text.strip.match?(command_responses) || message_text.match?(bot_command_patterns) || 
         message_text.start_with?("**") || message_text.start_with?("Available personalities:") ||
         message_text.start_with?("Current personality:") || message_text.start_with?("Switched to") ||
         message_text.start_with?("Chat history") || message_text.start_with?("No chat history")
        return :bot_command_response
      end
      
      # Check if this matches recent LLM responses
      if bot_responses.any? { |resp| resp && message_text.include?(resp[0..50]) }
        return :bot_llm_response
      end
      
      # Default to LLM response if it's from bot and not a command
      return :bot_llm_response
    else
      # User messages
      system_patterns = /^(JOIN|PART|QUIT|NICK|MODE|TOPIC)/
      if message_text.match?(system_patterns)
        return :system_message
      end
      return :user_message
    end
  end

  # Capture all IRC channel messages with metadata
  #
  # @param bot_name [String] The bot name
  # @param user_nick [String] The user's nickname
  # @param message_content [String] The message content
  # @param channel [String] The channel name (e.g., "#bot_name")
  # @param message_type [Symbol, nil] Optional message type. If nil, will be auto-classified
  # @param is_from_bot [Boolean] Whether this message is from the bot
  def capture_irc_message(bot_name, user_nick, message_content, channel = nil, message_type = nil, is_from_bot = false)
    return if message_content.nil? || message_content.strip.empty?
    
    # Get channel if not provided
    channel ||= "##{bot_name}"
    
    # Classify message type if not provided
    if message_type.nil?
      # Get recent bot responses for classification
      recent_bot_responses = []
      if @irc_message_history[bot_name].key?(channel)
        recent_bot_responses = @irc_message_history[bot_name][channel]
          .select { |msg| msg[:type] == :bot_llm_response }
          .last(5)
          .map { |msg| msg[:content] }
      end
      
      message_type = classify_message_type(message_content, is_from_bot, recent_bot_responses)
    end
    
    # Create message entry
    message_entry = {
      user: user_nick,
      content: message_content,
      timestamp: Time.now,
      type: message_type,
      channel: channel
    }
    
    # Store based on configured mode
    storage_key = (@message_storage_mode == :per_channel) ? channel : user_nick
    
    # Add to history
    @irc_message_history[bot_name][storage_key] ||= []
    @irc_message_history[bot_name][storage_key] << message_entry
    
    # Enforce max history length (keep last N messages per storage key)
    # Get bot-specific max history if configured, otherwise use default
    max_length = @bots.dig(bot_name, 'max_irc_message_history') || @max_irc_message_history
    if @irc_message_history[bot_name][storage_key].length > max_length
      @irc_message_history[bot_name][storage_key] = @irc_message_history[bot_name][storage_key].last(max_length)
    end
  end

  # Get all captured IRC messages for a bot/user/channel
  #
  # @param bot_name [String] The bot name
  # @param key [String] User ID or channel name depending on storage mode
  # @return [Array] Array of message hashes with metadata
  def get_irc_message_history(bot_name, key)
    @irc_message_history[bot_name][key] || []
  end

  # Clear IRC message history for a specific key
  #
  # @param bot_name [String] The bot name
  # @param key [String] User ID or channel name to clear
  def clear_irc_message_history(bot_name, key)
    @irc_message_history[bot_name].delete(key)
  end

  # Prune IRC message history for a bot to enforce max length limits
  #
  # @param bot_name [String] The bot name
  # @param force [Boolean] If true, prune all keys; if false, only prune keys that exceed limit
  def prune_irc_message_history(bot_name, force = false)
    return unless @irc_message_history[bot_name]
    
    # Get bot-specific max history if configured, otherwise use default
    max_length = @bots.dig(bot_name, 'max_irc_message_history') || @max_irc_message_history
    
    @irc_message_history[bot_name].each do |key, messages|
      if force || messages.length > max_length
        @irc_message_history[bot_name][key] = messages.last(max_length)
      end
    end
  end

  # Prune traditional chat history for a bot to enforce max length limits
  #
  # @param bot_name [String] The bot name
  # @param user_id [String, nil] If provided, prune only this user's history; if nil, prune all users
  def prune_chat_history(bot_name, user_id = nil)
    return unless @user_chat_histories[bot_name]
    
    # Get bot-specific max history if configured, otherwise use default
    max_length = @bots.dig(bot_name, 'max_history_length') || @max_history_length
    
    if user_id
      # Prune specific user's history
      if @user_chat_histories[bot_name][user_id] && @user_chat_histories[bot_name][user_id].length > max_length
        @user_chat_histories[bot_name][user_id] = @user_chat_histories[bot_name][user_id].last(max_length)
      end
    else
      # Prune all users' history for this bot
      @user_chat_histories[bot_name].each do |uid, history|
        if history.length > max_length
          @user_chat_histories[bot_name][uid] = history.last(max_length)
        end
      end
    end
  end

  def get_enhanced_context(bot_name, user_message, attack_index: nil, variables: {})
    # Initialize enhanced_context hash to ensure we always return a consistent structure
    enhanced_context = nil
    
    # Check if bot has explicit context enabled (per-bot override)
    bot_explicit_context_enabled = get_bot_explicit_context_enabled(bot_name)
    
    # Check for explicit knowledge retrieval if attack_index provided and explicit context enabled
    if attack_index && bot_explicit_context_enabled
      explicit_context = retrieve_explicit_knowledge(bot_name, attack_index)
      if explicit_context && explicit_context[:has_explicit]
        Print.info "Using explicit knowledge retrieval for attack #{attack_index}"
        
        # Check if RAG similarity search is also available
        bot_rag_enabled = get_bot_rag_enabled(bot_name)
        if bot_rag_enabled && @rag_manager
          # Both explicit and RAG available - combine them
          enhanced_context = combine_explicit_and_rag_context(bot_name, user_message, explicit_context, attack_index: attack_index)
        else
          # Only explicit context available - return formatted explicit context only
          enhanced_context = format_explicit_only_context(explicit_context, attack_index: attack_index)
        end
      end
    end

    # Continue with RAG similarity search if enabled and no explicit context was found
    unless enhanced_context
      if @enable_rag && @rag_manager
        # Check if bot has specific RAG configuration
        rag_enabled = get_bot_rag_enabled(bot_name)
        unless rag_enabled == false
          # Get bot-specific context preferences
          context_options = {}
          Print.info "Getting enhanced context for bot: #{bot_name}"
          Print.info "Bot has rag_config: #{@bots.dig(bot_name, 'rag_config') ? 'YES' : 'NO'}"
          Print.info "Bot rag_enabled: #{rag_enabled}"

          if @bots.dig(bot_name, 'rag_config')
            context_options = {
              max_results: @bots.dig(bot_name, 'rag_config', 'max_results') || 5,
              custom_collection: @bots.dig(bot_name, 'rag_config', 'collection_name')
            }
            Print.info "Using bot-specific config, custom_collection: #{context_options[:custom_collection].inspect}"
          else
            # Use global settings if no bot-specific config
            context_options = {
              max_results: 5,
              custom_collection: @rag_config[:knowledge_base_name] || 'cybersecurity'
            }
            Print.info "Using global config fallback, custom_collection: #{context_options[:custom_collection].inspect}"
            Print.info "@rag_config[:knowledge_base_name]: #{@rag_config[:knowledge_base_name].inspect}"
          end

          # Get enhanced context from RAG manager
          enhanced_context = @rag_manager.get_enhanced_context(user_message, context_options)
          Print.debug "Enhanced context length: #{enhanced_context&.dig(:combined_context)&.length || 0} characters"
        end
      end
    end

    # Fetch VM context if attack has VM context configuration and it's enabled
    if attack_index && should_fetch_vm_context(bot_name, attack_index)
      begin
        vm_context = fetch_vm_context(bot_name, attack_index, variables)
        if vm_context && !vm_context.strip.empty?
          # Initialize enhanced_context if it doesn't exist
          enhanced_context ||= {}
          # Ensure it's a hash with required keys
          enhanced_context = { original_query: user_message } unless enhanced_context.is_a?(Hash)
          enhanced_context[:original_query] ||= user_message
          enhanced_context[:vm_context] = vm_context
          Print.debug "VM context fetched and added to enhanced context (#{vm_context.length} characters)"
        end
      rescue => e
        Print.warn "Failed to fetch VM context for bot '#{bot_name}' attack #{attack_index}: #{e.message}"
        # Continue without VM context
      end
    end

    # Ensure we have a consistent structure
    if enhanced_context && enhanced_context.is_a?(Hash)
      enhanced_context[:original_query] ||= user_message
    end

    # Return enhanced_context (may be nil if no RAG/explicit/VM context was available)
    enhanced_context
  end

  def extract_entities_from_message(bot_name, user_message)
    return nil unless @enable_rag_cag && @rag_cag_manager

    # Check if bot has entity extraction enabled
    entity_extraction_enabled = @bots.dig(bot_name, 'entity_extraction_enabled')
    return nil if entity_extraction_enabled == false

    # Check if CAG is enabled for this bot (entity extraction requires CAG)
    cag_enabled = @bots.dig(bot_name, 'cag_enabled')
    return nil if cag_enabled == false

    # Get bot-specific entity types
    entity_types = @bots.dig(bot_name, 'entity_types') || ['ip_address', 'url', 'hash', 'filename']

    # Extract entities
    entities = @rag_cag_manager.extract_entities(user_message, entity_types)
    Print.debug "Extracted #{entities&.length || 0} entities from message"
    entities
  end

  # Retrieve explicit knowledge items from context_config for a specific attack
  #
  # @param bot_name [String] The bot name
  # @param attack_index [Integer] The attack index
  # @return [Hash, nil] Returns hash with explicit_context, explicit_sources, has_explicit, or nil if no context_config
  def retrieve_explicit_knowledge(bot_name, attack_index)
    # Validate attack_index
    attacks = @bots.dig(bot_name, 'attacks')
    return nil unless attacks && attack_index >= 0 && attack_index < attacks.length

    attack = attacks[attack_index]
    context_config = attack['context_config'] || attack[:context_config]
    
    # Return nil if no context_config or empty
    return nil unless context_config
    return nil if context_config.empty?
    
    # Handle both string and symbol keys
    man_pages = context_config[:man_pages] || context_config['man_pages']
    documents = context_config[:documents] || context_config['documents']
    mitre_techniques = context_config[:mitre_techniques] || context_config['mitre_techniques']
    
    # Check if context_config has any non-empty arrays
    has_man_pages = man_pages && !man_pages.empty?
    has_documents = documents && !documents.empty?
    has_mitre_techniques = mitre_techniques && !mitre_techniques.empty?
    
    return nil unless has_man_pages || has_documents || has_mitre_techniques

    explicit_items = []
    explicit_sources = []
    not_found_items = []

    # Retrieve man pages
    if has_man_pages
      man_page_results = retrieve_man_pages(man_pages)
      man_page_results[:found].each { |item| explicit_items << item; explicit_sources << item[:metadata][:source] }
      not_found_items.concat(man_page_results[:not_found])
    end

    # Retrieve documents
    if has_documents
      document_results = retrieve_documents(documents)
      document_results[:found].each { |item| explicit_items << item; explicit_sources << item[:metadata][:source] }
      not_found_items.concat(document_results[:not_found])
    end

    # Retrieve MITRE techniques
    if has_mitre_techniques
      mitre_results = retrieve_mitre_techniques(mitre_techniques)
      mitre_results[:found].each { |item| explicit_items << item; explicit_sources << item[:metadata][:source] }
      not_found_items.concat(mitre_results[:not_found])
    end

    # Log warnings for items not found
    not_found_items.each do |item|
      Print.warn "Explicit knowledge item not found: #{item}"
    end

    # Log summary
    Print.info "Retrieved #{explicit_items.length}/#{explicit_items.length + not_found_items.length} explicit knowledge items"

    {
      explicit_context: explicit_items,
      explicit_sources: explicit_sources,
      has_explicit: !explicit_items.empty?
    }
  end

  # Retrieve man pages via knowledge source
  #
  # @param man_page_names [Array<String>] Array of man page names
  # @return [Hash] Hash with :found (array of RAG documents) and :not_found (array of names)
  def retrieve_man_pages(man_page_names)
    # Use knowledge source manager from RAG manager if available, otherwise use standalone
    ksm = @rag_manager ? @rag_manager.knowledge_source_manager : @knowledge_source_manager
    return { found: [], not_found: [] } unless ksm

    found_items = []
    not_found_items = []

    # Get man page knowledge source from knowledge source manager
    man_page_source = find_knowledge_source(ksm, 'man_pages')

    if man_page_source.nil?
      # Fallback: create instance on-demand if not found in manager
      require_relative './knowledge_bases/sources/man_pages/man_page_knowledge.rb'
      man_page_source = ManPageKnowledgeSource.new({})
    end

    man_page_names.each do |command_name|
      result = man_page_source.get_man_page_by_name(command_name)
      if result && result[:found]
        found_items << result[:rag_document]
      else
        not_found_items << "man page '#{command_name}'"
      end
    end

    { found: found_items, not_found: not_found_items }
  end

  # Retrieve documents via knowledge source
  #
  # @param document_paths [Array<String>] Array of document paths
  # @return [Hash] Hash with :found (array of RAG documents) and :not_found (array of paths)
  def retrieve_documents(document_paths)
    # Use knowledge source manager from RAG manager if available, otherwise use standalone
    ksm = @rag_manager ? @rag_manager.knowledge_source_manager : @knowledge_source_manager
    return { found: [], not_found: [] } unless ksm

    found_items = []
    not_found_items = []

    # Get markdown knowledge source from knowledge source manager
    markdown_source = find_knowledge_source(ksm, 'markdown_files')

    if markdown_source.nil?
      # Fallback: create instance on-demand if not found in manager
      require_relative './knowledge_bases/sources/markdown_files/markdown_knowledge.rb'
      markdown_source = MarkdownKnowledgeSource.new({})
    end

    document_paths.each do |file_path|
      result = markdown_source.get_document_by_path(file_path)
      if result && result[:found]
        found_items << result[:rag_document]
      else
        not_found_items << "document '#{file_path}'"
      end
    end

    { found: found_items, not_found: not_found_items }
  end

  # Retrieve MITRE techniques via knowledge source
  #
  # @param technique_ids [Array<String>] Array of MITRE technique IDs
  # @return [Hash] Hash with :found (array of RAG documents) and :not_found (array of IDs)
  def retrieve_mitre_techniques(technique_ids)
    found_items = []
    not_found_items = []

    require_relative './knowledge_bases/mitre_attack_knowledge.rb'

    technique_ids.each do |technique_id|
      result = MITREAttackKnowledge.get_technique_by_id(technique_id)
      if result && result[:found]
        found_items << result[:rag_document]
      else
        not_found_items << "MITRE technique '#{technique_id}'"
      end
    end

    { found: found_items, not_found: not_found_items }
  end

  # Find a knowledge source by type from knowledge source manager
  #
  # @param ksm [KnowledgeSourceManager] The knowledge source manager
  # @param source_type [String] The source type ('man_pages', 'markdown_files', etc.)
  # @return [Object, nil] The knowledge source instance or nil if not found
  def find_knowledge_source(ksm, source_type)
    return nil unless ksm

    # Ensure knowledge source classes are loaded
    require_relative './knowledge_bases/sources/man_pages/man_page_knowledge.rb'
    require_relative './knowledge_bases/sources/markdown_files/markdown_knowledge.rb'

    # Access sources via instance variable or public method if available
    sources = ksm.instance_variable_get(:@sources) if ksm.instance_variable_defined?(:@sources)
    return nil unless sources

    # Look for source by type (case-insensitive)
    sources.values.find do |source|
      source_type_matches = case source_type.downcase
                           when 'man_pages', 'manpage', 'man'
                             source.is_a?(ManPageKnowledgeSource)
                           when 'markdown_files', 'markdown', 'md'
                             source.is_a?(MarkdownKnowledgeSource)
                           else
                             false
                           end
      source_type_matches
    end
  end

  # Combine explicit knowledge with RAG similarity search results
  #
  # @param bot_name [String] The bot name
  # @param user_message [String] The user message
  # @param explicit_context [Hash] The explicit context hash
  # @param attack_index [Integer] The attack index for reading context config
  # @return [Hash] Enhanced context with both explicit and similarity search results
  def combine_explicit_and_rag_context(bot_name, user_message, explicit_context, attack_index: nil)
    # Determine combination mode from context config or use default
    combine_mode = get_combination_mode(bot_name, attack_index)
    
    # Format explicit knowledge items with length management
    formatting_options = {
      max_length: get_max_context_length,
      truncation_strategy: :proportional
    }
    formatted_explicit = format_explicit_knowledge(explicit_context[:explicit_context], formatting_options)

    # Get RAG similarity search results based on combination mode
    rag_context = nil
    if combine_mode != :explicit_only
      # Get bot-specific context preferences for similarity search
      context_options = {}
      if @bots.dig(bot_name, 'rag_config')
        context_options = {
          max_results: @bots.dig(bot_name, 'rag_config', 'max_results') || 5,
          custom_collection: @bots.dig(bot_name, 'rag_config', 'collection_name')
        }
      else
        context_options = {
          max_results: 5,
          custom_collection: @rag_config[:knowledge_base_name] || 'cybersecurity'
        }
      end

      rag_context = @rag_manager.get_enhanced_context(user_message, context_options)
    end
    
    enhanced_context = {
      original_query: user_message,
      rag_context: rag_context&.dig(:rag_context),
      explicit_context: explicit_context[:explicit_context],
      explicit_sources: explicit_context[:explicit_sources],
      has_explicit: true,
      combine_mode: combine_mode,
      combined_context: '',
      sources: explicit_context[:explicit_sources] + (rag_context&.dig(:sources) || []),
      timestamp: Time.now
    }

    # Combine formatted explicit context with similarity search results based on mode
    combined_context = build_combined_context(formatted_explicit, rag_context, combine_mode)
    
    # Apply final length management to combined context
    max_length = get_max_context_length
    if max_length && combined_context.length > max_length
      combined_context = apply_combined_length_management(combined_context, formatted_explicit, rag_context, max_length, combine_mode)
    end
    
    enhanced_context[:combined_context] = combined_context

    # Store sections separately for debugging
    enhanced_context[:explicit_section] = formatted_explicit
    enhanced_context[:similarity_section] = rag_context&.dig(:combined_context) || ''
    enhanced_context[:sections_present] = []
    enhanced_context[:sections_present] << 'explicit' unless formatted_explicit.strip.empty?
    enhanced_context[:sections_present] << 'similarity' if rag_context && rag_context[:combined_context] && !rag_context[:combined_context].strip.empty?

    enhanced_context
  end
  
  # Format explicit context only (without RAG similarity search)
  #
  # @param explicit_context [Hash] The explicit context hash
  # @param attack_index [Integer] The attack index for reading context config
  # @return [Hash] Enhanced context with only explicit knowledge
  def format_explicit_only_context(explicit_context, attack_index: nil)
    # Format explicit knowledge items with length management
    formatting_options = {
      max_length: get_max_context_length,
      truncation_strategy: :proportional
    }
    formatted_explicit = format_explicit_knowledge(explicit_context[:explicit_context], formatting_options)
    
    enhanced_context = {
      original_query: nil,  # Not available in explicit-only mode
      rag_context: nil,
      explicit_context: explicit_context[:explicit_context],
      explicit_sources: explicit_context[:explicit_sources],
      has_explicit: true,
      combine_mode: :explicit_only,
      combined_context: formatted_explicit,
      sources: explicit_context[:explicit_sources],
      timestamp: Time.now
    }
    
    # Store sections separately for debugging
    enhanced_context[:explicit_section] = formatted_explicit
    enhanced_context[:similarity_section] = ''
    enhanced_context[:sections_present] = formatted_explicit.strip.empty? ? [] : ['explicit']
    
    enhanced_context
  end
  
  # Get whether RAG is enabled for a specific bot
  #
  # @param bot_name [String] The bot name
  # @return [Boolean, nil] True if enabled, false if disabled, nil if using global setting
  def get_bot_rag_enabled(bot_name)
    bot_rag_enabled = @bots.dig(bot_name, 'rag_enabled')
    return bot_rag_enabled unless bot_rag_enabled.nil?
    # Use global setting if not specified per-bot
    @enable_rag
  end
  
  # Get whether explicit context is enabled for a specific bot
  #
  # @param bot_name [String] The bot name
  # @return [Boolean] True if enabled, false otherwise
  def get_bot_explicit_context_enabled(bot_name)
    bot_explicit_context_enabled = @bots.dig(bot_name, 'explicit_context_enabled')
    return bot_explicit_context_enabled unless bot_explicit_context_enabled.nil?
    # Use global setting if not specified per-bot
    explicit_context_enabled?
  end

  # Get whether VM context is enabled for a specific bot
  #
  # @param bot_name [String] The bot name
  # @return [Boolean, nil] True if enabled, false if disabled, nil if not specified (default: enabled if config exists)
  def get_bot_vm_context_enabled(bot_name)
    @bots.dig(bot_name, 'vm_context_enabled')
  end

  # Get whether VM context is enabled for a specific attack
  #
  # @param bot_name [String] The bot name
  # @param attack_index [Integer] The attack index
  # @return [Boolean, nil] True if enabled, false if disabled, nil if not specified (default: enabled if config exists)
  def get_attack_vm_context_enabled(bot_name, attack_index)
    return nil unless attack_index
    attacks = @bots.dig(bot_name, 'attacks')
    return nil unless attacks && attack_index >= 0 && attack_index < attacks.length
    attacks[attack_index]['vm_context_enabled']
  end

  # Check if VM context should be fetched for a bot and attack
  #
  # @param bot_name [String] The bot name
  # @param attack_index [Integer, nil] The attack index
  # @return [Boolean] True if VM context should be fetched
  def should_fetch_vm_context(bot_name, attack_index)
    return false unless attack_index
    
    # Check attack-level flag first
    attack_flag = get_attack_vm_context_enabled(bot_name, attack_index)
    return false if attack_flag == false
    return true if attack_flag == true
    
    # Check bot-level flag
    bot_flag = get_bot_vm_context_enabled(bot_name)
    return false if bot_flag == false
    return true if bot_flag == true
    
    # Default: enabled if vm_context config exists
    attacks = @bots.dig(bot_name, 'attacks')
    return false unless attacks && attack_index >= 0 && attack_index < attacks.length
    attacks[attack_index].key?('vm_context') && !attacks[attack_index]['vm_context'].nil?
  end

  # Get combination mode from context config or return default
  #
  # @param bot_name [String] The bot name
  # @param attack_index [Integer] The attack index
  # @return [Symbol] Combination mode (:explicit_only, :explicit_first, :combined, :similarity_fallback)
  def get_combination_mode(bot_name, attack_index)
    return :explicit_first unless attack_index

    attacks = @bots.dig(bot_name, 'attacks')
    return :explicit_first unless attacks && attack_index >= 0 && attack_index < attacks.length

    attack = attacks[attack_index]
    context_config = attack['context_config'] || attack[:context_config]
    return :explicit_first unless context_config

    # Get combine_mode from context_config
    combine_mode_str = context_config[:combine_mode] || context_config['combine_mode']
    return :explicit_first unless combine_mode_str

    # Normalize to symbol
    mode = combine_mode_str.to_s.downcase.to_sym
    valid_modes = [:explicit_only, :explicit_first, :combined, :similarity_fallback]
    
    if valid_modes.include?(mode)
      mode
    else
      Print.warn "Invalid combination mode '#{combine_mode_str}', using default 'explicit_first'"
      :explicit_first
    end
  end

  # Build combined context string based on combination mode
  #
  # @param formatted_explicit [String] Formatted explicit context
  # @param rag_context [Hash, nil] RAG similarity search results
  # @param combine_mode [Symbol] Combination mode
  # @return [String] Combined formatted context
  def build_combined_context(formatted_explicit, rag_context, combine_mode)
    has_explicit = formatted_explicit && !formatted_explicit.strip.empty?
    has_similarity = rag_context && rag_context[:combined_context] && !rag_context[:combined_context].strip.empty?

    case combine_mode
    when :explicit_only
      # Use only explicit items, ignore similarity
      formatted_explicit || ''
    when :explicit_first
      # Use explicit items, fall back to similarity if explicit empty
      if has_explicit
        formatted_explicit
      elsif has_similarity
        rag_context[:combined_context]
      else
        ''
      end
    when :combined
      # Use both explicit and similarity
      if has_explicit && has_similarity
        "#{formatted_explicit}\n\n---\n\nSimilarity Search Results:\n#{rag_context[:combined_context]}"
      elsif has_explicit
        formatted_explicit
      elsif has_similarity
        rag_context[:combined_context]
      else
        ''
      end
    when :similarity_fallback
      # Use similarity if explicit not available
      if has_explicit
        formatted_explicit
      elsif has_similarity
        rag_context[:combined_context]
      else
        ''
      end
    else
      # Default: explicit_first behavior
      if has_explicit
        formatted_explicit
      elsif has_similarity
        rag_context[:combined_context]
      else
        ''
      end
    end
  end

  # Apply length management to combined context
  #
  # @param combined_context [String] The combined context string
  # @param formatted_explicit [String] The formatted explicit section
  # @param rag_context [Hash, nil] The RAG similarity search results
  # @param max_length [Integer] Maximum context length
  # @param combine_mode [Symbol] Combination mode
  # @return [String] Length-managed combined context
  def apply_combined_length_management(combined_context, formatted_explicit, rag_context, max_length, combine_mode)
    return combined_context if combined_context.length <= max_length

    has_explicit = formatted_explicit && !formatted_explicit.strip.empty?
    has_similarity = rag_context && rag_context[:combined_context] && !rag_context[:combined_context].strip.empty?

    case combine_mode
    when :combined
      # Allocate space proportionally (60% explicit, 40% similarity)
      explicit_max = (max_length * 0.6).to_i
      similarity_max = (max_length * 0.4).to_i
      
      truncated_explicit = if has_explicit && formatted_explicit.length > explicit_max
        truncate_formatted_context(formatted_explicit, explicit_max, :proportional)
      else
        formatted_explicit
      end
      
      truncated_similarity = if has_similarity && rag_context[:combined_context].length > similarity_max
        similarity_content = rag_context[:combined_context]
        truncated = similarity_content[0, similarity_max - 50] # Reserve space for truncation indicator
        last_newline = truncated.rindex("\n")
        truncated = similarity_content[0, last_newline] if last_newline && last_newline > similarity_max * 0.5
        truncated + "\n\n[Similarity search results truncated...]"
      else
        rag_context[:combined_context]
      end
      
      combined = "#{truncated_explicit}\n\n---\n\nSimilarity Search Results:\n#{truncated_similarity}"
      Print.info "Combined context allocated: explicit=#{truncated_explicit.length}, similarity=#{truncated_similarity.length}, total=#{combined.length} (max: #{max_length})"
      combined
    else
      # For other modes, use simple truncation
      truncate_formatted_context(combined_context, max_length, :proportional)
    end
  end

  # Format explicit knowledge items grouped by type with section headers
  #
  # @param explicit_items [Array<Hash>] Array of RAG documents
  # @param options [Hash] Formatting options
  # @option options [Integer] :max_length Maximum character length for formatted context
  # @option options [Symbol] :truncation_strategy Truncation strategy (:proportional, :last_items, :longest_items)
  # @return [String] Formatted context string grouped by type
  def format_explicit_knowledge(explicit_items, options = {})
    return '' if explicit_items.nil? || explicit_items.empty?

    # Group items by source_type
    grouped_items = {
      'man_page' => [],
      'markdown' => [],
      'mitre_attack' => []
    }

    explicit_items.each do |item|
      metadata = item[:metadata] || {}
      source_type = metadata[:source_type]
      
      # Normalize source type
      normalized_type = case source_type
                        when 'man_page', 'manpage', 'man'
                          'man_page'
                        when 'markdown', 'md', 'document'
                          'markdown'
                        when 'mitre_attack', 'mitre', 'attack_pattern', 'sub_technique'
                          'mitre_attack'
                        else
                          # Unknown type, try to infer from source
                          source_str = (metadata[:source] || '').to_s.downcase
                          if source_str.include?('man page') || source_str.include?('man')
                            'man_page'
                          elsif source_str.include?('mitre') || source_str.include?('attack')
                            'mitre_attack'
                          else
                            'markdown' # Default to markdown for unknown types
                          end
                        end
      
      grouped_items[normalized_type] << item if grouped_items.key?(normalized_type)
    end

    # Format each group with section headers
    formatted_sections = []

    # Format Man Pages Section
    if !grouped_items['man_page'].empty?
      man_page_section = format_man_pages_section(grouped_items['man_page'])
      formatted_sections << man_page_section if man_page_section && !man_page_section.strip.empty?
    end

    # Format Documents Section
    if !grouped_items['markdown'].empty?
      document_section = format_documents_section(grouped_items['markdown'])
      formatted_sections << document_section if document_section && !document_section.strip.empty?
    end

    # Format MITRE Techniques Section
    if !grouped_items['mitre_attack'].empty?
      mitre_section = format_mitre_techniques_section(grouped_items['mitre_attack'])
      formatted_sections << mitre_section if mitre_section && !mitre_section.strip.empty?
    end

    # Combine all sections with header
    return '' if formatted_sections.empty?

    combined = "Explicit Knowledge Sources:\n\n" + formatted_sections.join("\n\n")

    # Apply length management if needed
    max_length = options[:max_length] || get_max_context_length
    if max_length && combined.length > max_length
      combined = truncate_formatted_context(combined, max_length, options[:truncation_strategy])
    end

    combined
  end

  # Format man pages section with source attribution
  #
  # @param man_page_items [Array<Hash>] Array of man page RAG documents
  # @return [String] Formatted man pages section or empty string
  def format_man_pages_section(man_page_items)
    return '' if man_page_items.nil? || man_page_items.empty?

    formatted_items = []
    man_page_items.each do |item|
      metadata = item[:metadata] || {}
      content = item[:content] || ''
      command_name = metadata[:command_name] || metadata[:source] || 'unknown'
      
      # Format source attribution
      source = "man page '#{command_name}'"
      formatted_item = "Source: #{source}\n\n#{content}"
      formatted_items << formatted_item
    end

    "--- Man Pages ---\n" + formatted_items.join("\n\n")
  end

  # Format documents section with source attribution
  #
  # @param document_items [Array<Hash>] Array of document RAG documents
  # @return [String] Formatted documents section or empty string
  def format_documents_section(document_items)
    return '' if document_items.nil? || document_items.empty?

    formatted_items = []
    document_items.each do |item|
      metadata = item[:metadata] || {}
      content = item[:content] || ''
      file_path = metadata[:file_path] || metadata[:source] || 'unknown'
      
      # Extract filename from path
      filename = file_path.to_s.split('/').last || file_path
      
      # Format source attribution
      source = "document '#{filename}'"
      formatted_item = "Source: #{source}\n\n#{content}"
      formatted_items << formatted_item
    end

    "--- Documents ---\n" + formatted_items.join("\n\n")
  end

  # Format MITRE techniques section with structured information
  #
  # @param mitre_items [Array<Hash>] Array of MITRE technique RAG documents
  # @return [String] Formatted MITRE techniques section or empty string
  def format_mitre_techniques_section(mitre_items)
    return '' if mitre_items.nil? || mitre_items.empty?

    formatted_items = []
    mitre_items.each do |item|
      metadata = item[:metadata] || {}
      content = item[:content] || ''
      technique_id = metadata[:technique_id] || metadata[:id] || 'unknown'
      technique_name = metadata[:technique_name] || metadata[:name] || ''
      tactic = metadata[:tactic] || ''
      
      # Format source attribution and structured information
      source = "MITRE ATT&CK #{technique_id}"
      formatted_item = "Source: #{source}"
      
      # Add structured fields if available
      if !technique_name.empty?
        formatted_item += "\nTechnique: #{technique_name}"
      end
      if !tactic.empty?
        formatted_item += "\nTactic: #{tactic}"
      end
      
      formatted_item += "\n\n#{content}"
      formatted_items << formatted_item
    end

    "--- MITRE ATT&CK Techniques ---\n" + formatted_items.join("\n\n")
  end

  # Truncate formatted context if it exceeds max_length
  #
  # @param formatted_context [String] The formatted context string
  # @param max_length [Integer] Maximum character length
  # @param strategy [Symbol] Truncation strategy (:proportional, :last_items, :longest_items)
  # @return [String] Truncated formatted context
  def truncate_formatted_context(formatted_context, max_length, strategy = :proportional)
    return formatted_context if formatted_context.length <= max_length

    # For now, implement simple truncation that preserves headers
    # TODO: Implement more sophisticated truncation strategies
    if formatted_context.length > max_length
      # Keep header and truncate content proportionally
      # Reserve space for header and truncation indicator
      reserved_space = 100
      max_content_length = max_length - reserved_space
      
      # Try to truncate at section boundaries
      truncated = formatted_context[0, max_content_length]
      
      # Find last section separator before truncation point
      last_separator = truncated.rindex("\n\n---")
      if last_separator && last_separator > max_content_length * 0.5
        truncated = formatted_context[0, last_separator]
      end
      
      truncated += "\n\n[Content truncated to fit context length limit...]"
      
      Print.warn "Formatted context truncated from #{formatted_context.length} to #{truncated.length} characters (max: #{max_length})"
      return truncated
    end

    formatted_context
  end

  # Get maximum context length from RAG config
  #
  # @return [Integer] Maximum context length or default
  def get_max_context_length
    @rag_config.fetch(:max_context_length, 4000)
  end

  def read_bots
    Dir.glob("config/*.xml").each do |file|
      print "#{file}"

      begin
        doc = Nokogiri::XML(File.read(file))
        if doc.errors.any?
          Print.err doc.errors
        end
      rescue
        Print.err "Failed to read hackerbot file (#{file})"
        print "Failed to read hackerbot file (#{file})"
        exit
      end

      # remove xml namespaces for ease of processing
      doc.remove_namespaces!

      doc.xpath('/hackerbot').each_with_index do |hackerbot|
        bot_name = hackerbot.at_xpath('name').text
        Print.debug bot_name
        @bots[bot_name] = {}

        get_shell = hackerbot.at_xpath('get_shell').text
        Print.debug get_shell
        @bots[bot_name]['get_shell'] = get_shell

        @bots[bot_name]['messages'] = Nori.new.parse(hackerbot.at_xpath('//messages').to_s)['messages']
        Print.debug @bots[bot_name]['messages'].to_s

        # Initialize personality system
        initialize_personalities(bot_name)

        # Parse personalities if they exist
        personalities_node = hackerbot.at_xpath('//personalities')
        if personalities_node
          parse_personalities(bot_name, personalities_node)

          # Set default personality
          default_personality_node = hackerbot.at_xpath('//default_personality')
          if default_personality_node
            @bots[bot_name]['default_personality'] = default_personality_node.text
          elsif !@bots[bot_name]['personalities'].empty?
            # Use first personality as default
            @bots[bot_name]['default_personality'] = @bots[bot_name]['personalities'].keys.first
          end
        end

        @bots[bot_name]['attacks'] = []
        hackerbot.xpath('//attack').each do |attack|
          attack_data = Nori.new.parse(attack.to_s)['attack']
          # Extract system prompt for this attack if specified
          attack_xml = attack.to_s
          if attack_xml.include?('<system_prompt>')
            # Parse the system prompt from the attack XML
            attack_doc = Nokogiri::XML(attack_xml)
            attack_doc.remove_namespaces!
            system_prompt = attack_doc.at_xpath('//system_prompt')&.text
            if system_prompt
              attack_data['system_prompt'] = system_prompt
            end
          end
          
          # Parse context_config for this attack if specified
          # Note: We use the original attack node (which already has namespaces removed)
          context_config = parse_context_config(attack)
          if context_config
            attack_data['context_config'] = context_config
          elsif attack_data.key?('context_config')
            # Remove context_config key if Nori parsed an empty element (creates nil value)
            attack_data.delete('context_config')
          end
          
          # Parse vm_context for this attack if specified
          vm_context = parse_vm_context(attack)
          if vm_context
            attack_data['vm_context'] = vm_context
          elsif attack_data.key?('vm_context')
            # Remove vm_context key if Nori parsed an empty element
            attack_data.delete('vm_context')
          end
          
          # Parse attack-level vm_context_enabled flag if specified
          vm_context_enabled_node = attack.at_xpath('vm_context_enabled')
          if vm_context_enabled_node
            attack_data['vm_context_enabled'] = vm_context_enabled_node.text.downcase == 'true'
          end
          
          @bots[bot_name]['attacks'].push attack_data
        end
        @bots[bot_name]['current_attack'] = 0

        @bots[bot_name]['current_quiz'] = nil

        Print.debug @bots[bot_name]['attacks'].to_s

        # Initialize per-user chat history storage
        @bots[bot_name]['user_chat_history'] = {}

        # Initialize LLM client for this bot based on provider
        # You can customize the model per bot by adding a model attribute to the XML
        provider = hackerbot.at_xpath('llm_provider')&.text || @llm_provider
        model_name = hackerbot.at_xpath('ollama_model')&.text || @ollama_model
        ollama_host_config = hackerbot.at_xpath('ollama_host')&.text || @ollama_host
        ollama_port_config = (hackerbot.at_xpath('ollama_port')&.text || @ollama_port.to_s).to_i
        openai_api_key_config = hackerbot.at_xpath('openai_api_key')&.text || @openai_api_key
        openai__base_url_config = hackerbot.at_xpath('openai_base_url')&.text || @openai_base_url
        vllm_host_config = hackerbot.at_xpath('vllm_host')&.text || @vllm_host
        vllm_port_config = (hackerbot.at_xpath('vllm_port')&.text || @vllm_port.to_s).to_i
        sglang_host_config = hackerbot.at_xpath('sglang_host')&.text || @sglang_host
        sglang_port_config = (hackerbot.at_xpath('sglang_port')&.text || @sglang_port.to_s).to_i

        system_prompt = hackerbot.at_xpath('system_prompt')&.text || DEFAULT_SYSTEM_PROMPT

        # Store global system prompt for fallback
        @bots[bot_name]['global_system_prompt'] = system_prompt

        max_tokens = (hackerbot.at_xpath('max_tokens')&.text || DEFAULT_MAX_TOKENS).to_i
        temperature = (hackerbot.at_xpath('model_temperature')&.text || DEFAULT_TEMPERATURE).to_f
        num_thread = (hackerbot.at_xpath('num_thread')&.text || DEFAULT_NUM_THREAD).to_i
        keepalive = (hackerbot.at_xpath('keepalive')&.text || DEFAULT_KEEPALIVE).to_i
        streaming_config = hackerbot.at_xpath('streaming')&.text
        streaming_enabled = streaming_config.nil? ? DEFAULT_STREAMING : (streaming_config.downcase == 'true')

        # Create the appropriate LLM client based on provider
        case provider.downcase
        when 'ollama'
          @bots[bot_name]['chat_ai'] = LLMClientFactory.create_client(
            'ollama',
            host: ollama_host_config,
            port: ollama_port_config,
            model: model_name,
            system_prompt: system_prompt,
            max_tokens: max_tokens,
            temperature: temperature,
            num_thread: num_thread,
            keepalive: keepalive,
            streaming: streaming_enabled
          )
        when 'openai'
          @bots[bot_name]['chat_ai'] = LLMClientFactory.create_client(
            'openai',
            api_key: openai_api_key_config,
            base_url: openai__base_url_config,
            model: model_name,
            system_prompt: system_prompt,
            max_tokens: max_tokens,
            temperature: temperature,
            streaming: streaming_enabled
          )
        when 'vllm'
          @bots[bot_name]['chat_ai'] = LLMClientFactory.create_client(
            'vllm',
            host: vllm_host_config,
            port: vllm_port_config,
            model: model_name,
            system_prompt: system_prompt,
            max_tokens: max_tokens,
            temperature: temperature,
            streaming: streaming_enabled
          )
        when 'sglang'
          @bots[bot_name]['chat_ai'] = LLMClientFactory.create_client(
            'sglang',
            host: sglang_host_config,
            port: sglang_port_config,
            model: model_name,
            system_prompt: system_prompt,
            max_tokens: max_tokens,
            temperature: temperature,
            streaming: streaming_enabled
          )
        else
          # Default to Ollama if provider is not recognized
          Print.err "Unknown LLM provider '#{provider}', defaulting to Ollama"
          @bots[bot_name]['chat_ai'] = LLMClientFactory.create_client(
            'ollama',
            host: ollama_host_config,
            port: ollama_port_config,
            model: model_name,
            system_prompt: system_prompt,
            max_tokens: max_tokens,
            temperature: temperature,
            num_thread: num_thread,
            keepalive: keepalive,
            streaming: streaming_enabled
          )
        end

        # Parse RAG + CAG configuration if enabled
        rag_cag_enabled = hackerbot.at_xpath('rag_cag_enabled')&.text
        @bots[bot_name]['rag_cag_enabled'] = rag_cag_enabled ? (rag_cag_enabled.downcase == 'true') : @enable_rag_cag

        if @bots[bot_name]['rag_cag_enabled']
          # Parse individual RAG and CAG enabling (allowing independent control)
          rag_enabled_node = hackerbot.at_xpath('rag_enabled')&.text
          cag_enabled_node = hackerbot.at_xpath('cag_enabled')&.text
          explicit_context_enabled_node = hackerbot.at_xpath('explicit_context_enabled')&.text

          # Use global settings as defaults, but allow per-bot override
          @bots[bot_name]['rag_enabled'] = if rag_enabled_node
            rag_enabled_node.downcase == 'true'
          else
            @rag_config[:enable_rag]  # Use global setting
          end

          @bots[bot_name]['cag_enabled'] = if cag_enabled_node
            cag_enabled_node.downcase == 'true'
          else
            @rag_config[:enable_cag]  # Use global setting
          end
          
          # Parse explicit context enabled (works independently of RAG)
          @bots[bot_name]['explicit_context_enabled'] = if explicit_context_enabled_node
            explicit_context_enabled_node.downcase == 'true'
          else
            nil  # Use global setting (auto-detect: true if RAG enabled, for backward compatibility)
          end

          # Parse RAG configuration
          rag_config_node = hackerbot.at_xpath('rag_cag_config/rag')
          if rag_config_node
            @bots[bot_name]['rag_cag_config'] ||= {}
            @bots[bot_name]['rag_cag_config']['max_rag_results'] = (rag_config_node.at_xpath('max_rag_results')&.text || '5').to_i
            @bots[bot_name]['rag_cag_config']['include_rag_context'] = !(rag_config_node.at_xpath('include_rag_context')&.text.downcase == 'false')
            @bots[bot_name]['rag_cag_config']['collection_name'] = rag_config_node.at_xpath('collection_name')&.text
          end

          # Parse CAG configuration
          cag_config_node = hackerbot.at_xpath('rag_cag_config/cag')
          if cag_config_node
            @bots[bot_name]['rag_cag_config'] ||= {}
            @bots[bot_name]['rag_cag_config']['max_cag_depth'] = (cag_config_node.at_xpath('max_cag_depth')&.text || '2').to_i
            @bots[bot_name]['rag_cag_config']['max_cag_nodes'] = (cag_config_node.at_xpath('max_cag_nodes')&.text || '10').to_i
            @bots[bot_name]['rag_cag_config']['include_cag_context'] = !(cag_config_node.at_xpath('include_cag_context')&.text.downcase == 'false')
          end

          # Parse entity extraction configuration
          entity_extraction_enabled = hackerbot.at_xpath('entity_extraction_enabled')&.text
          @bots[bot_name]['entity_extraction_enabled'] = entity_extraction_enabled ? (entity_extraction_enabled.downcase == 'true') : true

          # Parse entity types
          entity_types_node = hackerbot.at_xpath('entity_types')
          if entity_types_node
            entity_types = entity_types_node.text.split(',').map(&:strip).reject(&:empty?)
            @bots[bot_name]['entity_types'] = entity_types unless entity_types.empty?
          end

          # Parse knowledge sources configuration
          knowledge_sources_node = hackerbot.at_xpath('knowledge_sources')
          if knowledge_sources_node
            @bots[bot_name]['knowledge_sources'] = parse_knowledge_sources(knowledge_sources_node)
            # Update global RAG/CAG config with bot-specific knowledge sources
            @rag_config[:knowledge_sources_config] = @bots[bot_name]['knowledge_sources']
          end
        else
          # If rag_cag_enabled is false, check if explicit_context_enabled is set independently
          explicit_context_enabled_node = hackerbot.at_xpath('explicit_context_enabled')&.text
          if explicit_context_enabled_node
            @bots[bot_name]['explicit_context_enabled'] = explicit_context_enabled_node.downcase == 'true'
          end
        end
        
        # Parse explicit context enabled independently (can work without RAG/CAG)
        # This allows explicit context to be enabled even when RAG is disabled
        if @bots[bot_name]['explicit_context_enabled'].nil?
          explicit_context_enabled_node = hackerbot.at_xpath('explicit_context_enabled')&.text
          @bots[bot_name]['explicit_context_enabled'] = if explicit_context_enabled_node
            explicit_context_enabled_node.downcase == 'true'
          else
            nil  # Use global setting (auto-detect based on RAG for backward compatibility)
          end
        end

        # Parse bot-level vm_context_enabled flag
        vm_context_enabled_node = hackerbot.at_xpath('vm_context_enabled')
        if vm_context_enabled_node
          @bots[bot_name]['vm_context_enabled'] = vm_context_enabled_node.text.downcase == 'true'
        end

        # Parse history window size configuration
        max_history_length_node = hackerbot.at_xpath('max_history_length')
        if max_history_length_node
          @bots[bot_name]['max_history_length'] = max_history_length_node.text.to_i
        else
          @bots[bot_name]['max_history_length'] = @max_history_length
        end

        # Parse IRC message history window size configuration
        max_irc_message_history_node = hackerbot.at_xpath('max_irc_message_history')
        if max_irc_message_history_node
          @bots[bot_name]['max_irc_message_history'] = max_irc_message_history_node.text.to_i
        else
          @bots[bot_name]['max_irc_message_history'] = @max_irc_message_history
        end

        # Parse message type filtering configuration
        # Default: include all message types except system messages
        default_message_types = [:user_message, :bot_llm_response, :bot_command_response]
        message_types_node = hackerbot.at_xpath('message_type_filter')
        if message_types_node
          # Parse <type> elements
          type_nodes = message_types_node.xpath('type')
          if type_nodes.any?
            parsed_types = type_nodes.map { |node| node.text.strip.to_sym }
            # Validate that all types are valid message types
            valid_types = [:user_message, :bot_llm_response, :bot_command_response, :system_message]
            invalid_types = parsed_types.reject { |t| valid_types.include?(t) }
            if invalid_types.any?
              Print.err "Warning: Invalid message types for bot #{bot_name}: #{invalid_types.join(', ')}. Ignoring invalid types."
              parsed_types = parsed_types.select { |t| valid_types.include?(t) }
            end
            @bots[bot_name]['message_type_filter'] = parsed_types.empty? ? default_message_types : parsed_types
          else
            # No types specified, use default
            @bots[bot_name]['message_type_filter'] = default_message_types
          end
        else
          # No configuration, use default
          @bots[bot_name]['message_type_filter'] = default_message_types
        end

        # Test connection to LLM provider
        unless @bots[bot_name]['chat_ai'].test_connection
          Print.err "Warning: Cannot connect to #{provider} for bot #{bot_name}. Chat responses may not work."
        end

        create_bot(bot_name, system_prompt)
      end
    end

    @bots
  end

  def parse_knowledge_sources(knowledge_sources_node)
    sources = []

    knowledge_sources_node.xpath('source').each do |source_node|
      source_type = source_node.at_xpath('type')&.text
      source_name = source_node.at_xpath('name')&.text
      enabled = source_node.at_xpath('enabled')&.text
      description = source_node.at_xpath('description')&.text
      priority = source_node.at_xpath('priority')&.text

      next unless source_type

      source_config = {
        type: source_type,
        name: source_name || source_type,
        enabled: enabled ? (enabled.downcase == 'true') : true,
        description: description || '',
        priority: priority ? priority.to_i : 0
      }

      # Parse type-specific configuration
      case source_type.downcase
      when 'man_pages', 'manpage', 'man'
        source_config[:man_pages] = parse_man_pages_config(source_node)
      when 'markdown_files', 'markdown', 'md'
        source_config[:markdown_files] = parse_markdown_files_config(source_node)
      end

      sources << source_config
    end

    sources
  end

  def parse_man_pages_config(source_node)
    man_pages = []

    source_node.xpath('man_pages/man_page').each do |man_page_node|
      name = man_page_node.at_xpath('name')&.text
      section = man_page_node.at_xpath('section')&.text
      collection_name = man_page_node.at_xpath('collection_name')&.text

      next unless name

      man_page_config = {
        name: name,
        collection_name: collection_name || 'default_man_pages'
      }

      if section
        man_page_config[:section] = section.to_i
      end

      man_pages << man_page_config
    end

    man_pages
  end

  def parse_markdown_files_config(source_node)
    markdown_files = []

    source_node.xpath('markdown_files/markdown_file').each do |markdown_file_node|
      path = markdown_file_node.at_xpath('path')&.text
      collection_name = markdown_file_node.at_xpath('collection_name')&.text
      tags_node = markdown_file_node.at_xpath('tags')

      next unless path

      markdown_file_config = {
        path: path,
        collection_name: collection_name || 'default_markdown_files'
      }

      # Parse tags if present
      if tags_node
        tags = []
        tags_node.xpath('tag').each do |tag_node|
          tag_text = tag_node.text
          tags << tag_text if tag_text && !tag_text.empty?
        end
        markdown_file_config[:tags] = tags unless tags.empty?
      end

      markdown_files << markdown_file_config
    end

    # Also check for directory-based configuration
    directory_node = source_node.at_xpath('markdown_files/directory')
    if directory_node
      dir_path = directory_node.at_xpath('path')&.text
      dir_pattern = directory_node.at_xpath('pattern')&.text
      dir_collection = directory_node.at_xpath('collection_name')&.text

      if dir_path
        dir_config = {
          path: dir_path,
          collection_name: dir_collection || "markdown_#{File.basename(dir_path).gsub(/[^W-]/, '_')}",
          pattern: dir_pattern || '*.md',
          is_directory: true
        }
        markdown_files << dir_config
      end
    end

    markdown_files
  end

  # Parse context_config element from attack XML
  # Supports both comma-separated and individual element formats
  # Includes validation with warnings (non-blocking)
  def parse_context_config(attack_node)
    context_config = {}
    
    # Check if context_config element exists
    context_config_node = attack_node.at_xpath('context_config')
    return nil unless context_config_node
    
    # Check if it's an empty or self-closing element (no children and no meaningful text)
    # If it has no child elements and no text content (or only whitespace), treat as missing
    has_element_children = context_config_node.children.any? { |c| c.element? }
    
    # Also check if any of the expected sub-elements exist (man_pages, documents, mitre_techniques)
    has_any_sub_elements = context_config_node.at_xpath('man_pages') || 
                          context_config_node.at_xpath('documents') || 
                          context_config_node.at_xpath('mitre_techniques')
    
    return nil unless has_element_children || has_any_sub_elements
    
    # Parse man_pages element
    man_pages_node = context_config_node.at_xpath('man_pages')
    if man_pages_node
      # Check if it contains individual <page> elements
      page_elements = man_pages_node.xpath('page')
      if page_elements.any?
        # Individual <page> elements format
        man_pages = page_elements.map { |e| e.text.strip }.reject(&:empty?)
      else
        # Comma-separated format
        text_content = man_pages_node.text.strip
        man_pages = text_content.split(',').map(&:strip).reject(&:empty?)
      end
      
      # Validate and deduplicate
      original_count = man_pages.length
      man_pages = man_pages.uniq
      if original_count > man_pages.length
        Print.debug "Warning: Duplicate man page entries detected and removed"
      end
      
      context_config[:man_pages] = man_pages unless man_pages.empty?
    end
    
    # Parse documents element
    documents_node = context_config_node.at_xpath('documents')
    if documents_node
      # Check if it contains individual <doc> elements
      doc_elements = documents_node.xpath('doc')
      if doc_elements.any?
        # Individual <doc> elements format
        documents = doc_elements.map { |e| e.text.strip }.reject(&:empty?)
      else
        # Comma-separated format
        text_content = documents_node.text.strip
        documents = text_content.split(',').map(&:strip).reject(&:empty?)
      end
      
      # Validate document paths (warn on suspicious paths but don't fail)
      documents.each do |doc_path|
        if doc_path.start_with?('/') && !doc_path.start_with?('/home', '/usr', '/opt')
          Print.debug "Warning: Document path '#{doc_path}' starts with root directory"
        elsif doc_path.include?('..')
          Print.debug "Warning: Document path '#{doc_path}' contains parent directory reference"
        end
      end
      
      # Deduplicate
      original_count = documents.length
      documents = documents.uniq
      if original_count > documents.length
        Print.debug "Warning: Duplicate document entries detected and removed"
      end
      
      context_config[:documents] = documents unless documents.empty?
    end
    
    # Parse mitre_techniques element
    mitre_techniques_node = context_config_node.at_xpath('mitre_techniques')
    if mitre_techniques_node
      # Check if it contains individual <technique> elements
      technique_elements = mitre_techniques_node.xpath('technique')
      if technique_elements.any?
        # Individual <technique> elements format
        mitre_techniques = technique_elements.map { |e| e.text.strip }.reject(&:empty?)
      else
        # Comma-separated format
        text_content = mitre_techniques_node.text.strip
        mitre_techniques = text_content.split(',').map(&:strip).reject(&:empty?)
      end
      
      # Validate MITRE technique IDs (format: T#### or T####.###)
      mitre_techniques.each do |technique_id|
        unless technique_id.match?(/\AT\d{4}(\.\d{3})?\z/)
          Print.debug "Warning: Invalid MITRE technique ID format: '#{technique_id}' (expected T#### or T####.###)"
        end
      end
      
      # Deduplicate
      original_count = mitre_techniques.length
      mitre_techniques = mitre_techniques.uniq
      if original_count > mitre_techniques.length
        Print.debug "Warning: Duplicate MITRE technique entries detected and removed"
      end
      
      context_config[:mitre_techniques] = mitre_techniques unless mitre_techniques.empty?
    end
    
    # Parse combine_mode element (optional)
    combine_mode_node = context_config_node.at_xpath('combine_mode')
    if combine_mode_node
      combine_mode = combine_mode_node.text.strip.downcase
      valid_modes = ['explicit_only', 'explicit_first', 'combined', 'similarity_fallback']
      if valid_modes.include?(combine_mode)
        context_config[:combine_mode] = combine_mode
      else
        Print.warn "Invalid combine_mode '#{combine_mode}' in context_config (valid: #{valid_modes.join(', ')}). Using default 'explicit_first'."
      end
    end
    
    # Return nil if context_config is empty (all sub-elements were empty or missing)
    context_config.empty? ? nil : context_config
  end

  # Parse vm_context element from attack XML
  # Supports bash_history, commands, and files configuration
  def parse_vm_context(attack_node)
    vm_context = {}
    
    # Check if vm_context element exists
    vm_context_node = attack_node.at_xpath('vm_context')
    return nil unless vm_context_node
    
    # Check if it's an empty or self-closing element
    has_element_children = vm_context_node.children.any? { |c| c.element? }
    has_any_sub_elements = vm_context_node.at_xpath('bash_history') || 
                          vm_context_node.at_xpath('commands') || 
                          vm_context_node.at_xpath('files')
    
    return nil unless has_element_children || has_any_sub_elements
    
    # Parse bash_history element with attributes
    bash_history_node = vm_context_node.at_xpath('bash_history')
    if bash_history_node
      bash_history = {}
      path = bash_history_node['path'] || '~/.bash_history'
      bash_history[:path] = path unless path.empty?
      
      # Parse limit attribute (convert to integer if present)
      if bash_history_node['limit'] && !bash_history_node['limit'].empty?
        limit_value = bash_history_node['limit'].to_i
        bash_history[:limit] = limit_value if limit_value > 0
      end
      
      # Parse user attribute
      if bash_history_node['user'] && !bash_history_node['user'].empty?
        bash_history[:user] = bash_history_node['user']
      end
      
      # Only add bash_history if it has at least a path
      vm_context[:bash_history] = bash_history unless bash_history.empty?
    end
    
    # Parse commands element
    commands_node = vm_context_node.at_xpath('commands')
    if commands_node
      commands = []
      commands_node.xpath('command').each do |cmd_node|
        cmd_text = cmd_node.text.to_s.strip
        commands << cmd_text unless cmd_text.empty?
      end
      vm_context[:commands] = commands unless commands.empty?
    end
    
    # Parse files element
    files_node = vm_context_node.at_xpath('files')
    if files_node
      files = []
      files_node.xpath('file').each do |file_node|
        path = file_node['path']
        files << path if path && !path.to_s.strip.empty?
      end
      vm_context[:files] = files unless files.empty?
    end
    
    # Return nil if vm_context is empty (all sub-elements were empty or missing)
    vm_context.empty? ? nil : vm_context
  end

  # Fetch VM context from student machine via SSH
  #
  # @param bot_name [String] Bot name
  # @param attack_index [Integer] Current attack index
  # @param variables [Hash] Optional variables for SSH command substitution (e.g., { chat_ip_address: '192.168.1.1' })
  # @return [String, nil] Formatted VM context string or nil if no config/error
  def fetch_vm_context(bot_name, attack_index, variables = {})
    return nil unless @bots[bot_name] && @bots[bot_name]['attacks']
    return nil unless attack_index >= 0 && attack_index < @bots[bot_name]['attacks'].length
    
    # Get VM context config from attack
    vm_context_config = @bots[bot_name]['attacks'][attack_index]['vm_context']
    return nil unless vm_context_config
    
    # Get SSH config (per-attack or fallback to global)
    ssh_config = nil
    if @bots[bot_name]['attacks'][attack_index].key?('get_shell')
      ssh_config = { 'get_shell' => @bots[bot_name]['attacks'][attack_index]['get_shell'] }
    elsif @bots[bot_name].key?('get_shell')
      ssh_config = { 'get_shell' => @bots[bot_name]['get_shell'] }
    else
      Print.warn("No SSH config found for bot '#{bot_name}' attack #{attack_index}")
      return nil
    end
    
    # Initialize VM context manager
    vm_manager = VMContextManager.new
    
    # Initialize VM context data structure
    vm_context_data = {
      bash_history: nil,
      commands: [],
      files: []
    }
    
    # Fetch bash history if configured
    if vm_context_config[:bash_history]
      begin
        bash_history_config = vm_context_config[:bash_history]
        path = bash_history_config[:path] || '~/.bash_history'
        limit = bash_history_config[:limit]
        user = bash_history_config[:user]
        
        history_content = vm_manager.read_bash_history(ssh_config, user, limit, variables)
        
        if history_content && !history_content.strip.empty?
          vm_context_data[:bash_history] = {
            content: history_content,
            path: path,
            limit: limit,
            user: user
          }
        end
      rescue => e
        Print.warn("Failed to fetch bash history for bot '#{bot_name}' attack #{attack_index}: #{e.message}")
      end
    end
    
    # Execute commands if configured
    if vm_context_config[:commands] && vm_context_config[:commands].is_a?(Array)
      vm_context_config[:commands].each do |command|
        next if command.nil? || command.strip.empty?
        
        begin
          output = vm_manager.execute_command(ssh_config, command, variables)
          
          if output && !output.strip.empty?
            vm_context_data[:commands] << {
              command: command,
              output: output
            }
          end
        rescue => e
          Print.warn("Failed to execute command '#{command}' for bot '#{bot_name}' attack #{attack_index}: #{e.message}")
          # Continue with other commands
        end
      end
    end
    
    # Read files if configured
    if vm_context_config[:files] && vm_context_config[:files].is_a?(Array)
      vm_context_config[:files].each do |file_path|
        next if file_path.nil? || file_path.strip.empty?
        
        begin
          content = vm_manager.read_file(ssh_config, file_path, variables)
          
          if content && !content.strip.empty?
            vm_context_data[:files] << {
              path: file_path,
              content: content
            }
          end
        rescue => e
          Print.warn("Failed to read file '#{file_path}' for bot '#{bot_name}' attack #{attack_index}: #{e.message}")
          # Continue with other files
        end
      end
    end
    
    # Assemble and return formatted VM context
    assemble_vm_context(vm_context_data)
  rescue => e
    Print.warn("Failed to fetch VM context for bot '#{bot_name}' attack #{attack_index}: #{e.message}")
    nil
  end
  
  # Assemble VM context data into formatted string for LLM consumption
  #
  # @param vm_context_data [Hash] VM context data structure with bash_history, commands, and files
  # @return [String, nil] Formatted VM context string or nil if no data
  def assemble_vm_context(vm_context_data)
    return nil unless vm_context_data
    
    sections = []
    
    # Add bash history section
    if vm_context_data[:bash_history] && vm_context_data[:bash_history][:content]
      bh = vm_context_data[:bash_history]
      limit_str = bh[:limit] ? "last #{bh[:limit]} commands from " : ""
      user_str = bh[:user] ? "user #{bh[:user]} " : ""
      sections << "Bash History (#{limit_str}#{user_str}#{bh[:path]}):"
      sections << bh[:content]
    end
    
    # Add command outputs section
    if vm_context_data[:commands] && !vm_context_data[:commands].empty?
      sections << "Command Outputs:"
      vm_context_data[:commands].each do |cmd_data|
        sections << "[Command: #{cmd_data[:command]}]"
        sections << cmd_data[:output]
        sections << ""  # Empty line between commands
      end
    end
    
    # Add files section
    if vm_context_data[:files] && !vm_context_data[:files].empty?
      sections << "Files:"
      vm_context_data[:files].each do |file_data|
        sections << "[File: #{file_data[:path]}]"
        sections << file_data[:content]
        sections << ""  # Empty line between files
      end
    end
    
    return nil if sections.empty?
    
    # Combine into formatted string with VM State header
    "VM State:\n#{sections.join("\n")}"
  end

  def assemble_prompt(system_prompt, context, chat_context, user_message, enhanced_context = nil)
    sections = [system_prompt]
    
    # Add context (attack prompt)
    sections << "Context: #{context}" unless context.empty?
    
    # Add VM context if present
    vm_context = nil
    if enhanced_context && enhanced_context[:vm_context] && !enhanced_context[:vm_context].strip.empty?
      vm_context = enhanced_context[:vm_context]
      sections << vm_context
    end
    
    # Add RAG + CAG enhanced context if present
    if enhanced_context && enhanced_context[:combined_context] && !enhanced_context[:combined_context].strip.empty?
      sections << "Enhanced Context:\n#{enhanced_context[:combined_context]}"
    end
    
    # Add chat history
    sections << "Chat History:\n#{chat_context}" unless chat_context.empty?
    
    # Add user message and assistant prompt
    sections << "User: #{user_message}"
    sections << "Assistant:"
    
    # Build prompt string
    prompt = sections.join("\n\n")
    
    # Apply context length management
    max_length = get_max_context_length
    if max_length && prompt.length > max_length
      # Calculate space needed for non-truncatable sections
      fixed_sections_length = [
        system_prompt,
        context.empty? ? '' : "Context: #{context}",
        "User: #{user_message}",
        "Assistant:"
      ].select { |s| !s.empty? }.join("\n\n").length
      
      # Estimate space for section headers
      header_space = 100
      
      # Available space for VM context, enhanced context, and chat history
      available_space = max_length - fixed_sections_length - header_space
      
      if available_space > 0
        # Truncate VM context if present and needed
        truncated_vm = nil
        if vm_context && vm_context.length > (available_space / 3)
          # Prioritize recent bash history and recent command outputs
          truncated_vm = truncate_vm_context(vm_context, available_space / 3)
        end
        
        # Rebuild prompt with potentially truncated VM context
        if truncated_vm && truncated_vm != vm_context
          sections = [system_prompt]
          sections << "Context: #{context}" unless context.empty?
          sections << truncated_vm if truncated_vm
          if enhanced_context && enhanced_context[:combined_context] && !enhanced_context[:combined_context].strip.empty?
            sections << "Enhanced Context:\n#{enhanced_context[:combined_context]}"
          end
          sections << "Chat History:\n#{chat_context}" unless chat_context.empty?
          sections << "User: #{user_message}"
          sections << "Assistant:"
          prompt = sections.join("\n\n")
        end
        
        # Final truncation if still too long (truncate from beginning of context sections)
        if prompt.length > max_length
          Print.warn "Prompt exceeds max_context_length (#{max_length} chars, actual: #{prompt.length}). Truncating."
          excess = prompt.length - max_length
          # Truncate from the middle sections (VM context, enhanced context, chat history)
          prompt = prompt[0..(system_prompt.length + 50)] + "\n\n" +
                   prompt[(system_prompt.length + 50 + excess)..-1]
        end
      else
        Print.warn "Max context length too small (#{max_length} chars). Prompt may be truncated."
      end
    end
    
    prompt
  end

  # Truncate VM context string while preserving important information
  #
  # @param vm_context [String] VM context string to truncate
  # @param max_length [Integer] Maximum length for truncated context
  # @return [String] Truncated VM context string
  def truncate_vm_context(vm_context, max_length)
    return vm_context if vm_context.length <= max_length
    
    # Split into sections
    lines = vm_context.split("\n")
    header = lines.first  # "VM State:"
    remaining_lines = lines[1..-1]
    
    # Prioritize: recent bash history > recent commands > files
    # Keep header and try to preserve as much as possible
    truncated = [header]
    current_length = header.length
    
    # Add lines until we reach max length
    remaining_lines.each do |line|
      line_with_newline = line + "\n"
      if current_length + line_with_newline.length <= max_length - 50  # Reserve space for truncation message
        truncated << line
        current_length += line_with_newline.length
      else
        break
      end
    end
    
    # Add truncation message if we truncated
    if truncated.length < lines.length
      truncated << "\n... (VM context truncated due to length limits)"
    end
    
    truncated.join("\n")
  end

  def parse_personalities(bot_name, personalities_node)
    personalities_node.xpath('personality').each do |personality_node|
      personality_name = personality_node.at_xpath('name')&.text
      next unless personality_name

      personality_config = {
        'name' => personality_name,
        'title' => personality_node.at_xpath('title')&.text || personality_name,
        'description' => personality_node.at_xpath('description')&.text || '',
        'system_prompt' => personality_node.at_xpath('system_prompt')&.text || @bots[bot_name]['global_system_prompt'],
        'messages' => {}
      }

      # Parse personality-specific messages
      %w[greeting help next previous goto ready say_ready correct_answer incorrect_answer no_quiz last_attack first_attack invalid getting_shell got_shell shell_fail_message repeat non_answer].each do |message_type|
        message_node = personality_node.at_xpath(message_type)
        if message_node
          personality_config['messages'][message_type] = message_node.text
        end
      end

      @bots[bot_name]['personalities'][personality_name] = personality_config
      Print.debug "Loaded personality: #{personality_name}"
    end
  end

  # Personality management methods
  def initialize_personalities(bot_name)
    @bots[bot_name]['personalities'] = {}
    @bots[bot_name]['current_personalities'] = {} # Track current personality per user
    @bots[bot_name]['default_personality'] = nil
  end

  def get_current_personality(bot_name, user_id)
    return @bots[bot_name]['default_personality'] unless @bots[bot_name]['current_personalities'].key?(user_id)
    @bots[bot_name]['current_personalities'][user_id]
  end

  def set_current_personality(bot_name, user_id, personality_name)
    if @bots[bot_name]['personalities'].key?(personality_name)
      @bots[bot_name]['current_personalities'][user_id] = personality_name
      true
    else
      false
    end
  end

  def get_personality_config(bot_name, personality_name)
    @bots[bot_name]['personalities'][personality_name]
  end

  def list_personalities(bot_name)
    @bots[bot_name]['personalities'].keys
  end

  def get_personality_system_prompt(bot_name, user_id)
    current_personality = get_current_personality(bot_name, user_id)
    if current_personality && @bots[bot_name]['personalities'].key?(current_personality)
      @bots[bot_name]['personalities'][current_personality]['system_prompt']
    else
      # Fallback to global system prompt
      @bots[bot_name]['global_system_prompt']
    end
  end

  def get_personality_messages(bot_name, user_id, message_type)
    current_personality = get_current_personality(bot_name, user_id)
    if current_personality &&
       @bots[bot_name]['personalities'].key?(current_personality) &&
       @bots[bot_name]['personalities'][current_personality]['messages'] &&
       @bots[bot_name]['personalities'][current_personality]['messages'][message_type]
      @bots[bot_name]['personalities'][current_personality]['messages'][message_type]
    else
      # Fallback to global messages
      @bots[bot_name]['messages'][message_type]
    end
  end

  def create_bot(bot_name, system_prompt)
    bots_ref = @bots
    irc_server_ip_address = @irc_server_ip_address
    user_chat_histories = @user_chat_histories
    max_history_length = @max_history_length
    get_chat_context = method(:get_chat_context)
    add_to_history = method(:add_to_history)
    clear_user_history = method(:clear_user_history)
    assemble_prompt = method(:assemble_prompt)
    get_enhanced_context = method(:get_enhanced_context)
    get_personality_system_prompt = method(:get_personality_system_prompt)
    get_personality_messages = method(:get_personality_messages)
    get_current_personality = method(:get_current_personality)
    set_current_personality = method(:set_current_personality)
    list_personalities = method(:list_personalities)
    get_personality_config = method(:get_personality_config)
    capture_irc_message = method(:capture_irc_message)

    @bots[bot_name]['bot'] = Cinch::Bot.new do
      configure do |c|
        c.nick = bot_name
        c.server = irc_server_ip_address
        # joins a channel named after the bot, and #bots
        c.channels = ["##{bot_name}", '#bots']
      end

      # Global message handler to capture all IRC channel messages
      # This runs for all messages to capture them with metadata
      on :message do |m|
        # Skip capturing if message is from the bot itself (to avoid duplicates)
        next if m.user.nick.downcase == bot_name.downcase
        
        # Determine channel
        channel = m.channel ? m.channel.name : "##{bot_name}"
        
        # Capture user message
        capture_irc_message.call(bot_name, m.user.nick, m.message, channel, nil, false)
      end

      on :message, /hello/i do |m|
        m.reply "Hello, #{m.user.nick} (#{m.user.host})."
        m.reply get_personality_messages.call(bot_name, m.user.nick, 'greeting')
        current = bots_ref[bot_name]['current_attack']

        # prompt for the first attack
        if bots_ref[bot_name]['messages'].key?('show_attack_numbers')
          m.reply "** ##{current + 1} **"
        end
        m.reply bots_ref[bot_name]['attacks'][current]['prompt']
        m.reply get_personality_messages.call(bot_name, m.user.nick, 'say_ready')
      end

      on :message, /help/i do |m|
        m.reply get_personality_messages.call(bot_name, m.user.nick, 'help')
      end

      # Personality management commands
      on :message, /^personalities$/i do |m|
        available_personalities = list_personalities.call(bot_name)
        if available_personalities.empty?
          m.reply "No personalities available for this bot."
        else
          current_personality = get_current_personality.call(bot_name, m.user.nick)
          personality_list = available_personalities.map do |name|
            config = get_personality_config.call(bot_name, name)
            status = (name == current_personality) ? "[CURRENT]" : ""
            "#{name} (#{config['title']}) #{status}"
          end.join("\n")
          m.reply "Available personalities:\n#{personality_list}"
        end
      end

      on :message, /^personality$/i do |m|
        current_personality = get_current_personality.call(bot_name, m.user.nick)
        if current_personality
          config = get_personality_config.call(bot_name, current_personality)
          m.reply "Current personality: #{current_personality} (#{config['title']}) - #{config['description']}"
        else
          m.reply "No personality selected. Use 'personalities' to see available options."
        end
      end

      on :message, /^(switch|personality) .+$/i do |m|
        target_personality = m.message.chomp.split(' ', 2)[1]
        if set_current_personality.call(bot_name, m.user.nick, target_personality)
          config = get_personality_config.call(bot_name, target_personality)
          m.reply "Switched to #{target_personality} personality (#{config['title']})"
        else
          available = list_personalities.call(bot_name)
          m.reply "Unknown personality '#{target_personality}'. Available personalities: #{available.join(', ')}"
        end
      end

      on :message, 'next' do |m|
        m.reply get_personality_messages.call(bot_name, m.user.nick, 'next')

        # is this the last one?
        if bots_ref[bot_name]['current_attack'] < bots_ref[bot_name]['attacks'].length - 1
          bots_ref[bot_name]['current_attack'] += 1
          current = bots_ref[bot_name]['current_attack']
          update_bot_state(bot_name, bots_ref, current)

          # prompt for current hack
          if bots_ref[bot_name]['messages'].key?('show_attack_numbers')
            m.reply "** ##{current + 1} **"
          end
          m.reply bots_ref[bot_name]['attacks'][current]['prompt']
          m.reply get_personality_messages.call(bot_name, m.user.nick, 'say_ready')
        else
          m.reply get_personality_messages.call(bot_name, m.user.nick, 'last_attack')
        end
      end

      on :message, /^(goto|attack) [0-9]+$/i do |m|
        m.reply get_personality_messages.call(bot_name, m.user.nick, 'goto')
        requested_index = m.message.chomp().split[1].to_i - 1

        Print.debug "requested_index = #{requested_index}, bots_ref[bot_name]['attacks'].length = #{bots_ref[bot_name]['attacks'].length}"

        # is this a valid attack number?
        if requested_index < bots_ref[bot_name]['attacks'].length
          update_bot_state(bot_name, bots_ref, requested_index)
          current = bots_ref[bot_name]['current_attack']

          # prompt for current hack
          if bots_ref[bot_name]['messages'].key?('show_attack_numbers')
            m.reply "** ##{current + 1} **"
          end
          m.reply bots_ref[bot_name]['attacks'][current]['prompt']
          m.reply get_personality_messages.call(bot_name, m.user.nick, 'say_ready')
        else
          m.reply get_personality_messages.call(bot_name, m.user.nick, 'invalid')
        end
      end

      on :message, /^(the answer is|answer):? .+$/i do |m|
        answer = m.message.chomp().match(/(?:the )?answer(?: is)?:? (.+)$/i)[1]
        current = bots_ref[bot_name]['current_attack']

        quiz = nil
        if bots_ref[bot_name]['attacks'][current].key?('quiz') && bots_ref[bot_name]['attacks'][current]['quiz'].key?('answer')
          quiz = bots_ref[bot_name]['attacks'][current]['quiz']
        end

        if quiz != nil
          correct_answer = quiz['answer'].clone
          if bots_ref[bot_name]['attacks'][current].key?('post_command_output')
            post_outputs = bots_ref[bot_name]['attacks'][current]['post_command_outputs'].map(&:strip).join('|')
            correct_answer.gsub!(/{{post_command_output}}/, post_outputs)
          end
          if bots_ref[bot_name]['attacks'][current].key?('get_shell_command_output')
            shell_outputs = bots_ref[bot_name]['attacks'][current]['shell_command_outputs'].map { |output| output.lines.first.to_s.strip }.join('|')
            correct_answer.gsub!(/{{shell_command_output_first_line}}/, shell_outputs)
          end
          if bots_ref[bot_name]['attacks'][current].key?('pre_shell')
            pre_shell_outputs = bots_ref[bot_name]['attacks'][current]['pre_shell_command_outputs'] || []
            pre_shell_output = pre_shell_outputs.map { |output| output.lines.first.to_s.strip }.join('|')
            correct_answer.gsub!(/{{pre_shell_command_output_first_line}}/, pre_shell_output)
          end
          correct_answer.chomp!
          Print.debug "#{correct_answer}====#{answer}"

          if answer.strip.match?(/^(?:#{correct_answer})$/i)
            m.reply get_personality_messages.call(bot_name, m.user.nick, 'correct_answer')
            m.reply quiz['correct_answer_response']

            if quiz.key?('trigger_next_attack')
              if bots_ref[bot_name]['current_attack'] < bots_ref[bot_name]['attacks'].length - 1
                bots_ref[bot_name]['current_attack'] += 1
                current = bots_ref[bot_name]['current_attack']
                update_bot_state(bot_name, bots_ref, current)

                sleep(1)
                if bots_ref[bot_name]['messages'].key?('show_attack_numbers')
                  m.reply "** ##{current + 1} **"
                end
                m.reply bots_ref[bot_name]['attacks'][current]['prompt']
                m.reply get_personality_messages.call(bot_name, m.user.nick, 'say_ready')
              else
                m.reply get_personality_messages.call(bot_name, m.user.nick, 'last_attack')
              end
            end
          else
            m.reply "#{get_personality_messages.call(bot_name, m.user.nick, 'incorrect_answer')} (#{answer})"
          end
        else
          m.reply get_personality_messages.call(bot_name, m.user.nick, 'no_quiz')
        end
      end

      on :message, 'previous' do |m|
        m.reply get_personality_messages.call(bot_name, m.user.nick, 'previous')

        # is this the last one?
        if bots_ref[bot_name]['current_attack'] > 0
          bots_ref[bot_name]['current_attack'] -= 1
          current = bots_ref[bot_name]['current_attack']
          update_bot_state(bot_name, bots_ref, current)

          # prompt for current hack
          if bots_ref[bot_name]['messages'].key?('show_attack_numbers')
            m.reply "** ##{current + 1} **"
          end
          m.reply bots_ref[bot_name]['attacks'][current]['prompt']
          m.reply get_personality_messages.call(bot_name, m.user.nick, 'say_ready')
        else
          m.reply get_personality_messages.call(bot_name, m.user.nick, 'first_attack')
        end
      end

      on :message, 'list' do |m|
        bots_ref[bot_name]['attacks'].each_with_index {|val, index|
          uptohere = ''
          if index == bots_ref[bot_name]['current_attack']
            uptohere = '--> '
          end

          m.reply "#{uptohere}#{index+1}: #{val['prompt']}"
        }
      end

      on :message, 'clear_history' do |m|
        user_id = m.user.nick
        clear_user_history.call(bot_name, user_id)
        m.reply "Chat history cleared for #{user_id}."
      end

      on :message, 'show_history' do |m|
        user_id = m.user.nick
        chat_context = get_chat_context.call(bot_name, user_id)
        if chat_context.empty?
          m.reply "No chat history found for #{user_id}."
        else
          m.reply "Chat history for #{user_id}:"
          m.reply chat_context
        end
      end

      # fallback to Ollama LLM responses
      on :message do |m|
        # Only process messages not related to controlling attacks or personality management
        if m.message !~ /hello|help|next|previous|ready|list|clear_history|show_history|^(goto|attack) [0-9]|(the answer is|answer)|personalities|^(switch|personality) .+$/
          begin
            user_id = m.user.nick
            current_attack = bots_ref[bot_name]['current_attack']
            attack_context = ''
            # Get personality-specific system prompt
            current_system_prompt = get_personality_system_prompt.call(bot_name, user_id)

            if current_attack < bots_ref[bot_name]['attacks'].length
              attack_context = "Current topic (#{current_attack + 1}): #{bots_ref[bot_name]['attacks'][current_attack]['prompt']}"
              # Use attack-specific system prompt if available, otherwise use personality prompt
              if bots_ref[bot_name]['attacks'][current_attack].key?('system_prompt')
                current_system_prompt = bots_ref[bot_name]['attacks'][current_attack]['system_prompt']
              end
              # Update the OllamaClient's system prompt
              bots_ref[bot_name]['chat_ai'].update_system_prompt(current_system_prompt)
            end
            chat_context = get_chat_context.call(bot_name, user_id, exclude_message: m.message)

            # Get RAG + CAG enhanced context if enabled (VM context is now included in get_enhanced_context)
            enhanced_context = nil
            if bots_ref[bot_name]['rag_cag_enabled'] != false
              variables = { chat_ip_address: m.user.host.to_s }
              enhanced_context = get_enhanced_context.call(bot_name, m.message, attack_index: current_attack, variables: variables)
            end

            prompt = assemble_prompt.call(current_system_prompt, attack_context, chat_context, m.message, enhanced_context)
            if bots_ref[bot_name]['chat_ai'].instance_variable_get(:@streaming)
              accumulated_text = ''
              stream_callback = Proc.new do |chunk|
                accumulated_text << chunk
                if accumulated_text.include?("\n")
                  lines = accumulated_text.split("\n", -1)
                  lines[0...-1].each do |complete_line|
                    if !complete_line.strip.empty?
                      m.reply complete_line.strip
                    end
                  end
                  accumulated_text = lines.last
                end
              end
              reaction = bots_ref[bot_name]['chat_ai'].generate_response(prompt, stream_callback)
              if !accumulated_text.strip.empty?
                m.reply accumulated_text.strip
              end
              if reaction && !reaction.empty?
                add_to_history.call(bot_name, user_id, m.message, reaction)
                # Capture bot LLM response
                channel = m.channel ? m.channel.name : "##{bot_name}"
                capture_irc_message.call(bot_name, bot_name, reaction, channel, :bot_llm_response, true)
              elsif m.message.include?('?')
                non_answer_msg = bots_ref[bot_name]['messages']['non_answer']
                m.reply non_answer_msg
                # Capture bot command response
                channel = m.channel ? m.channel.name : "##{bot_name}"
                capture_irc_message.call(bot_name, bot_name, non_answer_msg, channel, :bot_command_response, true)
              end
            else
              reaction = bots_ref[bot_name]['chat_ai'].generate_response(prompt)
              if reaction && !reaction.empty?
                m.reply reaction
                add_to_history.call(bot_name, user_id, m.message, reaction)
                # Capture bot LLM response
                channel = m.channel ? m.channel.name : "##{bot_name}"
                capture_irc_message.call(bot_name, bot_name, reaction, channel, :bot_llm_response, true)
              elsif m.message.include?('?')
                non_answer_msg = get_personality_messages.call(bot_name, user_id, 'non_answer')
                m.reply non_answer_msg
                # Capture bot command response
                channel = m.channel ? m.channel.name : "##{bot_name}"
                capture_irc_message.call(bot_name, bot_name, non_answer_msg, channel, :bot_command_response, true)
              end
            end
          rescue Exception => e
            puts e.message
            puts e.backtrace.inspect
            if m.message.include?('?')
              m.reply get_personality_messages.call(bot_name, user_id, 'non_answer')
            end
          end
        end
      end

      on :message, 'ready' do |m|
        m.reply get_personality_messages.call(bot_name, m.user.nick, 'getting_shell')
        current = bots_ref[bot_name]['current_attack']

        if bots_ref[bot_name]['attacks'][current].key?('pre_shell')
          pre_shell_cmd = bots_ref[bot_name]['attacks'][current]['pre_shell'].to_s.clone
          pre_shell_cmd.gsub!(/{{chat_ip_address}}/, m.user.host.to_s)

          pre_output = `#{pre_shell_cmd}`
          unless bots_ref[bot_name]['attacks'][current].key?('suppress_command_output_feedback')
            m.reply "FYI: #{pre_output}"
          end
          bots_ref[bot_name]['attacks'][current]['pre_shell_command_outputs'] ||= []
          bots_ref[bot_name]['attacks'][current]['pre_shell_command_outputs'] << pre_output
          current = check_output_conditions(bot_name, bots_ref, current, pre_output, m)
        end

        # use bot-wide method for obtaining shell, unless specified per-attack
        if bots_ref[bot_name]['attacks'][current].key?('get_shell')
          shell_cmd = bots_ref[bot_name]['attacks'][current]['get_shell'].to_s.clone
        else
          shell_cmd = bots_ref[bot_name]['get_shell'].clone
        end

        if shell_cmd != 'false'
          # substitute special variables
          shell_cmd.gsub!(/{{chat_ip_address}}/, m.user.host.to_s)
          # add a ; to ensure it is run via bash
          shell_cmd << ';'
          Print.debug shell_cmd

          got_shell = false
          Open3.popen2e(shell_cmd) do |stdin, stdout_err, wait_thr|
            begin
              Timeout.timeout(240) do # timeout 240 sec, 4mins to get root
                # check whether we have shell by echoing "shelltest"
                lines = ''
                i = 0
                while i < 60 and not got_shell # retry for a while
                  i += 1
                  Print.debug i.to_s
                  stdin.puts "echo shelltest\n"
                  sleep(5)

                  # non-blocking read from buffer
                  begin
                    while ch = stdout_err.read_nonblock(1)
                      lines << ch
                    end
                  rescue # continue consuming until input blocks
                  end
                  bots_ref[bot_name]['attacks'][current]['get_shell_command_output'] = lines

                  Print.debug lines
                  if lines =~ /shelltest/i
                    got_shell = true
                    Print.debug 'Got shell!'
                  else
                    Print.debug 'Still trying to get shell...'
                    m.reply '...'
                  end
                end
                Print.debug got_shell.to_s
              end
            rescue Timeout::Error
              got_shell = false
              m.reply 'Took too long...'
            rescue
              got_shell = false
            end

            if got_shell
              m.reply get_personality_messages.call(bot_name, m.user.nick, 'got_shell')

              post_cmd = bots_ref[bot_name]['attacks'][current]['post_command']
              if post_cmd
                Print.debug post_cmd
                post_cmd.gsub!(/{{chat_ip_address}}/, m.user.host.to_s)
                stdin.puts "#{post_cmd}\n"
              end

              sleep(3)
              # non-blocking read from buffer
              post_lines = ''
              begin
                while ch = stdout_err.read_nonblock(1)
                  post_lines << ch
                end
              rescue # continue consuming until input blocks
              end
              begin
                Timeout.timeout(15) do # timeout 15 sec
                  stdin.close # no more input, end the program
                  post_lines << stdout_err.read.chomp()
                end
              rescue Timeout::Error
                wait_thr.kill

                begin
                  while ch = stdout_err.read_nonblock(1)
                    post_lines << ch
                  end
                rescue # continue consuming until input blocks
                end
              end

              bots_ref[bot_name]['attacks'][current]['post_command_output'] = post_lines
              bots_ref[bot_name]['attacks'][current]['post_command_outputs'] ||= []
              bots_ref[bot_name]['attacks'][current]['post_command_outputs'] << post_lines

              unless bots_ref[bot_name]['attacks'][current].key?('suppress_command_output_feedback')
                  m.reply "FYI: #{post_lines}"
              end
              Print.debug post_lines

              if post_lines && !post_lines.empty?
              current = check_output_conditions(bot_name, bots_ref, current, post_lines, m)
            end
            else
              Print.debug("Shell failed...")
              # shell fail message will use the default message, unless specified for the attack
              if bots_ref[bot_name]['attacks'][current].key?('shell_fail_message')
                  m.reply bots_ref[bot_name]['attacks'][current]['shell_fail_message']
              else
                  m.reply get_personality_messages.call(bot_name, m.user.nick, 'shell_fail_message')
              end
              # under specific situations reveal the error message to the user
              if defined?(lines) && lines =~ /command not found/
                  m.reply "Looks like there is some software missing: #{lines}"
              end
            end

            # ensure any child processes are not left running (without this msfconsole is left running)
            `kill -9 $(ps -o pid --no-headers --ppid #{wait_thr.pid})`
            wait_thr.kill
          end
        end

        if bots_ref[bot_name]['attacks'][current].key?('post_shell')
          post_shell_cmd = bots_ref[bot_name]['attacks'][current]['post_shell'].to_s.clone
          post_shell_cmd.gsub!(/{{chat_ip_address}}/, m.user.host.to_s)

          post_output = `#{post_shell_cmd}`
          unless bots_ref[bot_name]['attacks'][current].key?('suppress_command_output_feedback')
            m.reply "FYI: #{post_output}"
          end
          # bots_ref[bot_name]['attacks'][current]['get_shell_command_output'] = post_output
          current = check_output_conditions(bot_name, bots_ref, current, post_output, m)
        end

        m.reply get_personality_messages.call(bot_name, m.user.nick, 'repeat')
      end
    end
  end

  def start_bots
    threads = []
    @bots.each do |bot_name, bot|
      threads << Thread.new {
        Print.std "Starting bot: #{bot_name}\n"
        bot['bot'].start
      }
    end
    ThreadsWait.all_waits(threads)
  end
# Helper functions that need to be accessible to the bot instances
  def update_bot_state(bot_name, bots, current_attack)
  bots[bot_name]['current_attack'] = current_attack
  bots[bot_name]['current_quiz'] = nil
  bots[bot_name]['attacks'][current_attack]['post_command_outputs'] ||= []
  bots[bot_name]['attacks'][current_attack]['shell_command_outputs'] ||= []
end

def check_output_conditions(bot_name, bots, current, lines, m)
  bots[bot_name]['attacks'][current]['shell_command_outputs'] ||= []
  bots[bot_name]['attacks'][current]['shell_command_outputs'] << lines

  condition_met = false
  bots[bot_name]['attacks'][current]['condition'].each do |condition|
    if !condition_met && condition.key?('output_matches') && lines =~ /#{condition['output_matches']}/m
      condition_met = true
      m.reply "#{condition['message']}"
    end
    if !condition_met && condition.key?('output_not_matches') && lines !~ /#{condition['output_not_matches']}/m
      condition_met = true
      m.reply "#{condition['message']}"
    end
    if !condition_met && condition.key?('output_equals') && lines.chomp == condition['output_equals']
      condition_met = true
      m.reply "#{condition['message']}"
    end

    if condition_met
      if condition.key?('trigger_next_attack')
        if bots[bot_name]['current_attack'] < bots[bot_name]['attacks'].length - 1
          current = bots[bot_name]['current_attack'] + 1
          update_bot_state(bot_name, bots, current)

          sleep(1)
          if bots[bot_name]['messages'].key?('show_attack_numbers')
            m.reply "** ##{current + 1} **"
          end
          m.reply bots[bot_name]['attacks'][current]['prompt']
        else
          m.reply bots[bot_name]['messages']['last_attack'].sample
        end
      end

      if condition.key?('trigger_quiz')
        m.reply bots[bot_name]['attacks'][current]['quiz']['question']
        m.reply bots[bot_name]['messages']['say_answer']
        bots[bot_name]['current_quiz'] = 0
      end
      # stop processing conditions, once we meet one
      break
    end
  end
  unless condition_met
    if bots[bot_name]['attacks'][current]['else_condition']
      m.reply bots[bot_name]['attacks'][current]['else_condition']['message']
    end
  end
  current
end
end
