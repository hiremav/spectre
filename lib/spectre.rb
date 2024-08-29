# frozen_string_literal: true

require "spectre/version"
require "spectre/embeddable"
require 'spectre/searchable'
require "spectre/openai"
require "spectre/logging"

module Spectre
  VALID_LLM_PROVIDERS = {
    openai: Spectre::Openai,
    # cohere: Spectre::Cohere,
    # ollama: Spectre::Ollama
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

  class << self
    attr_accessor :api_key, :llm_provider

    def setup
      yield self
      validate_llm_provider!
    end

    def provider_module
      VALID_LLM_PROVIDERS[llm_provider] || raise("LLM provider #{llm_provider} not supported")
    end

    private

    def validate_llm_provider!
      unless VALID_LLM_PROVIDERS.keys.include?(llm_provider)
        raise ArgumentError, "Invalid llm_provider: #{llm_provider}. Must be one of: #{VALID_LLM_PROVIDERS.keys.join(', ')}"
      end
    end

  end
end
