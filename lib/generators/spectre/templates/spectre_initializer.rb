# frozen_string_literal: true

require 'spectre'

Spectre.setup do |config|
  # Chose your LLM (openai, ollama, claude, gemini)
  config.default_llm_provider = :openai

  config.openai do |openai|
    openai.api_key = ENV['OPENAI_API_KEY']
  end

  config.ollama do |ollama|
    ollama.host = ENV['OLLAMA_HOST']
    ollama.api_key = ENV['OLLAMA_API_KEY']
  end

  config.claude do |claude|
    claude.api_key = ENV['ANTHROPIC_API_KEY']
  end

  config.gemini do |gemini|
    gemini.api_key = ENV['GEMINI_API_KEY']
  end
end
