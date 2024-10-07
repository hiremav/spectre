# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Openai
    class Completions
      API_URL = 'https://api.openai.com/v1/chat/completions'
      DEFAULT_MODEL = 'gpt-4o-mini'

      # Class method to generate a completion based on user messages and optional tools
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions, defaults to DEFAULT_MODEL
      # @param json_schema [Hash, nil] An optional JSON schema to enforce structured output
      # @param max_tokens [Integer] The maximum number of tokens for the completion (default: 50)
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @return [Hash] The parsed response including any function calls or content
      # @raise [APIKeyNotConfiguredError] If the API key is not set
      # @raise [RuntimeError] For general API errors or unexpected issues
      def self.create(messages:, model: DEFAULT_MODEL, json_schema: nil, max_tokens: nil, tools: nil)
        api_key = Spectre.api_key
        raise APIKeyNotConfiguredError, "API key is not configured" unless api_key

        validate_messages!(messages)

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 10 # seconds
        http.open_timeout = 10 # seconds

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        request.body = generate_body(messages, model, json_schema, max_tokens, tools).to_json
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

      # Validate the structure and content of the messages array.
      #
      # @param messages [Array<Hash>] The array of message hashes to validate.
      #
      # @raise [ArgumentError] if the messages array is not in the expected format or contains invalid data.
      def self.validate_messages!(messages)
        # Check if messages is an array of hashes.
        # This ensures that the input is in the correct format for message processing.
        unless messages.is_a?(Array) && messages.all? { |msg| msg.is_a?(Hash) }
          raise ArgumentError, "Messages must be an array of message hashes."
        end

        # Check if the array is empty.
        # This prevents requests with no messages, which would be invalid.
        if messages.empty?
          raise ArgumentError, "Messages cannot be empty."
        end

        # Iterate through each message and perform detailed validation.
        messages.each_with_index do |msg, index|
          # Check if each message hash contains the required keys: :role and :content.
          # These keys are necessary for defining the type of message and its content.
          unless msg.key?(:role) && msg.key?(:content)
            raise ArgumentError, "Message at index #{index} must contain both :role and :content keys."
          end

          # Check if the role is one of the allowed values: 'system', 'user', or 'assistant'.
          # This ensures that each message has a valid role identifier.
          unless %w[system user assistant].include?(msg[:role])
            raise ArgumentError, "Invalid role '#{msg[:role]}' at index #{index}. Valid roles are 'system', 'user', 'assistant'."
          end

          # Check if the content is a non-empty string.
          # This prevents empty or non-string content, which would be meaningless in a conversation.
          unless msg[:content].is_a?(String) && !msg[:content].strip.empty?
            raise ArgumentError, "Content for message at index #{index} must be a non-empty string."
          end
        end
      end

      # Helper method to generate the request body
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions
      # @param json_schema [Hash, nil] An optional JSON schema to enforce structured output
      # @param max_tokens [Integer, nil] The maximum number of tokens for the completion
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @return [Hash] The body for the API request
      def self.generate_body(messages, model, json_schema, max_tokens, tools)
        body = {
          model: model,
          messages: messages
        }

        body[:max_tokens] = max_tokens if max_tokens
        body[:response_format] = { type: 'json_schema', json_schema: json_schema } if json_schema
        body[:tools] = tools if tools # Add the tools to the request body if provided

        body
      end

      # Handles the API response, raising errors for specific cases and returning structured content otherwise
      #
      # @param response [Hash] The parsed API response
      # @return [Hash] The relevant data based on the finish reason
      def self.handle_response(response)
        message = response.dig('choices', 0, 'message')
        finish_reason = response.dig('choices', 0, 'finish_reason')

        # Check if the response contains a refusal
        if message['refusal']
          raise "Refusal: #{message['refusal']}"
        end

        # Check if the finish reason is "length", indicating incomplete response
        if finish_reason == "length"
          raise "Incomplete response: The completion was cut off due to token limit."
        end

        # Check if the finish reason is "content_filter", indicating policy violations
        if finish_reason == "content_filter"
          raise "Content filtered: The model's output was blocked due to policy violations."
        end

        # Check if the model made a function call
        if finish_reason == "function_call" || finish_reason == "tool_calls"
          return { tool_calls: message['tool_calls'], content: message['content'] }
        end

        # If the response finished normally, return the content
        if finish_reason == "stop"
          return { content: message['content'] }
        end

        # Handle unexpected finish reasons
        raise "Unexpected finish_reason: #{finish_reason}"
      end
    end
  end
end
