# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Openai
    class Embeddings
      API_URL = 'https://api.openai.com/v1/embeddings'
      MODEL = 'text-embedding-3-small'

      def self.generate(text)
        api_key = Spectre.api_key
        raise "API key is not configured" unless api_key

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        request.body = { model: MODEL, input: text }.to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "OpenAI API Error: #{response.body}"
        end

        JSON.parse(response.body).dig('data', 0, 'embedding')
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      end
    end
  end
end
