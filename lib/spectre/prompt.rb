# frozen_string_literal: true

require 'erb'
require 'yaml'

module Spectre
  class Prompt
    class << self
      attr_reader :prompts_path

      def prompts_path
        @prompts_path ||= detect_prompts_path
      end

      # Render a prompt by reading and rendering the YAML template
      #
      # @param template [String] The path to the template file, formatted as 'folder1/folder2/prompt'
      # @param locals [Hash] Variables to be passed to the template for rendering
      #
      # @return [String] Rendered prompt
      def render(template:, locals: {})
        path, prompt = split_template(template)
        file_path = prompt_file_path(path, prompt)

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

      # Detects the appropriate path for prompt templates
      def detect_prompts_path
        # Find the first non-spectre, non-ruby core file in the call stack
        calling_file = caller.find do |path|
          !path.include?('/spectre/') && !path.include?(RbConfig::CONFIG['rubylibdir'])
        end

        # Determine the directory from where spectre was invoked
        start_dir = calling_file ? File.dirname(calling_file) : Dir.pwd

        # Traverse up until we find a Gemfile (or another marker of the project root)
        project_root = find_project_root(start_dir)

        # Return the prompts path based on the detected project root
        File.join(project_root, 'app', 'spectre', 'prompts')
      end

      def find_project_root(dir)
        while dir != '/' do
          # Check for Gemfile, .git directory, or config/application.rb (Rails)
          return dir if File.exist?(File.join(dir, 'Gemfile')) ||
            File.directory?(File.join(dir, '.git')) ||
            File.exist?(File.join(dir, 'config', 'application.rb'))

          # Move up one directory
          dir = File.expand_path('..', dir)
        end

        # Default fallback if no root markers are found
        Dir.pwd
      end

      # Split the template parameter into path and prompt
      #
      # @param template [String] Template path in the format 'folder1/folder2/prompt'
      # @return [Array<String, String>] An array containing the folder path and the prompt name
      def split_template(template)
        *path_parts, prompt = template.split('/')
        [File.join(path_parts), prompt]
      end

      # Build the path to the desired prompt file
      #
      # @param path [String] Path to the prompt folder(s)
      # @param prompt [String] Name of the prompt file (e.g., 'system', 'user')
      #
      # @return [String] Full path to the template file
      def prompt_file_path(path, prompt)
        File.join(prompts_path, path, "#{prompt}.yml.erb")
      end

      # Preprocess locals recursively to escape special characters in strings
      #
      # @param value [Object] The value to process (string, array, hash, etc.)
      # @return [Object] Processed value with special characters escaped
      def preprocess_locals(value)
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
      def escape_special_chars(value)
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
      def convert_special_chars_back(value)
        value.gsub('&amp;', '&')
             .gsub('&lt;', '<')
             .gsub('&gt;', '>')
             .gsub('&quot;', '"')
             .gsub('&#39;', "'")
             .gsub('\\n', "\n")
             .gsub('\\r', "\r")
             .gsub('\\t', "\t")
      end
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
