# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Openai
    class Functions
      API_URL = 'https://api.openai.com/v1/chat/completions'
      DEFAULT_MODEL = 'gpt-4o-mini'

      # Class method to generate a completion with function calling capabilities
      #
      # @param user_prompt [String] the user's input to generate a completion for
      # @param system_prompt [String] an optional system prompt to guide the AI's behavior
      # @param assistant_prompt [String] an optional assistant prompt to provide context for the assistant's behavior
      # @param model [String] the model to be used for generating completions, defaults to DEFAULT_MODEL
      # @param json_schema [Hash, nil] an optional JSON schema to enforce structured output
      # @param max_tokens [Integer] the maximum number of tokens for the completion (default: 50)
      # @param tools [Array, nil] an optional array of tools (functions) that the assistant can call
      # @return [Hash] the generated completion or function call information
      # @raise [APIKeyNotConfiguredError] if the API key is not set
      # @raise [RuntimeError] for general API errors or unexpected issues
      def self.create(user_prompt:, system_prompt: "You are a helpful assistant.", assistant_prompt: nil, model: DEFAULT_MODEL, json_schema: nil, max_tokens: nil, tools: nil)
        api_key = Spectre.api_key
        raise APIKeyNotConfiguredError, "API key is not configured" unless api_key

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 10 # seconds
        http.open_timeout = 10 # seconds

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        request.body = generate_body(user_prompt, system_prompt, assistant_prompt, model, json_schema, max_tokens, tools).to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "OpenAI API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        parsed_response = JSON.parse(response.body)
        handle_response(parsed_response)
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise "Request Timeout: #{e.message}"
      end

      private

      # Helper method to generate the request body
      #
      # @param user_prompt [String] the user's input to generate a completion for
      # @param system_prompt [String] an optional system prompt to guide the AI's behavior
      # @param assistant_prompt [String] an optional assistant prompt to provide context for the assistant's behavior
      # @param model [String] the model to be used for generating completions
      # @param json_schema [Hash, nil] an optional JSON schema to enforce structured output
      # @param max_tokens [Integer, nil] the maximum number of tokens for the completion
      # @param tools [Array, nil] an optional array of tools (functions) that the assistant can call
      # @return [Hash] the body for the API request
      def self.generate_body(user_prompt, system_prompt, assistant_prompt, model, json_schema, max_tokens, tools)
        messages = [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_prompt }
        ]

        # Add the assistant prompt if provided
        messages << { role: 'assistant', content: assistant_prompt } if assistant_prompt

        body = {
          model: model,
          messages: messages,
        }
        body['max_tokens'] = max_tokens if max_tokens

        # Add the JSON schema as part of response_format if provided
        if json_schema
          body[:response_format] = {
            type: 'json_schema',
            json_schema: json_schema
          }
        end

        # Add tools (functions) to the body if provided
        body[:tools] = tools if tools

        body
      end

      # Handles the API response, raising errors for specific cases and returning structured content otherwise
      #
      # @param response [Hash] The parsed API response
      # @return [Hash] The relevant data based on the finish reason
      def self.handle_response(response)
        message = response.dig('choices', 0, 'message')
        finish_reason = message['finish_reason']

        case finish_reason
        when 'length'
          raise "Incomplete response: The conversation was too long for the context window."
        when 'content_filter'
          raise "Content filtered: The model's output was blocked due to policy violations."
        when 'tool_calls', 'function_call'
          # Returning function call details
          { function_call: message['function_call'], content: message['content'] }
        when 'stop'
          # Normal response
          { content: message['content'] }
        else
          raise "Unexpected finish_reason: #{finish_reason}"
        end
      end
    end
  end
end
