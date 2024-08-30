# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Openai
    class Completions
      API_URL = 'https://api.openai.com/v1/completions'
      DEFAULT_MODEL = 'gpt-4o-mini'

      # Class method to generate a completion based on a user prompt
      #
      # @param user_prompt [String] the user's input to generate a completion for
      # @param system_prompt [String] an optional system prompt to guide the AI's behavior
      # @param model [String] the model to be used for generating completions, defaults to DEFAULT_MODEL
      # @return [String] the generated completion text
      # @raise [APIKeyNotConfiguredError] if the API key is not set
      # @raise [RuntimeError] for general API errors or unexpected issues
      def self.generate(user_prompt, system_prompt: "You are a helpful assistant.", model: DEFAULT_MODEL)
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

        request.body = generate_body(user_prompt, system_prompt, model).to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "OpenAI API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        JSON.parse(response.body).dig('choices', 0, 'message', 'content')
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
      # @param model [String] the model to be used for generating completions
      # @return [Hash] the body for the API request
      def self.generate_body(user_prompt, system_prompt, model)
        {
          model: model,
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: user_prompt }
          ]
        }
      end
    end
  end
end
