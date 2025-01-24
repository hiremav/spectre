# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spectre::Ollama::Embeddings do
  let(:api_key) { 'test_api_key' }
  let(:host) { 'https://localhost:11434' }
  let(:text) { 'example text' }
  let(:embedding) { [0.1, 0.2, 0.3] }
  let(:response_body) { { embedding: embedding }.to_json }

  before do
    Spectre.setup do |config|
      config.llm_provider = :ollama
      config.ollama do |ollama|
        ollama.api_key = api_key
        ollama.host = host
      end
    end
  end

  describe '.create' do
    context 'when the host is not configured' do
      before do
        Spectre.setup do |config|
          config.llm_provider = :ollama
          config.ollama do |ollama|
            ollama.api_key = api_key
            ollama.host = nil
          end
        end
      end

      it 'raises a HostNotConfiguredError' do
        expect {
          described_class.create(text)
        }.to raise_error(Spectre::HostNotConfiguredError, 'Host is not configured')
      end
    end

    context 'when the API key is not configured' do
      before do
        Spectre.setup do |config|
          config.llm_provider = :ollama
          config.ollama do |ollama|
            ollama.api_key = nil
            ollama.host = host
          end
        end
      end

      it 'raises an APIKeyNotConfiguredError' do
        expect {
          described_class.create(text)
        }.to raise_error(Spectre::APIKeyNotConfiguredError, 'API key is not configured')
      end
    end

    context 'when the request is successful' do
      before do
        stub_request(:post, "#{host}/#{Spectre::Ollama::Embeddings::API_PATH}")
          .with(
            body: { model: Spectre::Ollama::Embeddings::DEFAULT_MODEL, prompt: text }.to_json,
            headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{api_key}" }
          )
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the embedding' do
        result = described_class.create(text)
        expect(result).to eq(embedding)
      end
    end

    context 'when the API returns an error' do
      before do
        stub_request(:post, "#{host}/#{Spectre::Ollama::Embeddings::API_PATH}")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error with the API response' do
        expect {
          described_class.create(text)
        }.to raise_error(RuntimeError, /Ollama API Error/)
      end
    end

    context 'when the response is not valid JSON' do
      before do
        stub_request(:post, "#{host}/#{Spectre::Ollama::Embeddings::API_PATH}")
          .to_return(status: 200, body: 'Invalid JSON')
      end

      it 'raises a JSON Parse Error' do
        expect {
          described_class.create(text)
        }.to raise_error(RuntimeError, /JSON Parse Error/)
      end
    end
  end
end
