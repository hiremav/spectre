# frozen_string_literal: true

module Spectre
  # Define custom error classes here
  class APIKeyNotConfiguredError < StandardError; end
  class HostNotConfiguredError < StandardError; end
end
