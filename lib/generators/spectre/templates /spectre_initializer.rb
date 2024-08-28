# frozen_string_literal: true

Spectre.setup do |config|
  # Set the API key for OpenAI
  config.api_key = ENV['CHATGPT_API_TOKEN']

  # Optionally set the log level (e.g., Logger::DEBUG, Logger::INFO)
  Spectre::Logging.logger.level = Logger::INFO
end
