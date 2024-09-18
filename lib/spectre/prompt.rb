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

      # Preprocess the locals before rendering the YAML file
      preprocessed_locals = preprocess_locals(locals)

      template_content = File.read(file_path)
      erb_template = ERB.new(template_content)

      context = Context.new(preprocessed_locals)
      rendered_prompt = erb_template.result(context.get_binding)

      # YAML.safe_load returns a hash, so fetch the correct part based on the prompt
      parsed_yaml = YAML.safe_load(rendered_prompt)[prompt]

      # Convert special characters back after YAML processing
      convert_special_chars_back(parsed_yaml)
    rescue Errno::ENOENT
      raise "Template file not found at path: #{file_path}"
    rescue Psych::SyntaxError => e
      raise "YAML Syntax Error in file #{file_path}: #{e.message}"
    rescue StandardError => e
      raise "Error rendering prompt for template '#{template}': #{e.message}"
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

    # Preprocess locals recursively to escape special characters in strings
    #
    # @param value [Object] The value to process (string, array, hash, etc.)
    # @return [Object] Processed value with special characters escaped
    def self.preprocess_locals(value)
      case value
      when String
        escape_special_chars(value)
      when Hash
        value.transform_values { |v| preprocess_locals(v) } # Recurse into hash values
      when Array
        value.map { |item| preprocess_locals(item) } # Recurse into array items
      else
        value
      end
    end

    # Escape special characters in strings to avoid YAML parsing issues
    #
    # @param value [String] The string to process
    # @return [String] The processed string with special characters escaped
    def self.escape_special_chars(value)
      value.gsub('&', '&amp;')
           .gsub('<', '&lt;')
           .gsub('>', '&gt;')
           .gsub('"', '&quot;')
           .gsub("'", '&#39;')
           .gsub("\n", '\\n')
           .gsub("\r", '\\r')
           .gsub("\t", '\\t')
    end

    # Convert special characters back to their original form after YAML processing
    #
    # @param value [String] The string to process
    # @return [String] The processed string with original special characters restored
    def self.convert_special_chars_back(value)
      value.gsub('&amp;', '&')
           .gsub('&lt;', '<')
           .gsub('&gt;', '>')
           .gsub('&quot;', '"')
           .gsub('&#39;', "'")
           .gsub('\\n', "\n")
           .gsub('\\r', "\r")
           .gsub('\\t', "\t")
    end

    # Helper class to handle the binding for ERB template rendering
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
