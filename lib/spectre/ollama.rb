# frozen_string_literal: true

module Spectre
  module Ollama
    # Require each specific client file here
    require_relative 'ollama/embeddings'
    require_relative 'ollama/completions'
  end
end
