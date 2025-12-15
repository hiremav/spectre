# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Gemini
    class Completions
      # Using Google's OpenAI-compatible endpoint
      API_URL = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
      DEFAULT_MODEL = 'gemini-2.5-flash'
      DEFAULT_TIMEOUT = 60

      # Class method to generate a completion based on user messages and optional tools
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions, defaults to DEFAULT_MODEL
      # @param json_schema [Hash, nil] An optional JSON schema to enforce structured output (OpenAI-compatible "response_format")
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @param args [Hash, nil] optional arguments like read_timeout and open_timeout. Provide max_tokens at the top level only.
      #   Any additional kwargs (e.g., temperature:, top_p:) will be forwarded into the request body.
      # @return [Hash] The parsed response including any function calls or content
      # @raise [APIKeyNotConfiguredError] If the API key is not set
      # @raise [RuntimeError] For general API errors or unexpected issues
      def self.create(messages:, model: DEFAULT_MODEL, json_schema: nil, tools: nil, **args)
        api_key = Spectre.gemini_configuration&.api_key
        raise APIKeyNotConfiguredError, "API key is not configured" unless api_key

        validate_messages!(messages)

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = args.fetch(:read_timeout, DEFAULT_TIMEOUT)
        http.open_timeout = args.fetch(:open_timeout, DEFAULT_TIMEOUT)

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        max_tokens = args[:max_tokens]
        # Forward extra args (like temperature) into the body, excluding control/network keys
        forwarded = args.reject { |k, _| [:read_timeout, :open_timeout, :max_tokens].include?(k) }
        request.body = generate_body(messages, model, json_schema, max_tokens, tools, forwarded).to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Gemini API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        parsed_response = JSON.parse(response.body)

        handle_response(parsed_response)
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      end

      private

      # Validate the structure and content of the messages array.
      def self.validate_messages!(messages)
        unless messages.is_a?(Array) && messages.all? { |msg| msg.is_a?(Hash) }
          raise ArgumentError, "Messages must be an array of message hashes."
        end

        if messages.empty?
          raise ArgumentError, "Messages cannot be empty."
        end

        # Gemini's OpenAI-compatible chat endpoint requires that single-turn
        # and general requests end with a user message. If not, return a clear error.
        last_role = (messages.last[:role] || messages.last['role']).to_s
        unless last_role == 'user'
          raise ArgumentError, "Gemini: the last message must have role 'user'. Got '#{last_role}'."
        end
      end

      # Helper method to generate the request body (OpenAI-compatible)
      def self.generate_body(messages, model, json_schema, max_tokens, tools, forwarded)
        body = {
          model: model,
          messages: messages
        }

        body[:max_tokens] = max_tokens if max_tokens
        body[:response_format] = { type: 'json_schema', json_schema: json_schema } if json_schema
        body[:tools] = tools if tools

        # Merge any extra forwarded options (e.g., temperature, top_p)
        if forwarded && !forwarded.empty?
          body.merge!(forwarded.transform_keys(&:to_sym))
        end

        body
      end

      # Handles the API response, mirroring OpenAI semantics
      def self.handle_response(response)
        message = response.dig('choices', 0, 'message')
        finish_reason = response.dig('choices', 0, 'finish_reason')

        if message && message['refusal']
          raise "Refusal: #{message['refusal']}"
        end

        if finish_reason == 'length'
          raise "Incomplete response: The completion was cut off due to token limit."
        end

        if finish_reason == 'content_filter'
          raise "Content filtered: The model's output was blocked due to policy violations."
        end

        if finish_reason == 'function_call' || finish_reason == 'tool_calls'
          return { tool_calls: message['tool_calls'], content: message['content'] }
        end

        if finish_reason == 'stop'
          return { content: message['content'] }
        end

        raise "Unexpected finish_reason: #{finish_reason}"
      end
    end
  end
end
