# frozen_string_literal: true

Spectre.setup do |config|
  # Set the API key for OpenAI
  config.api_key = ENV.fetch('CHATGPT_API_TOKEN')
end
