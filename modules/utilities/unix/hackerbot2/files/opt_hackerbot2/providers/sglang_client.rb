require 'net/http'
require 'json'
require_relative './llm_client.rb'

# Default configuration constants for SGLang
DEFAULT_SGLANG_HOST = 'localhost'
DEFAULT_SGLANG_PORT = 30000
DEFAULT_SGLANG_MODEL = 'meta-llama/Llama-2-7b-chat-hf'

# SGLang API client for LLM integration
class SGLangClient < LLMClient
  def initialize(host = nil, port = nil, model = nil, system_prompt = nil, max_tokens = nil, temperature = nil, streaming = nil)
    # Set defaults if not provided
    @host = host || DEFAULT_SGLANG_HOST
    @port = port || DEFAULT_SGLANG_PORT
    model = model || DEFAULT_SGLANG_MODEL

    # Call parent constructor
    super('sglang', model, system_prompt, max_tokens, temperature, streaming)

    @base_url = "http://#{@host}:#{@port}"
  end

  # Generate response from SGLang
  def generate_response(prompt, stream_callback = nil)
    if @streaming && stream_callback
      return generate_streaming_response(prompt, stream_callback)
    end

    begin
      uri = URI("#{@base_url}/generate")
      Print.info "Generating response using SGLang model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      # Format prompt with system prompt for SGLang
      formatted_prompt = "#{@system_prompt}\n\n#{prompt}"

      request_body = {
        text: formatted_prompt,
        sampling_params: {
          max_new_tokens: @max_tokens,
          temperature: @temperature
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
        response_text = result['text'].strip
        return response_text
      else
        Print.err "SGLang API error: #{response.code} - #{response.body}"
        return nil
      end
    rescue => e
      Print.err "Error calling SGLang API: #{e.message}"
      return nil
    end
  end

  # Generate streaming response from SGLang
  def generate_streaming_response(prompt, stream_callback = nil)
    begin
      uri = URI("#{@base_url}/generate")
      Print.info "Generating streaming response using SGLang model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      # Format prompt with system prompt for SGLang
      formatted_prompt = "#{@system_prompt}\n\n#{prompt}"

      request_body = {
        text: formatted_prompt,
        sampling_params: {
          max_new_tokens: @max_tokens,
          temperature: @temperature
        },
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
            # Handle streaming response chunks
            chunk.each_line do |line|
              line.strip!
              next if line.empty?

              begin
                # SGLang streaming might send different formats, handle accordingly
                if line.start_with?("data: ")
                  data_str = line[6..-1] # Remove "data: " prefix
                  data = JSON.parse(data_str)

                  if data['text']
                    # For SGLang, we might get incremental text updates
                    text_chunk = data['text']
                    # Extract only the new part if it's a continuation
                    new_text = text_chunk[full_response.length..-1] || ""

                    if !new_text.empty?
                      full_response = text_chunk
                      current_line << new_text

                      if stream_callback && !new_text.empty?
                        stream_callback.call(new_text)
                      end

                      if current_line.include?("\n")
                        lines = current_line.split("\n", -1)
                        current_line = lines.last
                      end
                    end
                  end
                end
              rescue JSON::ParserError => e
                # If it's not JSON, treat as raw text (some streaming formats)
                if !line.empty? && line != "data: [DONE]"
                  text_chunk = line
                  # Remove data prefix if present
                  if text_chunk.start_with?("data: ")
                    text_chunk = text_chunk[6..-1]
                  end

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
              end
            end
          end

          if !current_line.strip.empty? && stream_callback
            stream_callback.call(current_line.strip)
          end

          return full_response.strip
        else
          Print.err "SGLang API error: #{response.code} - #{response.body}"
          return nil
        end
      end
    rescue => e
      Print.err "Error calling SGLang API: #{e.message}"
      return nil
    end
  end

  # Test connection to SGLang
  def test_connection
    begin
      uri = URI("#{@base_url}/health")
      http = Net::HTTP.new(@host, @port)
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      return response.code == '200'
    rescue => e
      Print.err "Cannot connect to SGLang: #{e.message}"
      return false
    end
  end
end
