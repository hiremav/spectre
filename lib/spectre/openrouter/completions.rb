# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Openrouter
    class Completions
      API_URL = 'https://openrouter.ai/api/v1/chat/completions'
      DEFAULT_MODEL = 'openai/gpt-4o-mini'
      DEFAULT_TIMEOUT = 60

      # Generate a completion based on user messages and optional tools
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions
      # @param json_schema [Hash, nil] An optional JSON schema to enforce structured output (OpenAI-compatible)
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @param args [Hash, nil] optional arguments like read_timeout and open_timeout. Provide max_tokens at the top level only.
      #   Any additional kwargs (e.g., temperature:, top_p:) will be forwarded into the request body.
      # @return [Hash] The parsed response including any tool calls or content
      # @raise [APIKeyNotConfiguredError] If the API key is not set
      # @raise [RuntimeError] For general API errors or unexpected issues
      def self.create(messages:, model: DEFAULT_MODEL, json_schema: nil, tools: nil, **args)
        cfg = Spectre.openrouter_configuration
        api_key = cfg&.api_key
        raise APIKeyNotConfiguredError, 'API key is not configured' unless api_key

        validate_messages!(messages)

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = args.fetch(:read_timeout, DEFAULT_TIMEOUT)
        http.open_timeout = args.fetch(:open_timeout, DEFAULT_TIMEOUT)

        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        }
        headers['HTTP-Referer'] = cfg.referer if cfg.respond_to?(:referer) && cfg.referer
        headers['X-Title'] = cfg.app_title if cfg.respond_to?(:app_title) && cfg.app_title

        request = Net::HTTP::Post.new(uri.path, headers)

        max_tokens = args[:max_tokens]
        # Forward extra args into body, excluding control/network keys
        forwarded = args.reject { |k, _| [:read_timeout, :open_timeout, :max_tokens].include?(k) }
        request.body = generate_body(messages, model, json_schema, max_tokens, tools, forwarded).to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "OpenRouter API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        parsed_response = JSON.parse(response.body)
        handle_response(parsed_response)
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      end

      private

      def self.validate_messages!(messages)
        unless messages.is_a?(Array) && messages.all? { |msg| msg.is_a?(Hash) }
          raise ArgumentError, 'Messages must be an array of message hashes.'
        end
        raise ArgumentError, 'Messages cannot be empty.' if messages.empty?
      end

      def self.generate_body(messages, model, json_schema, max_tokens, tools, forwarded)
        body = {
          model: model,
          messages: messages
        }
        body[:max_tokens] = max_tokens if max_tokens
        body[:response_format] = { type: 'json_schema', json_schema: json_schema } if json_schema
        body[:tools] = tools if tools
        if forwarded && !forwarded.empty?
          body.merge!(forwarded.transform_keys(&:to_sym))
        end
        body
      end

      # Handle OpenRouter finish reasons
      # https://openrouter.ai/docs/api-reference/overview#finish-reason
      def self.handle_response(response)
        message = response.dig('choices', 0, 'message') || {}
        finish_reason = response.dig('choices', 0, 'finish_reason')

        if message['refusal']
          raise "Refusal: #{message['refusal']}"
        end

        case finish_reason
        when 'stop'
          return { content: message['content'] }
        when 'tool_calls', 'function_call'
          return { tool_calls: message['tool_calls'], content: message['content'] }
        when 'length', 'model_length'
          raise 'Incomplete response: The completion was cut off due to token limit.'
        when 'content_filter'
          raise "Content filtered: The model's output was blocked due to policy violations."
        when 'error'
          raise "Model returned finish_reason=error: #{response.inspect}"
        else
          raise "Unexpected finish_reason: #{finish_reason}"
        end
      end
    end
  end
end
