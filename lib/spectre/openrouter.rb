# frozen_string_literal: true

module Spectre
  module Openrouter
    # Require each specific client file here
    require_relative 'openrouter/embeddings'
    require_relative 'openrouter/completions'
  end
end
