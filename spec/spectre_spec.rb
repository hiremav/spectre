# frozen_string_literal: true

require 'spec_helper'
require 'spectre'

RSpec.describe Spectre do
  describe '.setup' do
    it 'yields the configuration to the block' do
      yielded = false
      Spectre.setup do |config|
        yielded = true
        config.llm_provider = :openai
      end
      expect(yielded).to be true
    end

    it 'allows setting the api_key and llm_provider' do
      api_key = 'test_api_key'
      llm_provider = :openai
      Spectre.setup do |config|
        config.api_key = api_key
        config.llm_provider = llm_provider
      end
      expect(Spectre.api_key).to eq(api_key)
      expect(Spectre.llm_provider).to eq(llm_provider)
    end

    it 'raises an error for an invalid llm_provider' do
      expect {
        Spectre.setup do |config|
          config.llm_provider = :invalid_provider
        end
      }.to raise_error(ArgumentError, "Invalid llm_provider: invalid_provider. Must be one of: openai")
    end
  end

  describe '.provider_module' do
    it 'returns the correct module for the :openai provider' do
      Spectre.setup do |config|
        config.llm_provider = :openai
      end
      expect(Spectre.provider_module).to eq(Spectre::Openai)
    end

    # it 'returns the correct module for the :cohere provider' do
    #   Spectre.setup do |config|
    #     config.llm_provider = :cohere
    #   end
    #   expect(Spectre.provider_module).to eq(Spectre::Cohere)
    # end
    #
    # it 'returns the correct module for the :ollama provider' do
    #   Spectre.setup do |config|
    #     config.llm_provider = :ollama
    #   end
    #   expect(Spectre.provider_module).to eq(Spectre::Ollama)
    # end

    it 'raises an error for an unsupported provider' do
      Spectre.setup do |config|
        config.llm_provider = :openai
      end

      allow(Spectre).to receive(:llm_provider).and_return(:unsupported_provider)

      expect {
        Spectre.provider_module
      }.to raise_error(RuntimeError, "LLM provider unsupported_provider not supported")
    end
  end

  describe '.configuration' do
    it 'returns the current configuration' do
      Spectre.setup do |config|
        config.api_key = 'test_key'
        config.llm_provider = :openai
      end
      expect(Spectre.api_key).to eq('test_key')
      expect(Spectre.llm_provider).to eq(:openai)
    end
  end

  describe '.version' do
    it 'returns the correct version' do
      expect(Spectre::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
