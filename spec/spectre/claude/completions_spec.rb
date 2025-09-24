# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spectre::Claude::Completions do
  let(:api_key) { 'test_api_key' }
  let(:messages) do
    [
      { role: 'system', content: 'You are a helpful assistant.' },
      { role: 'user', content: 'Tell me a joke.' }
    ]
  end

  let(:completion_text) { 'Why did the scarecrow win an award? Because he was outstanding in his field!' }
  let(:success_response_body) do
    {
      content: [
        { type: 'text', text: completion_text }
      ],
      stop_reason: 'end_turn'
    }.to_json
  end

  before do
    Spectre.setup do |config|
      config.default_llm_provider = :claude
      config.claude do |claude|
        claude.api_key = api_key
      end
    end
  end

  describe '.create' do
    context 'when the API key is not configured' do
      before do
        Spectre.setup do |config|
          config.default_llm_provider = :claude
          config.claude do |claude|
            claude.api_key = nil
          end
        end
      end

      it 'raises an APIKeyNotConfiguredError' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(Spectre::APIKeyNotConfiguredError, 'API key is not configured')
      end
    end

    context 'when the request is successful' do
      before do
        stub_request(:post, Spectre::Claude::Completions::API_URL)
          .to_return(status: 200, body: success_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns the completion text' do
        result = described_class.create(messages: messages)
        expect(result).to eq({ content: completion_text })
      end
    end

    context 'when the API returns an error' do
      before do
        stub_request(:post, Spectre::Claude::Completions::API_URL)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an error with the API response' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /Claude API Error/)
      end
    end

    context 'when the response is not valid JSON' do
      before do
        stub_request(:post, Spectre::Claude::Completions::API_URL)
          .to_return(status: 200, body: 'Invalid JSON')
      end

      it 'raises a JSON Parse Error' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /JSON Parse Error/)
      end
    end

    context 'when the response stop_reason is max_tokens' do
      let(:incomplete_response_body) do
        {
          content: [ { type: 'text', text: completion_text } ],
          stop_reason: 'max_tokens'
        }.to_json
      end

      before do
        stub_request(:post, Spectre::Claude::Completions::API_URL)
          .to_return(status: 200, body: incomplete_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises an incomplete response error' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(RuntimeError, /Incomplete response: The completion was cut off due to token limit./)
      end
    end

    context 'when the response stop_reason is refusal' do
      let(:refusal_response_body) do
        {
          content: [ { type: 'text', text: '' } ],
          stop_reason: 'refusal'
        }.to_json
      end

      before do
        stub_request(:post, Spectre::Claude::Completions::API_URL)
          .to_return(status: 200, body: refusal_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises a refusal error' do
        expect {
          described_class.create(messages: messages)
        }.to raise_error(Spectre::Claude::RefusalError, /Content filtered: The model's output was blocked due to policy violations./)
      end
    end

    context 'when the response contains a tool_use and no json_schema was provided' do
      let(:tool_use_response_body) do
        {
          content: [
            { type: 'tool_use', id: 'tool_1', name: 'get_info', input: { query: 'something' } },
            { type: 'text', text: 'Calling tool' }
          ],
          stop_reason: 'tool_use'
        }.to_json
      end

      before do
        stub_request(:post, Spectre::Claude::Completions::API_URL)
          .to_return(status: 200, body: tool_use_response_body, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns tool_calls and text content' do
        result = described_class.create(messages: messages)
        parsed = JSON.parse(tool_use_response_body)
        expect(result).to eq({
          tool_calls: parsed['content'].select { |b| b['type'] == 'tool_use' },
          content: 'Calling tool'
        })
      end
    end

    context 'with a json_schema parameter' do
      let(:json_schema) do
        { name: 'completion_response', schema: { type: 'object', properties: { response: { type: 'string' } }, required: ['response'] } }
      end

      context 'request formation' do
        before do
          stub_request(:post, Spectre::Claude::Completions::API_URL)
            .to_return(status: 200, body: success_response_body, headers: { 'Content-Type' => 'application/json' })
        end

        it 'converts json_schema to a tool with input_schema and forces tool_choice by default' do
          described_class.create(messages: messages, json_schema: json_schema)

          expect(a_request(:post, Spectre::Claude::Completions::API_URL)
            .with { |req|
              body = JSON.parse(req.body)
              schema_tool = body['tools']&.first
              body['tool_choice'] == { 'type' => 'tool', 'name' => json_schema[:name] } &&
                schema_tool && schema_tool['name'] == json_schema[:name] &&
                schema_tool['input_schema'] == JSON.parse(json_schema[:schema].to_json)
            }).to have_been_made.once
        end

        it 'does not override an explicit tool_choice' do
          described_class.create(messages: messages, json_schema: json_schema, tool_choice: { type: 'auto' })

          expect(a_request(:post, Spectre::Claude::Completions::API_URL)
            .with { |req| JSON.parse(req.body)['tool_choice'] == { 'type' => 'auto' } }).to have_been_made.once
        end

        it 'includes user-provided tools along with the schema tool' do
          tools = [{ name: 'other_tool', description: 'Other', input_schema: { type: 'object', properties: {}, additionalProperties: false } }]
          described_class.create(messages: messages, json_schema: json_schema, tools: tools)

          expect(a_request(:post, Spectre::Claude::Completions::API_URL)
            .with { |req|
              body = JSON.parse(req.body)
              body['tools'].is_a?(Array) && body['tools'].any? { |t| t['name'] == 'other_tool' } && body['tools'].any? { |t| t['name'] == json_schema[:name] }
            }).to have_been_made.once
        end

        it 'sends the claude max_tokens parameter when provided' do
          described_class.create(messages: messages, json_schema: json_schema, claude: { max_tokens: 77 })
          expect(a_request(:post, Spectre::Claude::Completions::API_URL)
            .with(body: hash_including(max_tokens: 77))).to have_been_made
        end
      end

      context 'response normalization' do
        let(:schema_tool_name) { json_schema[:name] }
        let(:tool_only_response_body) do
          {
            content: [
              { type: 'tool_use', id: 'tool_u', name: schema_tool_name, input: { response: 'OK' } }
            ],
            stop_reason: 'tool_use'
          }.to_json
        end

        before do
          stub_request(:post, Spectre::Claude::Completions::API_URL)
            .to_return(status: 200, body: tool_only_response_body, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns the parsed tool input in :content (not a JSON string)' do
          result = described_class.create(messages: messages, json_schema: json_schema)
          expect(result).to eq({ content: { 'response' => 'OK' } })
        end
      end
    end
  end
end
