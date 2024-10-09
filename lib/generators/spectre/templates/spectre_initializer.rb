# frozen_string_literal: true

require 'spectre'

Spectre.setup do |config|
  # Chose your LLM (openai, cohere, ollama)
  config.llm_provider = :openai
  # Set the API key for your chosen LLM
  config.api_key = ENV.fetch('CHATGPT_API_TOKEN')
  # Set the root directory for your project (optional)
  # config.root = File.expand_path('..', __dir__)
end
