# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Ollama
    class Embeddings
      API_PATH = 'api/embeddings'
      DEFAULT_MODEL = 'nomic-embed-text'
      PARAM_NAME = 'prompt'
      DEFAULT_TIMEOUT = 60

      # Class method to generate embeddings for a given text
      #
      # @param text [String] the text input for which embeddings are to be generated
      # @param model [String] the model to be used for generating embeddings, defaults to DEFAULT_MODEL
      # @param args [Hash, nil] optional arguments like read_timeout and open_timeout
      # @param args.ollama.path [String, nil] the API path, defaults to API_PATH
      # @param args.ollama.param_name [String, nil] the parameter key for the text input, defaults to PARAM_NAME
      # @return [Array<Float>] the generated embedding vector
      # @raise [HostNotConfiguredError] if the host is not set in the configuration
      # @raise [APIKeyNotConfiguredError] if the API key is not set in the configuration
      # @raise [RuntimeError] for API errors or invalid responses
      # @raise [JSON::ParserError] if the response cannot be parsed as JSON
      def self.create(text, model: DEFAULT_MODEL, **args)
        api_host = Spectre.ollama_configuration.host
        api_key = Spectre.ollama_configuration.api_key
        raise HostNotConfiguredError, "Host is not configured" unless api_host
        raise APIKeyNotConfiguredError, "API key is not configured" unless api_key

        path = args.dig(:ollama, :path) || API_PATH
        uri = URI.join(api_host, path)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        http.read_timeout = args.fetch(:read_timeout, DEFAULT_TIMEOUT)
        http.open_timeout = args.fetch(:open_timeout, DEFAULT_TIMEOUT)

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        })

        param_name = args.dig(:ollama, :param_name) || PARAM_NAME
        request.body = { model: model, param_name => text }.to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Ollama API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        JSON.parse(response.body).dig('embedding')
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      end
    end
  end
end
