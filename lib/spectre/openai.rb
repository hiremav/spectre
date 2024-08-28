# frozen_string_literal: true

module Spectre
  module Openai
    # Require each specific client file here
    require_relative 'openai/embeddings'
    # require_relative 'openai/completions'
  end
end
