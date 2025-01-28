# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spectre::Ollama::Completions do
  let(:api_key) { 'test_api_key' }
  let(:api_host) { 'http://localhost:11434/' }
  let(:messages) do
    [
      { role: 'user', content: 'Tell me a joke about llamas.' }
    ]
  end
  let(:completion) { 'Why do llamas always win arguments? Because they "alpaca" punch!' }
  let(:response_body) { { message: { content: completion }, done: true }.to_json }

  before do
    Spectre.setup do |config|
      config.llm_provider = :ollama
      config.ollama do |ollama|
        ollama.api_key = api_key
        ollama.host = api_host
      end
    end
  end

  describe '.create' do
    context 'when the API key is not configured' do
      before do
        Spectre.setup do |config|
          config.llm_provider = :ollama
          config.ollama do |ollama|
            ollama.api_key = nil
          end
        end
      end

      it 'raises an APIKeyNotConfiguredError' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(Spectre::APIKeyNotConfiguredError, 'API key is not configured')
      end
    end

    context 'when the host is not configured' do
      before do
        Spectre.setup do |config|
          config.llm_provider = :ollama
          config.ollama do |ollama|
            ollama.api_key = api_key
            ollama.host = nil # Host is not configured
          end
        end
      end

      it 'raises a HostNotConfiguredError' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(Spectre::HostNotConfiguredError, 'Host is not configured')
      end
    end

    context 'when the request is successful' do
      before do
        stub_request(:post, URI.join(api_host, Spectre::Ollama::Completions::API_PATH))
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the completion text' do
        result = described_class.create(messages: messages)
        expect(result).to eq({ content: completion })
      end
    end

    context 'when the API returns an error' do
      before do
        stub_request(:post, URI.join(api_host, Spectre::Ollama::Completions::API_PATH))
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error with the API response' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /Ollama API Error/)
      end
    end

    context 'when the response is not valid JSON' do
      before do
        stub_request(:post, URI.join(api_host, Spectre::Ollama::Completions::API_PATH))
          .to_return(status: 200, body: 'Invalid JSON')
      end

      it 'raises a JSON Parse Error' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /JSON Parse Error/)
      end
    end

    context 'when the response contains a tool call' do
      let(:tool_response_body) do
        {
          message: {
            tool_calls: { tool: 'get_weather', parameters: { location: 'New York' } },
            content: 'Tool called successfully'
          },
          done: true
        }.to_json
      end

      before do
        stub_request(:post, URI.join(api_host, Spectre::Ollama::Completions::API_PATH))
          .to_return(status: 200, body: tool_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the tool call details' do
        result = described_class.create(messages: messages)
        expect(result).to eq({
                               tool_calls: { 'tool' => 'get_weather', 'parameters' => { 'location' => 'New York' } },
                               content: 'Tool called successfully'
                             })
      end
    end

    context 'with a json_schema parameter' do
      let(:json_schema) do
        {
          'type' => 'object',
          'properties' => {
            'joke' => { 'type' => 'string', 'description' => 'A humorous statement about llamas' }
          },
          'required' => ['joke']
        }
      end

      before do
        stub_request(:post, URI.join(api_host, Spectre::Ollama::Completions::API_PATH))
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sends the json_schema in the request' do
        described_class.create(messages: messages, json_schema: json_schema)

        expect(a_request(:post, URI.join(api_host, Spectre::Ollama::Completions::API_PATH))
                 .with { |req| JSON.parse(req.body)['format'] == json_schema }).to have_been_made.once
      end
    end

    context 'when the response contains an unexpected error' do
      let(:unexpected_response_body) do
        { message: {}, done_reason: 'unexpected_error', done: false }.to_json
      end

      before do
        stub_request(:post, URI.join(api_host, Spectre::Ollama::Completions::API_PATH))
          .to_return(status: 200, body: unexpected_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises an unexpected finish_reason error' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /Unexpected finish_reason: unexpected_error/)
      end
    end
  end
end
