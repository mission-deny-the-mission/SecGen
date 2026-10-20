require 'net/http'
require 'json'
require_relative './llm_client.rb'

# Default configuration constants for VLLM
DEFAULT_VLLM_HOST = 'localhost'
DEFAULT_VLLM_PORT = 8000
DEFAULT_VLLM_MODEL = 'facebook/opt-125m'

# VLLM API client for LLM integration
class VLLMClient < LLMClient
  def initialize(host = nil, port = nil, model = nil, system_prompt = nil, max_tokens = nil, temperature = nil, streaming = nil)
    # Set defaults if not provided
    @host = host || DEFAULT_VLLM_HOST
    @port = port || DEFAULT_VLLM_PORT
    model = model || DEFAULT_VLLM_MODEL

    # Call parent constructor
    super('vllm', model, system_prompt, max_tokens, temperature, streaming)

    @base_url = "http://#{@host}:#{@port}"
  end

  # Generate response from VLLM
  def generate_response(prompt, stream_callback = nil)
    if @streaming && stream_callback
      return generate_streaming_response(prompt, stream_callback)
    end

    begin
      uri = URI("#{@base_url}/v1/completions")
      Print.info "Generating response using VLLM model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      # Format prompt with system prompt for VLLM
      formatted_prompt = "#{@system_prompt}\n\n#{prompt}"

      request_body = {
        model: @model,
        prompt: formatted_prompt,
        max_tokens: @max_tokens,
        temperature: @temperature,
        stream: false
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
        response_text = result['choices'][0]['text'].strip
        return response_text
      else
        Print.err "VLLM API error: #{response.code} - #{response.body}"
        return nil
      end
    rescue => e
      Print.err "Error calling VLLM API: #{e.message}"
      return nil
    end
  end

  # Generate streaming response from VLLM
  def generate_streaming_response(prompt, stream_callback = nil)
    begin
      uri = URI("#{@base_url}/v1/completions")
      Print.info "Generating streaming response using VLLM model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      # Format prompt with system prompt for VLLM
      formatted_prompt = "#{@system_prompt}\n\n#{prompt}"

      request_body = {
        model: @model,
        prompt: formatted_prompt,
        max_tokens: @max_tokens,
        temperature: @temperature,
        stream: true
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
            # Handle Server-Sent Events format
            chunk.split("\n\n").each do |event|
              next if event.strip.empty? || event.start_with?("data: [DONE]")

              if event.start_with?("data: ")
                data_str = event[6..-1] # Remove "data: " prefix
                begin
                  data = JSON.parse(data_str)
                  if data['choices'] && data['choices'][0] && data['choices'][0]['text']
                    text_chunk = data['choices'][0]['text']
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
                rescue JSON::ParserError => e
                  Print.err "Failed to parse streaming response event: #{event}"
                  next
                end
              end
            end
          end

          if !current_line.strip.empty? && stream_callback
            stream_callback.call(current_line.strip)
          end

          return full_response.strip
        else
          Print.err "VLLM API error: #{response.code} - #{response.body}"
          return nil
        end
      end
    rescue => e
      Print.err "Error calling VLLM API: #{e.message}"
      return nil
    end
  end

  # Test connection to VLLM
  def test_connection
    begin
      uri = URI("#{@base_url}/v1/models")
      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      return response.code == '200'
    rescue => e
      Print.err "Cannot connect to VLLM: #{e.message}"
      return false
    end
  end
end
