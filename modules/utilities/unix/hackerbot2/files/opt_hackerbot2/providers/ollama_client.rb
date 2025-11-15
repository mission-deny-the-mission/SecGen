require 'net/http'
require 'json'
require_relative '../print.rb'
require_relative './llm_client.rb'

# Default configuration constants for Ollama
DEFAULT_OLLAMA_HOST = 'localhost'
DEFAULT_OLLAMA_PORT = 11434
DEFAULT_OLLAMA_MODEL = 'gemma3:1b'
DEFAULT_OLLAMA_NUM_THREAD = 8
DEFAULT_OLLAMA_KEEPALIVE = -1

# Ollama API client for LLM integration
class OllamaClient < LLMClient
  def initialize(host = nil, port = nil, model = nil, system_prompt = nil, max_tokens = nil, temperature = nil, num_thread = nil, keepalive = nil, streaming = nil)
    # Set defaults if not provided
    @host = host || DEFAULT_OLLAMA_HOST
    @port = port || DEFAULT_OLLAMA_PORT
    model = model || DEFAULT_OLLAMA_MODEL
    num_thread = num_thread || DEFAULT_OLLAMA_NUM_THREAD
    keepalive = keepalive || DEFAULT_OLLAMA_KEEPALIVE

    # Call parent constructor
    super('ollama', model, system_prompt, max_tokens, temperature, streaming)

    @base_url = "http://#{@host}:#{@port}"
    @num_thread = num_thread
    @keepalive = keepalive
  end

  # Generate response from Ollama
  def generate_response(prompt, stream_callback = nil)
    if @streaming && stream_callback
      return generate_streaming_response(prompt, stream_callback)
    end

    begin
      uri = URI("#{@base_url}/api/generate")
      Print.info "Generating response using Ollama model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      request_body = {
        model: @model,
        prompt: prompt,
        stream: false,
        keepalive: @keepalive,
        options: {
          temperature: @temperature,
          top_p: 0.9,
          max_tokens: @max_tokens,
          num_thread: @num_thread
        }
      }

      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 10
      http.read_timeout = 300
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = request_body.to_json

      response = http.request(request)
      if response.code == '200'
        result = JSON.parse(response.body)
        response_text = result['response'].strip
        return response_text
      else
        Print.err "Ollama API error: #{response.code} - #{response.body}"
        return nil
      end
    rescue => e
      Print.err "Error calling Ollama API: #{e.message}"
      return nil
    end
  end

  # Generate streaming response from Ollama
  def generate_streaming_response(prompt, stream_callback = nil)
    begin
      uri = URI("#{@base_url}/api/generate")
      Print.info "Generating streaming response using Ollama model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      request_body = {
        model: @model,
        prompt: prompt,
        stream: true,
        keepalive: @keepalive,
        options: {
          temperature: @temperature,
          top_p: 0.9,
          max_tokens: @max_tokens,
          num_thread: @num_thread
        }
      }

      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 10
      http.read_timeout = 300
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = request_body.to_json

      full_response = ''
      current_line = ''

      http.request(request) do |response|
        if response.code == '200'
          response.read_body do |chunk|
            chunk.each_line do |line|
              line.strip!
              next if line.empty?

              begin
                data = JSON.parse(line)
                if data['response']
                  text_chunk = data['response']
                  full_response << text_chunk
                  current_line << text_chunk

                  if stream_callback && !text_chunk.empty?
                    stream_callback.call(text_chunk)
                  end

                  if current_line.include?("\n")
                    lines = current_line.split("\n", -1)
                    current_line = lines.last
                  end
                end

                if data['done']
                  if !current_line.strip.empty? && stream_callback
                    stream_callback.call(current_line.strip)
                  end
                  break
                end
              rescue JSON::ParserError => e
                Print.err "Failed to parse streaming response line: #{line}"
                next
              end
            end
          end
          return full_response.strip
        else
          Print.err "Ollama API error: #{response.code} - #{response.body}"
          return nil
        end
      end
    rescue => e
      Print.err "Error calling Ollama API: #{e.message}"
      return nil
    end
  end

  # Test connection to Ollama server
  def test_connection
    begin
      uri = URI("#{@base_url}/api/tags")
      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      return response.code == '200'
    rescue => e
      Print.err "Cannot connect to Ollama: #{e.message}"
      return false
    end
  end
end
