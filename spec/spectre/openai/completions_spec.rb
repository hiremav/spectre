# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spectre::Openai::Completions do
  let(:api_key) { 'test_api_key' }
  let(:user_prompt) { 'Tell me a joke.' }
  let(:system_prompt) { 'You are a funny assistant.' }
  let(:assistant_prompt) { 'Sure, here\'s a joke!' }
  let(:completion) { 'Why did the chicken cross the road? To get to the other side!' }
  let(:response_body) { { choices: [{ message: { content: completion }, finish_reason: 'stop' }] }.to_json }

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
          described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt)
        }.to raise_error(Spectre::APIKeyNotConfiguredError, 'API key is not configured')
      end
    end

    context 'when the request is successful' do
      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the completion text' do
        result = described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt, assistant_prompt: assistant_prompt)
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
          described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt)
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
          described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt)
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
          described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt)
        }.to raise_error(RuntimeError, /Request Timeout/)
      end
    end

    context 'when the response finish_reason is length' do
      let(:incomplete_response_body) { { choices: [{ message: { content: completion }, finish_reason: 'length' }] }.to_json }

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: incomplete_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises an incomplete response error' do
        expect {
          described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt)
        }.to raise_error(RuntimeError, /Incomplete response: The completion was cut off due to token limit./)
      end
    end

    context 'with a max_tokens parameter' do
      let(:max_tokens) { 30 }

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sends the max_tokens parameter in the request' do
        described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt, max_tokens: max_tokens)

        expect(a_request(:post, Spectre::Openai::Completions::API_URL)
                 .with(body: hash_including(max_tokens: max_tokens))).to have_been_made
      end
    end

    context 'with a json_schema parameter' do
      let(:json_schema) { { name: 'completion_response', schema: { type: 'object', properties: { response: { type: 'string' } } } } }

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sends the json_schema in the request' do
        described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt, json_schema: json_schema)

        expect(a_request(:post, Spectre::Openai::Completions::API_URL)
                 .with { |req| JSON.parse(req.body)['response_format']['json_schema'] == JSON.parse(json_schema.to_json) }).to have_been_made.once
      end
    end

    context 'when the response contains a refusal' do
      let(:refusal_response_body) do
        { choices: [{ message: { refusal: "I'm sorry, I cannot assist with that request." } }] }.to_json
      end

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: refusal_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises a refusal error' do
        expect {
          described_class.generate(user_prompt: user_prompt, system_prompt: system_prompt)
        }.to raise_error(RuntimeError, /Refusal: I'm sorry, I cannot assist with that request./)
      end
    end
  end
end
