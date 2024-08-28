# frozen_string_literal: true

require_relative 'logging'
require_relative 'openai'

module Spectre
  module Embeddable
    include Spectre::Logging

    class NoEmbeddableFieldsError < StandardError; end
    class EmbeddingValidationError < StandardError; end

    def self.included(base)
      base.extend ClassMethods
    end

    # Converts the specified fields into a JSON representation suitable for embedding.
    #
    # @return [String] A JSON string representing the vectorized content of the specified fields.
    #
    # @raise [NoEmbeddableFieldsError] if no embeddable fields are defined in the model.
    #
    def as_vector
      raise NoEmbeddableFieldsError, "Embeddable fields are not defined" if self.class.embeddable_fields.empty?

      vector_data = self.class.embeddable_fields.map { |field| [field, send(field)] }.to_h
      vector_data.to_json
    end

    # Embeds the vectorized content and saves it to the specified fields.
    #
    # @param validation [Proc, nil] A validation block that returns true if the embedding should proceed.
    # @param embedding_field [Symbol] The field in which to store the generated embedding (default: :embedding).
    # @param timestamp_field [Symbol] The field in which to store the embedding timestamp (default: :embedded_at).
    #
    # @example
    #   embed!(validation: -> { !self.response.nil? }, embedding_field: :custom_embedding, timestamp_field: :custom_embedded_at)
    #
    # @raise [EmbeddingValidationError] if the validation block fails.
    #
    def embed!(validation: nil, embedding_field: :embedding, timestamp_field: :embedded_at)
      if validation && !instance_exec(&validation)
        raise EmbeddingValidationError, "Validation failed for embedding"
      end

      embedding_value = Spectre::Openai::Embeddings.generate(as_vector)
      send("#{embedding_field}=", embedding_value)
      send("#{timestamp_field}=", Time.now)
      save!
    end

    module ClassMethods
      include Spectre::Logging

      def embeddable_field(*fields)
        @embeddable_fields = fields
      end

      def embeddable_fields
        @embeddable_fields ||= []
      end

      # Embeds the vectorized content for all records that match the optional scope
      # and pass the validation check. Saves the embedding and timestamp to the specified fields.
      #
      # @param scope [Proc, nil] A scope or query to filter records (default: all records).
      # @param validation [Proc, nil] A validation block that returns true if the embedding should proceed for a record.
      # @param embedding_field [Symbol] The field in which to store the generated embedding (default: :embedding).
      # @param timestamp_field [Symbol] The field in which to store the embedding timestamp (default: :embedded_at).
      #
      # @example
      #   embed_all!(
      #     scope: -> { where(:response.exists => true) },
      #     validation: ->(record) { !record.response.nil? },
      #     embedding_field: :custom_embedding,
      #     timestamp_field: :custom_embedded_at
      #   )
      #
      def embed_all!(scope: nil, validation: nil, embedding_field: :embedding, timestamp_field: :embedded_at)
        records = scope ? instance_exec(&scope) : all

        records.each do |record|
          begin
            record.embed!(
              validation: validation,
              embedding_field: embedding_field,
              timestamp_field: timestamp_field
            )
          rescue EmbeddingValidationError => e
            log_error("Failed to embed record #{record.id}: #{e.message}")
          rescue => e
            log_error("Unexpected error embedding record #{record.id}: #{e.message}")
          end
        end
      end
    end
  end
end
