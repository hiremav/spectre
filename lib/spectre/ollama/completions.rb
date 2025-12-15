# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Ollama
    class Completions
      API_PATH = 'api/chat'
      DEFAULT_MODEL = 'llama3.1:8b'
      DEFAULT_TIMEOUT = 60

      # Class method to generate a completion based on user messages and optional tools
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions, defaults to DEFAULT_MODEL
      # @param json_schema [Hash, nil] An optional JSON schema to enforce structured output
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @param args [Hash, nil] optional arguments like read_timeout and open_timeout.
      #   Any additional top-level kwargs (e.g., temperature:, max_tokens:) will be forwarded into body[:options], same as other providers forward into body.
      # @param path [String, nil] Top-level path override for the Ollama API endpoint, defaults to API_PATH
      # @return [Hash] The parsed response including any function calls or content
      # @raise [HostNotConfiguredError] If the API host is not set in the provider configuration.
      # @raise [APIKeyNotConfiguredError] If the API key is not set
      # @raise [RuntimeError] For general API errors or unexpected issues
      def self.create(messages:, model: DEFAULT_MODEL, json_schema: nil, tools: nil, **args)
        api_host = Spectre.ollama_configuration.host
        api_key = Spectre.ollama_configuration.api_key
        raise HostNotConfiguredError, "Host is not configured" unless api_host
        raise APIKeyNotConfiguredError, "API key is not configured" unless api_key

        validate_messages!(messages)

        path = args[:path] || API_PATH
        uri = URI.join(api_host, path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        http.read_timeout = args.fetch(:read_timeout, DEFAULT_TIMEOUT)
        http.open_timeout = args.fetch(:open_timeout, DEFAULT_TIMEOUT)

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        # Forward extra top-level args (like temperature, max_tokens) into body[:options],
        # excluding control/network keys and the request path override.
        forwarded = args.reject { |k, _| [:read_timeout, :open_timeout, :path].include?(k) }
        options = nil
        if forwarded && !forwarded.empty?
          options = forwarded.transform_keys(&:to_sym)
        end
        request.body = generate_body(messages, model, json_schema, tools, options).to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Ollama API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        parsed_response = JSON.parse(response.body)

        handle_response(parsed_response)
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
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
      end

      # Helper method to generate the request body
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions
      # @param json_schema [Hash, nil] An optional JSON schema to enforce structured output
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @param options [Hash, nil] Additional model parameters listed in the documentation for the https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values such as temperature
      # @return [Hash] The body for the API request
      def self.generate_body(messages, model, json_schema, tools, options)
        body = {
          model: model,
          stream: false,
          messages: messages
        }

        # Extract schema if json_schema follows OpenAI's structure
        if json_schema.is_a?(Hash) && json_schema.key?(:schema)
          body[:format] = json_schema[:schema] # Use only the "schema" key
        elsif json_schema.is_a?(Hash)
          body[:format] = json_schema # Use the schema as-is if it doesn't follow OpenAI's structure
        end

        body[:tools] = tools if tools # Add the tools to the request body if provided
        body[:options] = options if options

        body
      end

      # Handles the API response, raising errors for specific cases and returning structured content otherwise
      #
      # @param response [Hash] The parsed API response
      # @return [Hash] The relevant data based on the finish reason
      def self.handle_response(response)
        message = response.dig('message')
        finish_reason = response.dig('done_reason')
        done = response.dig('done')

        # Check if the model made a function call
        if message['tool_calls'] && !message['tool_calls'].empty?
          return { tool_calls: message['tool_calls'], content: message['content'] }
        end

        # If the response finished normally, return the content
        if done
          return { content: message['content'] }
        end

        # Handle unexpected finish reasons
        raise "Unexpected finish_reason: #{finish_reason}, done: #{done}, message: #{message}"
      end
    end
  end
end
