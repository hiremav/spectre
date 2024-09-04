# frozen_string_literal: true

require 'erb'
require 'yaml'

module Spectre
  class Prompt
    PROMPTS_PATH = File.join(Dir.pwd, 'app', 'spectre', 'prompts')

    # Generate a prompt by reading and rendering the YAML template
    #
    # @param name [String] Name of the folder containing the prompts (e.g., 'rag')
    # @param prompt [Symbol] The type of prompt (e.g., :system or :user)
    # @param locals [Hash] Variables to be passed to the template for rendering
    #
    # @return [String] Rendered prompt
    def self.generate(name:, prompt:, locals: {})
      file_path = prompt_file_path(name, prompt)

      raise "Prompt file not found: #{file_path}" unless File.exist?(file_path)

      template = File.read(file_path)
      erb_template = ERB.new(template)

      context = Context.new(locals)
      rendered_prompt = erb_template.result(context.get_binding)

      YAML.safe_load(rendered_prompt)[prompt.to_s]
    end

    private

    # Build the path to the desired prompt file
    #
    # @param name [String] Name of the prompt folder
    # @param prompt [Symbol] Type of prompt (e.g., :system, :user)
    #
    # @return [String] Full path to the template file
    def self.prompt_file_path(name, prompt)
      "#{PROMPTS_PATH}/#{name}/#{prompt}_prompt.yml.erb"
    end

    # Helper class to handle the binding for ERB rendering
    class Context
      def initialize(locals)
        locals.each do |key, value|
          instance_variable_set("@#{key}", value)
        end
      end

      # Returns binding for ERB template rendering
      def get_binding
        binding
      end
    end
  end
end
