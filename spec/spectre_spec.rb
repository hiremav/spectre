# frozen_string_literal: true

require 'spec_helper'
require 'spectre'

RSpec.describe Spectre do
  let(:openai_api_key) { 'test_openai_api_key' }
  let(:ollama_host) { 'http://ollama.local' }
  let(:ollama_api_key) { 'test_ollama_api_key' }

  shared_context 'configured openai provider' do
    before do
      Spectre.setup do |config|
        config.default_llm_provider = :openai
        config.openai do |openai|
          openai.api_key = openai_api_key
        end
      end
    end
  end

  shared_context 'configured ollama provider' do
    before do
      Spectre.setup do |config|
        config.default_llm_provider = :ollama
        config.ollama do |ollama|
          ollama.host = ollama_host
          ollama.api_key = ollama_api_key
        end
      end
    end
  end

  describe '.setup' do
    it 'yields the configuration to the block' do
      yielded = false
      Spectre.setup do |config|
        yielded = true
        config.default_llm_provider = :openai
      end
      expect(yielded).to be true
    end

    it 'allows setting the default_llm_provider and provider-specific configurations' do
      Spectre.setup do |config|
        config.default_llm_provider = :openai
        config.openai { |openai| openai.api_key = openai_api_key }
        config.ollama { |ollama| ollama.host = ollama_host }
      end

      expect(Spectre.config.default_llm_provider).to eq(:openai)
      expect(Spectre.config.providers[:openai].api_key).to eq(openai_api_key)
      expect(Spectre.config.providers[:ollama].host).to eq(ollama_host)
    end

    it 'raises an error for an invalid default_llm_provider' do
      expect {
        Spectre.setup do |config|
          config.default_llm_provider = :invalid_provider
        end
      }.to raise_error(ArgumentError, /Invalid default_llm_provider: invalid_provider/)
    end
  end

  describe '.provider_module' do
    include_context 'configured openai provider'

    it 'returns the correct module for the :openai provider' do
      expect(Spectre.provider_module).to eq(Spectre::Openai)
    end

    it 'raises an error for an unsupported provider' do
      allow(Spectre).to receive(:config).and_return(double(default_llm_provider: :unsupported_provider))

      expect {
        Spectre.provider_module
      }.to raise_error(RuntimeError, /LLM provider unsupported_provider not supported/)
    end
  end

  describe '.configuration' do
    include_context 'configured openai provider'

    it 'returns the current configuration' do
      expect(Spectre.config.default_llm_provider).to eq(:openai)
      expect(Spectre.config.providers[:openai].api_key).to eq(openai_api_key)
    end
  end

  describe 'nested provider configurations' do
    context 'when configuring OpenAI' do
      include_context 'configured openai provider'

      it 'allows setting OpenAI-specific configurations' do
        expect(Spectre.config.providers[:openai].api_key).to eq(openai_api_key)
      end
    end

    context 'when configuring Ollama' do
      include_context 'configured ollama provider'

      it 'allows setting Ollama-specific configurations' do
        expect(Spectre.config.providers[:ollama].host).to eq(ollama_host)
        expect(Spectre.config.providers[:ollama].api_key).to eq(ollama_api_key)
      end
    end
  end

  describe '.version' do
    it 'returns the correct version' do
      expect(Spectre::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe '.provider_configuration' do
    context 'when the current provider is :openai' do
      include_context 'configured openai provider'

      it 'returns the configuration for the Openai provider' do
        provider_config = Spectre.provider_configuration
        expect(provider_config).to be_a(Spectre::OpenaiConfiguration)
        expect(provider_config.api_key).to eq(openai_api_key)
      end
    end

    context 'when the current provider is :ollama' do
      include_context 'configured ollama provider'

      it 'returns the configuration for the Ollama provider' do
        provider_config = Spectre.provider_configuration
        expect(provider_config).to be_a(Spectre::OllamaConfiguration)
        expect(provider_config.host).to eq(ollama_host)
        expect(provider_config.api_key).to eq(ollama_api_key)
      end
    end

    context 'when no configuration exists for the current provider' do
      before do
        Spectre.setup do |config|
          config.default_llm_provider = :openai
        end
        Spectre.config.providers.delete(:openai) # Simulate missing configuration
      end

      it 'raises an error' do
        expect {
          Spectre.provider_configuration
        }.to raise_error(RuntimeError, /No configuration found for provider: openai/)
      end
    end
  end
end
