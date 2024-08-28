# frozen_string_literal: true

require "spectre/version"
require "spectre/embeddable"
require "spectre/openai"
require "spectre/logging"

module Spectre
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def spectre(*modules)
      modules.each do |mod|
        case mod
        when :embeddable
          include Spectre::Embeddable
        else
          raise ArgumentError, "Unknown spectre module: #{mod}"
        end
      end
    end
  end

  class << self
    attr_accessor :api_key

    def setup
      yield self
    end
  end
end