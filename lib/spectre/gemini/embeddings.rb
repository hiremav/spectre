# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Gemini
    class Embeddings
      # Using Google's OpenAI-compatible endpoint
      API_URL = 'https://generativelanguage.googleapis.com/v1beta/openai/embeddings'
      DEFAULT_MODEL = 'gemini-embedding-001'
      DEFAULT_TIMEOUT = 60

      # Generate embeddings for text
      def self.create(text, model: DEFAULT_MODEL, **args)
        api_key = Spectre.gemini_configuration&.api_key
        raise APIKeyNotConfiguredError, "API key is not configured" unless api_key

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = args.fetch(:read_timeout, DEFAULT_TIMEOUT)
        http.open_timeout = args.fetch(:open_timeout, DEFAULT_TIMEOUT)

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        request.body = { model: model, input: text }.to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Gemini API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        JSON.parse(response.body).dig('data', 0, 'embedding')
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      end
    end
  end
end
