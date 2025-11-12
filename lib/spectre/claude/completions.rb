# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Spectre
  module Claude
    class RefusalError < StandardError; end

    class Completions
      API_URL = 'https://api.anthropic.com/v1/messages'
      DEFAULT_MODEL = 'claude-opus-4-1'
      DEFAULT_TIMEOUT = 60
      ANTHROPIC_VERSION = '2023-06-01'

      # Class method to generate a completion based on user messages and optional tools
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions, defaults to DEFAULT_MODEL
      # @param json_schema [Hash, nil] Optional JSON Schema; when provided, it will be converted into a tool with input_schema and forced via tool_choice unless overridden
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @param tool_choice [Hash, nil] Optional tool_choice to force a specific tool use (e.g., { type: 'tool', name: 'record_summary' })
      # @param args [Hash, nil] optional arguments like read_timeout and open_timeout. Provide max_tokens at the top level only.
      # @return [Hash] The parsed response including any tool calls or content
      # @raise [APIKeyNotConfiguredError] If the API key is not set
      # @raise [RuntimeError] For general API errors or unexpected issues
      def self.create(messages:, model: DEFAULT_MODEL, json_schema: nil, tools: nil, tool_choice: nil, **args)
        api_key = Spectre.claude_configuration&.api_key
        raise APIKeyNotConfiguredError, "API key is not configured" unless api_key

        validate_messages!(messages)

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = args.fetch(:read_timeout, DEFAULT_TIMEOUT)
        http.open_timeout = args.fetch(:open_timeout, DEFAULT_TIMEOUT)

        request = Net::HTTP::Post.new(uri.path, {
          'Content-Type' => 'application/json',
          'x-api-key' => api_key,
          'anthropic-version' => ANTHROPIC_VERSION
        })

        max_tokens = args[:max_tokens] || 1024
        request.body = generate_body(messages, model, json_schema, max_tokens, tools, tool_choice).to_json
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "Claude API Error: #{response.code} - #{response.message}: #{response.body}"
        end

        parsed_response = JSON.parse(response.body)

        handle_response(parsed_response, schema_used: !!json_schema)
      rescue JSON::ParserError => e
        raise "JSON Parse Error: #{e.message}"
      end

      private

      # Validate the structure and content of the messages array.
      #
      # @param messages [Array<Hash>] The array of message hashes to validate.
      #
      # @raise [ArgumentError] if the messages array is not in the expected format or contains invalid data.
      def self.validate_messages!(messages)
        unless messages.is_a?(Array) && messages.all? { |msg| msg.is_a?(Hash) }
          raise ArgumentError, "Messages must be an array of message hashes."
        end

        if messages.empty?
          raise ArgumentError, "Messages cannot be empty."
        end
      end

      # Helper method to generate the request body for Anthropic Messages API
      #
      # @param messages [Array<Hash>] The conversation messages, each with a role and content
      # @param model [String] The model to be used for generating completions
      # @param json_schema [Hash, nil] An optional JSON schema to hint structured output
      # @param max_tokens [Integer] The maximum number of tokens for the completion
      # @param tools [Array<Hash>, nil] An optional array of tool definitions for function calling
      # @return [Hash] The body for the API request
      def self.generate_body(messages, model, json_schema, max_tokens, tools, tool_choice)
        system_prompts, chat_messages = partition_system_and_chat(messages)

        body = {
          model: model,
          max_tokens: max_tokens,
          messages: chat_messages
        }

        # Join multiple system prompts into one. Anthropic supports a string here.
        body[:system] = system_prompts.join("\n\n") unless system_prompts.empty?

        # If a json_schema is provided, transform it into a "virtual" tool and force its use via tool_choice (unless already provided).
        if json_schema
          # Normalize schema input: accept anthropic-style { json_schema: { name:, schema:, strict: } },
          # OpenAI-like { name:, schema:, strict: }, or a raw schema object.
          if json_schema.is_a?(Hash) && (json_schema.key?(:json_schema) || json_schema.key?("json_schema"))
            schema_payload = json_schema[:json_schema] || json_schema["json_schema"]
            schema_name = (schema_payload[:name] || schema_payload["name"] || "structured_output").to_s
            schema_object = schema_payload[:schema] || schema_payload["schema"] || schema_payload
          else
            schema_name = (json_schema.is_a?(Hash) && (json_schema[:name] || json_schema["name"])) || "structured_output"
            schema_object = (json_schema.is_a?(Hash) && (json_schema[:schema] || json_schema["schema"])) || json_schema
          end

          schema_tool = {
            name: schema_name,
            description: "Return a JSON object that strictly follows the provided input_schema.",
            input_schema: schema_object
          }

          # Merge with any user-provided tools. Prefer a single tool by default but don't drop existing tools.
          existing_tools = tools || []
          body[:tools] = [schema_tool] + existing_tools

          # If the caller didn't specify tool_choice, force using the schema tool.
          body[:tool_choice] = { type: 'tool', name: schema_name } unless tool_choice
        end

        body[:tools] = tools if tools && !body.key?(:tools)
        body[:tool_choice] = tool_choice if tool_choice

        body
      end

      # Normalize content for Anthropic: preserve arrays/hashes (structured blocks), stringify otherwise
      def self.normalize_content(content)
        case content
        when Array
          content
        when Hash
          content
        else
          content.to_s
        end
      end

      # Partition system messages and convert remaining into Anthropic-compatible messages
      def self.partition_system_and_chat(messages)
        system_prompts = []
        chat_messages = []

        messages.each do |msg|
          role = (msg[:role] || msg['role']).to_s
          content = msg[:content] || msg['content']

          case role
          when 'system'
            system_prompts << content.to_s
          when 'user', 'assistant'
            chat_messages << { role: role, content: normalize_content(content) }
          else
            # Unknown role, treat as user to avoid API errors
            chat_messages << { role: 'user', content: normalize_content(content) }
          end
        end

        [system_prompts, chat_messages]
      end

      # Handles the API response, raising errors for specific cases and returning structured content otherwise
      #
      # @param response [Hash] The parsed API response
      # @param schema_used [Boolean] Whether the request used a JSON schema (tools-based) and needs normalization
      # @return [Hash] The relevant data based on the stop_reason
      def self.handle_response(response, schema_used: false)
        content_blocks = response['content'] || []
        stop_reason = response['stop_reason']

        text_content = content_blocks.select { |b| b['type'] == 'text' }.map { |b| b['text'] }.join
        tool_uses = content_blocks.select { |b| b['type'] == 'tool_use' }

        if stop_reason == 'max_tokens'
          raise "Incomplete response: The completion was cut off due to token limit."
        end

        if stop_reason == 'refusal'
          raise RefusalError, "Content filtered: The model's output was blocked due to policy violations."
        end

        # If a json_schema was provided and Claude produced a single tool_use with no text,
        # treat it as structured JSON output and return the parsed object in :content.
        if schema_used && tool_uses.length == 1 && (text_content.nil? || text_content.strip.empty?)
          input = tool_uses.first['input']
          return({ content: input }) if input.is_a?(Hash) || input.is_a?(Array)
        end

        if !tool_uses.empty?
          return { tool_calls: tool_uses, content: text_content }
        end

        # Normal end of turn
        if stop_reason == 'end_turn' || stop_reason.nil?
          return { content: text_content }
        end

        # Handle unexpected stop reasons
        raise "Unexpected stop_reason: #{stop_reason}"
      end
    end
  end
end
