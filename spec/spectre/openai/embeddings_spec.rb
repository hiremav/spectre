# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spectre::Openai::Embeddings do
  let(:api_key) { 'test_api_key' }
  let(:text) { 'example text' }
  let(:embedding) { [0.1, 0.2, 0.3] }
  let(:response_body) { { data: [{ embedding: embedding }] }.to_json }

  before do
    Spectre.setup do |config|
      config.llm_provider = :openai
      config.openai do |openai|
        openai.api_key = api_key
      end
    end
  end

  describe '.generate' do
    context 'when the API key is not configured' do
      before do
        Spectre.setup do |config|
          config.llm_provider = :openai
          config.openai do |openai|
            openai.api_key = nil
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
        stub_request(:post, Spectre::Openai::Embeddings::API_URL)
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the embedding' do
        result = described_class.create(text)
        expect(result).to eq(embedding)
      end
    end

    context 'when the API returns an error' do
      before do
        stub_request(:post, Spectre::Openai::Embeddings::API_URL)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error with the API response' do
        expect {
          described_class.create(text)
        }.to raise_error(RuntimeError, /OpenAI API Error/)
      end
    end

    context 'when the response is not valid JSON' do
      before do
        stub_request(:post, Spectre::Openai::Embeddings::API_URL)
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
