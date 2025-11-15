require 'net/http'
require 'json'
require_relative './llm_client.rb'

# Default configuration constants for OpenAI
DEFAULT_OPENAI_HOST = 'api.openai.com'
DEFAULT_OPENAI_MODEL = 'gpt-3.5-turbo'
DEFAULT_OPENAI_MAX_TOKENS = 150
DEFAULT_OPENAI_TEMPERATURE = 0.7

# OpenAI API client for LLM integration
class OpenAIClient < LLMClient
  def initialize(api_key, host = nil, model = nil, system_prompt = nil, max_tokens = nil, temperature = nil, streaming = nil, base_url = nil)
    # Set defaults if not provided
    @api_key = api_key
    @host = host || DEFAULT_OPENAI_HOST
    model = model || DEFAULT_OPENAI_MODEL

    # Call parent constructor
    super('openai', model, system_prompt, max_tokens || DEFAULT_OPENAI_MAX_TOKENS, temperature || DEFAULT_OPENAI_TEMPERATURE, streaming)

    # Use provided base_url, otherwise construct from host
    @base_url = if base_url
      # Remove trailing slash if present to ensure consistency
      base_url.end_with?('/') ? base_url.chop : base_url
    else
      "https://#{@host}/v1"
    end
  end

  # Generate response from OpenAI
  def generate_response(prompt, stream_callback = nil)
    if @streaming && stream_callback
      return generate_streaming_response(prompt, stream_callback)
    end

    begin
      uri = URI("#{@base_url}/chat/completions")
      Print.info "Generating response using OpenAI model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      # Format messages for OpenAI Chat API
      messages = [
        { role: 'system', content: @system_prompt },
        { role: 'user', content: prompt }
      ]

      request_body = {
        model: @model,
        messages: messages,
        max_tokens: @max_tokens,
        temperature: @temperature,
        stream: false
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 300
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@api_key}"
      request.body = request_body.to_json

      response = http.request(request)
      if response.code == '200'
        result = JSON.parse(response.body)
        response_text = result['choices'][0]['message']['content'].strip
        return response_text
      else
        Print.err "OpenAI API error: #{response.code} - #{response.body}"
        return nil
      end
    rescue => e
      Print.err "Error calling OpenAI API: #{e.message}"
      return nil
    end
  end

  # Generate streaming response from OpenAI
  def generate_streaming_response(prompt, stream_callback = nil)
    begin
      uri = URI("#{@base_url}/chat/completions")
      Print.info "Generating streaming response using OpenAI model: #{@model}"
      Print.info "Prompt:"
      Print.info prompt

      # Format messages for OpenAI Chat API
      messages = [
        { role: 'system', content: @system_prompt },
        { role: 'user', content: prompt }
      ]

      request_body = {
        model: @model,
        messages: messages,
        max_tokens: @max_tokens,
        temperature: @temperature,
        stream: true
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 300
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Authorization'] = "Bearer #{@api_key}"
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
                  if data['choices'] && data['choices'][0] && data['choices'][0]['delta'] && data['choices'][0]['delta']['content']
                    text_chunk = data['choices'][0]['delta']['content']
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
          Print.err "OpenAI API error: #{response.code} - #{response.body}"
          return nil
        end
      end
    rescue => e
      Print.err "Error calling OpenAI API: #{e.message}"
      return nil
    end
  end

  # Test connection to OpenAI
  def test_connection
    begin
      uri = URI("#{@base_url}/models")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      response = http.request(request)
      return response.code == '200'
    rescue => e
      Print.err "Cannot connect to OpenAI: #{e.message}"
      return false
    end
  end
end
