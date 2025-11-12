# frozen_string_literal: true

require "spectre/version"
require "spectre/embeddable"
require 'spectre/searchable'
require "spectre/openai"
require "spectre/ollama"
require "spectre/claude"
require "spectre/gemini"
require "spectre/openrouter"
require "spectre/logging"
require 'spectre/prompt'
require 'spectre/errors'

module Spectre
  VALID_LLM_PROVIDERS = {
    openai: Spectre::Openai,
    ollama: Spectre::Ollama,
    claude: Spectre::Claude,
    gemini: Spectre::Gemini,
    openrouter: Spectre::Openrouter
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
    attr_accessor :default_llm_provider, :providers

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

    def claude
      @providers[:claude] ||= ClaudeConfiguration.new
      yield @providers[:claude] if block_given?
    end

    def gemini
      @providers[:gemini] ||= GeminiConfiguration.new
      yield @providers[:gemini] if block_given?
    end

    def openrouter
      @providers[:openrouter] ||= OpenrouterConfiguration.new
      yield @providers[:openrouter] if block_given?
    end

    def provider_configuration
      providers[default_llm_provider] || raise("No configuration found for provider: #{default_llm_provider}")
    end
  end

  class OpenaiConfiguration
    attr_accessor :api_key
  end

  class OllamaConfiguration
    attr_accessor :host, :api_key
  end

  class ClaudeConfiguration
    attr_accessor :api_key
  end

  class GeminiConfiguration
    attr_accessor :api_key
  end

  class OpenrouterConfiguration
    # OpenRouter additionally recommends setting Referer and X-Title headers
    attr_accessor :api_key, :referer, :app_title
  end

  class << self
    attr_accessor :config

    def setup
      self.config ||= Configuration.new
      yield config
      validate_llm_provider!
    end

    def provider_module
      VALID_LLM_PROVIDERS[config.default_llm_provider] || raise("LLM provider #{config.default_llm_provider} not supported")
    end

    def provider_configuration
      config.provider_configuration
    end

    def openai_configuration
      config.providers[:openai]
    end

    def ollama_configuration
      config.providers[:ollama]
    end

    def claude_configuration
      config.providers[:claude]
    end

    def gemini_configuration
      config.providers[:gemini]
    end

    def openrouter_configuration
      config.providers[:openrouter]
    end

    private

    def validate_llm_provider!
      unless VALID_LLM_PROVIDERS.keys.include?(config.default_llm_provider)
        raise ArgumentError, "Invalid default_llm_provider: #{config.default_llm_provider}. Must be one of: #{VALID_LLM_PROVIDERS.keys.join(', ')}"
      end
    end
  end
end
