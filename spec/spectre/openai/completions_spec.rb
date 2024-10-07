# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spectre::Openai::Completions do
  let(:api_key) { 'test_api_key' }
  let(:messages) do
    [
      { role: 'system', content: 'You are a funny assistant.' },
      { role: 'user', content: 'Tell me a joke.' },
      { role: 'assistant', content: 'Sure, here\'s a joke!' }
    ]
  end
  let(:completion) { 'Why did the chicken cross the road? To get to the other side!' }
  let(:response_body) { { choices: [{ message: { content: completion }, finish_reason: 'stop' }] }.to_json }

  before do
    allow(Spectre).to receive(:api_key).and_return(api_key)
  end

  describe '.create' do
    context 'when the API key is not configured' do
      before do
        allow(Spectre).to receive(:api_key).and_return(nil)
      end

      it 'raises an APIKeyNotConfiguredError' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(Spectre::APIKeyNotConfiguredError, 'API key is not configured')
      end
    end

    context 'when the request is successful' do
      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the completion text' do
        result = described_class.create(messages: messages)
        expect(result).to eq({ content: completion })
      end
    end

    context 'when the API returns an error' do
      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error with the API response' do
        expect {
          described_class.create(messages: messages)
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
          described_class.create(messages: messages)
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
          described_class.create(messages: messages)
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
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /Incomplete response: The completion was cut off due to token limit./)
      end
    end

    context 'when the response finish_reason is content_filter' do
      let(:filtered_response_body) { { choices: [{ message: { content: completion }, finish_reason: 'content_filter' }] }.to_json }

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: filtered_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises a content filtered error' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /Content filtered: The model's output was blocked due to policy violations./)
      end
    end

    context 'when the response contains a function call' do
      let(:function_response_body) do
        { choices: [{ message: { tool_calls: { function: 'get_delivery_date', parameters: { order_id: 'order_12345' } }, content: 'Function called' }, finish_reason: 'function_call' }] }.to_json
      end

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: function_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the function call details' do
        result = described_class.create(messages: messages)
        expect(result).to eq({ tool_calls: { 'function' => 'get_delivery_date', 'parameters' => { 'order_id' => 'order_12345' } }, content: 'Function called' })
      end
    end

    context 'with a max_tokens parameter' do
      let(:max_tokens) { 30 }

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'sends the max_tokens parameter in the request' do
        described_class.create(messages: messages, max_tokens: max_tokens)

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
        described_class.create(messages: messages, json_schema: json_schema)

        expect(a_request(:post, Spectre::Openai::Completions::API_URL)
                 .with { |req| JSON.parse(req.body)['response_format']['json_schema'] == JSON.parse(json_schema.to_json) }).to have_been_made.once
      end
    end

    context 'when the response contains a refusal' do
      let(:refusal_response_body) do
        { choices: [{ message: { refusal: "I'm sorry, I cannot assist with that request." }, finish_reason: 'stop' }] }.to_json
      end

      before do
        stub_request(:post, Spectre::Openai::Completions::API_URL)
          .to_return(status: 200, body: refusal_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises a refusal error' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /Refusal: I'm sorry, I cannot assist with that request./)
      end
    end
  end
end
