# frozen_string_literal: true

require "spectre/version"
require "spectre/embeddable"
require 'spectre/searchable'
require "spectre/openai"
require "spectre/ollama"
require "spectre/logging"
require 'spectre/prompt'
require 'spectre/errors'

module Spectre
  VALID_LLM_PROVIDERS = {
    openai: Spectre::Openai,
    ollama: Spectre::Ollama
    # cohere: Spectre::Cohere,
  }.freeze

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def spectre(*modules)
      modules.each do |mod|
        case mod
        when :embeddable
          include Spectre::Embeddable
        when :searchable
          include Spectre::Searchable
        else
          raise ArgumentError, "Unknown spectre module: #{mod}"
        end
      end
    end
  end

  class Configuration
    attr_accessor :llm_provider, :providers

    def initialize
      @providers = {}
    end

    def openai
      @providers[:openai] ||= OpenaiConfiguration.new
      yield @providers[:openai] if block_given?
    end

    def ollama
      @providers[:ollama] ||= OllamaConfiguration.new
      yield @providers[:ollama] if block_given?
    end

    def provider_configuration
      providers[llm_provider] || raise("No configuration found for provider: #{llm_provider}")
    end
  end

  class OpenaiConfiguration
    attr_accessor :api_key
  end

  class OllamaConfiguration
    attr_accessor :host, :api_key
  end

  class << self
    attr_accessor :config

    def setup
      self.config ||= Configuration.new
      yield config
      validate_llm_provider!
    end

    def provider_module
      VALID_LLM_PROVIDERS[config.llm_provider] || raise("LLM provider #{config.llm_provider} not supported")
    end

    def provider_configuration
      config.provider_configuration
    end

    private

    def validate_llm_provider!
      unless VALID_LLM_PROVIDERS.keys.include?(config.llm_provider)
        raise ArgumentError, "Invalid llm_provider: #{config.llm_provider}. Must be one of: #{VALID_LLM_PROVIDERS.keys.join(', ')}"
      end
    end
  end
end
