# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Openai
    class Completions
      API_URL = 'https://api.openai.com/v1/chat/completions'
      DEFAULT_MODEL = 'gpt-4o-mini'

      # Class method to generate a completion based on a user prompt
      #
      # @param user_prompt [String] the user's input to generate a completion for
      # @param system_prompt [String] an optional system prompt to guide the AI's behavior
      # @param assistant_prompt [String] an optional assistant prompt to provide context for the assistant's behavior
      # @param model [String] the model to be used for generating completions, defaults to DEFAULT_MODEL
      # @param json_schema [Hash, nil] an optional JSON schema to enforce structured output
      # @param max_tokens [Integer] the maximum number of tokens for the completion (default: 50)
      # @return [String] the generated completion text
      # @raise [APIKeyNotConfiguredError] if the API key is not set
      # @raise [RuntimeError] for general API errors or unexpected issues
      def self.create(user_prompt:, system_prompt: "You are a helpful assistant.", assistant_prompt: nil, model: DEFAULT_MODEL, json_schema: nil, max_tokens: nil)
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

        request.body = generate_body(user_prompt, system_prompt, assistant_prompt, model, json_schema, max_tokens).to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "OpenAI API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        parsed_response = JSON.parse(response.body)

        # Check if the response contains a refusal
        if parsed_response.dig('choices', 0, 'message', 'refusal')
          raise "Refusal: #{parsed_response.dig('choices', 0, 'message', 'refusal')}"
        end

        # Check if the finish reason is "length", indicating incomplete response
        if parsed_response.dig('choices', 0, 'finish_reason') == "length"
          raise "Incomplete response: The completion was cut off due to token limit."
        end

        # Return the structured output if it's included
        parsed_response.dig('choices', 0, 'message', 'content')
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
      # @return [Hash] the body for the API request
      def self.generate_body(user_prompt, system_prompt, assistant_prompt, model, json_schema, max_tokens)
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

        body
      end
    end
  end
end
