require 'ircinch'
require 'open3'
require 'getoptlong'
require 'thwait'
require './print.rb'
require './bot_manager.rb'

def usage
  Print.std 'USAGE'
  Print.std 'ruby hackerbot.rb [OPTIONS]'
  Print.std ''
  Print.std 'OPTIONS:'
  Print.std '  --irc-server, -i HOST          IRC server IP address (default: localhost)'
  Print.std '  --llm-provider, -l PROVIDER    LLM provider: ollama, openai, vllm, sglang (default: ollama)'
  Print.std '  --ollama-host, -o HOST         Ollama server host (default: localhost)'
  Print.std '  --ollama-port, -p PORT         Ollama server port (default: 11434)'
  Print.std '  --ollama-model, -m MODEL       Ollama model name (default: gemma3:1b)'
  Print.std '  --openai-api-key, -k KEY       OpenAI API key'
  Print.std '  --openai-base-url URL          OpenAI API base URL (default: https://api.openai.com/v1)'
  Print.std '  --vllm-host HOST               VLLM server host (default: localhost)'
  Print.std '  --vllm-port PORT               VLLM server port (default: 8000)'
  Print.std '  --sglang-host HOST             SGLang server host (default: localhost)'
  Print.std '  --sglang-port PORT             SGLang server port (default: 30000)'
  Print.std '  --streaming, -s true|false     Enable/disable streaming (default: true)'
  Print.std '  --enable-rag-cag               Enable RAG + CAG capabilities (default: true)'
  Print.std '  --rag-only                     Enable only RAG system (disables CAG)'

  Print.std '  --offline                      Force offline mode (default: auto-detect)'
  Print.std '  --online                       Force online mode'
  Print.std '  --help, -h                     Show this help message'
end

# -- main --

Print.std '~'*47
Print.std ' '*19 + 'Hackerbot'
Print.std '~'*47

$irc_server_ip_address = 'localhost'
$llm_provider = 'ollama'  # Default provider
$ollama_host = 'localhost'
$ollama_port = 11434
$ollama_model = 'gemma3:1b'
$openai_api_key = nil
$openai_base_url = nil
$vllm_host = 'localhost'
$vllm_port = 8000
$sglang_host = 'localhost'
$sglang_port = 30000
$enable_rag = true
$rag_only = false
$offline_mode = 'auto'  # 'auto', 'offline', 'online'

# Get command line arguments
opts = GetoptLong.new(
    [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
    [ '--irc-server', '-i', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--llm-provider', '-l', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--ollama-host', '-o', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--ollama-port', '-p', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--ollama-model', '-m', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--openai-api-key', '-k', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--openai-base-url', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--vllm-host', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--vllm-port', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--sglang-host', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--sglang-port', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--streaming', '-s', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--enable-rag-cag', GetoptLong::NO_ARGUMENT ],
    [ '--rag-only', GetoptLong::NO_ARGUMENT ],

    [ '--offline', GetoptLong::NO_ARGUMENT ],
    [ '--online', GetoptLong::NO_ARGUMENT ],
)

# process option arguments
begin
  opts.each do |opt, arg|
    case opt
      # Main options
      when '--help'
        usage
        exit
    when '--irc-server'
      $irc_server_ip_address = arg;
    when '--llm-provider'
      $llm_provider = arg;
    when '--ollama-host'
      $ollama_host = arg;
    when '--ollama-port'
      $ollama_port = arg.to_i;
    when '--ollama-model'
      $ollama_model = arg;
    when '--openai-api-key'
      $openai_api_key = arg;
    when '--openai-base-url'
      $openai_base_url = arg;
    when '--vllm-host'
      $vllm_host = arg;
    when '--vllm-port'
      $vllm_port = arg.to_i;
    when '--sglang-host'
      $sglang_host = arg;
    when '--sglang-port'
      $sglang_port = arg.to_i;
    when '--streaming'
      streaming_arg = arg.downcase
      if streaming_arg == 'true' || streaming_arg == 'false'
        $DEFAULT_STREAMING = (streaming_arg == 'true')
      else
        Print.err "Streaming argument must be 'true' or 'false': #{arg}"
        usage
        exit
      end
    when '--enable-rag-cag'
      $enable_rag_cag = true
    when '--rag-only'
      $enable_rag_cag = true
      $rag_only = true


    when '--offline'
      $offline_mode = 'offline'
    when '--online'
      $offline_mode = 'online'
    else
      Print.err "Argument not valid: #{arg}"
      usage
      exit
    end
  end
rescue GetoptLong::InvalidOption => e
  Print.err "Argument not valid: #{e.message}"
  usage
  exit
end

if __FILE__ == $0
  # Prepare RAG + CAG configuration with comprehensive knowledge sources
  rag_config = {
    enable_rag: true,  # Always enable RAG
    offline_mode: $offline_mode,
    knowledge_base_name: 'cybersecurity',
    rag: {
      max_results: 5,
      similarity_threshold: 0.2,  # Even lower threshold for better retrieval
      chunk_size: 1000,
      chunk_overlap: 200
    },
    max_context_length: 16000,  # Increased from default 4000 to allow more comprehensive responses
    knowledge_sources_config: [
      # MITRE ATT&CK Framework
      {
        type: 'mitre_attack',
        name: 'mitre_attack',
        enabled: true,
        description: 'MITRE ATT&CK framework knowledge base',
        priority: 1
      },
      # Man pages temporarily disabled due to text length issues
      # {
      #   type: 'man_pages',
      #   name: 'cybersecurity_man_pages',
      #   enabled: false,
      #   description: 'Common cybersecurity and security tool man pages',
      #   priority: 2
      # },
      # Project documentation
      {
        type: 'markdown_files',
        name: 'project_docs',
        enabled: true,
        description: 'Project documentation and guides',
        priority: 3,
        markdown_files: [
          { path: 'README.md', collection_name: 'cybersecurity' },
          { path: 'QUICKSTART.md', collection_name: 'cybersecurity' },
          { path: 'docs/*.md', collection_name: 'cybersecurity' }
        ]
      }
    ]
  }

  bot_manager = BotManager.new($irc_server_ip_address, $llm_provider, $ollama_host, $ollama_port, $ollama_model, $openai_api_key, $openai_base_url, $vllm_host, $vllm_port, $sglang_host, $sglang_port, $enable_rag, rag_config)
  bots = bot_manager.read_bots
  bot_manager.start_bots
end
