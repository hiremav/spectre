# frozen_string_literal: true

module Spectre
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_initializer_file
        template "spectre_initializer.rb", "config/initializers/spectre.rb"
      end

      desc "This generator creates system_prompt.yml.erb and user_prompt.yml.erb examples in your app/spectre/prompts folder."
      def create_prompt_files
        directory 'rag', 'app/spectre/prompts/rag'
      end
    end
  end
end
