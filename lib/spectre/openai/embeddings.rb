# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Openai
    class Embeddings
      API_URL = 'https://api.openai.com/v1/embeddings'
      DEFAULT_MODEL = 'text-embedding-3-small'

      # Class method to generate embeddings for a given text
      #
      # @param text [String] the text input for which embeddings are to be generated
      # @param model [String] the model to be used for generating embeddings, defaults to DEFAULT_MODEL
      # @return [Array<Float>] the generated embedding vector
      # @raise [APIKeyNotConfiguredError] if the API key is not set
      # @raise [RuntimeError] for general API errors or unexpected issues
      def self.generate(text, model: DEFAULT_MODEL)
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

        request.body = { model: model, input: text }.to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "OpenAI API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        JSON.parse(response.body).dig('data', 0, 'embedding')
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise "Request Timeout: #{e.message}"
      end
    end
  end
end
