# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spectre::Openai::Completions do
  let(:api_key) { 'test_api_key' }
  let(:user_prompt) { 'Tell me a joke.' }
  let(:system_prompt) { 'You are a funny assistant.' }
  let(:completion) { 'Why did the chicken cross the road? To get to the other side!' }
  let(:response_body) { { choices: [{ message: { content: completion } }] }.to_json }

  before do
    allow(Spectre).to receive(:api_key).and_return(api_key)
  end

  describe '.generate' do
    context 'when the API key is not configured' do
      before do
        allow(Spectre).to receive(:api_key).and_return(nil)
      end

      it 'raises an APIKeyNotConfiguredError' do
        expect {
          described_class.generate(user_prompt, system_prompt: system_prompt)
        }.to raise_error(Spectre::APIKeyNotConfiguredError, 'API key is not configured')
      end
    end

    context 'when the request is successful' do
      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the completion text' do
        result = described_class.generate(user_prompt, system_prompt: system_prompt)
        expect(result).to eq(completion)
      end
    end

    context 'when the API returns an error' do
      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error with the API response' do
        expect {
          described_class.generate(user_prompt, system_prompt: system_prompt)
        }.to raise_error(RuntimeError, /OpenAI API Error/)
      end
    end

    context 'when the response is not valid JSON' do
      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: 'Invalid JSON')
      end

      it 'raises a JSON Parse Error' do
        expect {
          described_class.generate(user_prompt, system_prompt: system_prompt)
        }.to raise_error(RuntimeError, /JSON Parse Error/)
      end
    end

    context 'when the request times out' do
      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_timeout
      end

      it 'raises a Request Timeout error' do
        expect {
          described_class.generate(user_prompt, system_prompt: system_prompt)
        }.to raise_error(RuntimeError, /Request Timeout/)
      end
    end
  end
end
