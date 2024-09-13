# frozen_string_literal: true

require 'erb'
require 'yaml'

module Spectre
  class Prompt
    PROMPTS_PATH = File.join(Dir.pwd, 'app', 'spectre', 'prompts')

    # Render a prompt by reading and rendering the YAML template
    #
    # @param template [String] The path to the template file, formatted as 'type/prompt' (e.g., 'rag/system')
    # @param locals [Hash] Variables to be passed to the template for rendering
    #
    # @return [String] Rendered prompt
    def self.render(template:, locals: {})
      type, prompt = split_template(template)
      file_path = prompt_file_path(type, prompt)

      raise "Prompt file not found: #{file_path}" unless File.exist?(file_path)

      template_content = File.read(file_path)
      erb_template = ERB.new(template_content)

      context = Context.new(locals)
      rendered_prompt = erb_template.result(context.get_binding)

      YAML.safe_load(rendered_prompt)[prompt]
    end

    private

    # Split the template parameter into type and prompt
    #
    # @param template [String] Template path in the format 'type/prompt' (e.g., 'rag/system')
    # @return [Array<String, String>] An array containing the type and prompt
    def self.split_template(template)
      template.split('/')
    end

    # Build the path to the desired prompt file
    #
    # @param type [String] Name of the prompt folder
    # @param prompt [String] Type of prompt (e.g., 'system', 'user')
    #
    # @return [String] Full path to the template file
    def self.prompt_file_path(type, prompt)
      "#{PROMPTS_PATH}/#{type}/#{prompt}.yml.erb"
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
