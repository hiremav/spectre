# frozen_string_literal: true

module Spectre
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_initializer_file
        template "spectre_initializer.rb", "config/initializers/spectre.rb"
      end
    end
  end
end
