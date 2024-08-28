# frozen_string_literal: true

require 'rails/generators'

module Spectre
  module Generators
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc "Creates a Spectre initializer file for configuring the gem"

      def create_initializer_file
        template "spectre_initializer.rb", "config/initializers/spectre.rb"
      end
    end
  end
end