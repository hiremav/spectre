# frozen_string_literal: true

module Spectre
  module Searchable
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      # Configure the path to the embedding field for the vector search.
      #
      # @param path [String] The path to the embedding field.
      def configure_spectre_search_path(path)
        @search_path = path
      end

      # Configure the index to be used for the vector search.
      #
      # @param index [String] The name of the vector index.
      def configure_spectre_search_index(index)
        @search_index = index
      end

      # Configure the default fields to include in the search results.
      #
      # @param fields [Hash] The fields to include in the results, with their MongoDB projection configuration.
      def configure_spectre_result_fields(fields)
        @result_fields = fields
      end

      # Provide access to the configured search path.
      #
      # @return [String] The configured search path.
      def search_path
        @search_path || 'embedding'  # Default to 'embedding' if not configured
      end

      # Provide access to the configured search index.
      #
      # @return [String] The configured search index.
      def search_index
        @search_index || 'vector_index'  # Default to 'vector_index' if not configured
      end

      # Provide access to the configured result fields.
      #
      # @return [Hash, nil] The configured result fields, or nil if not configured.
      def result_fields
        @result_fields
      end

      # Searches based on a query string by first embedding the query.
      #
      # @param query [String] The text query to embed and search for.
      # @param limit [Integer] The maximum number of results to return (default: 5).
      # @param additional_scopes [Array<Hash>] Additional MongoDB aggregation stages to filter or modify results.
      # @param custom_result_fields [Hash, nil] Custom fields to include in the search results, overriding the default.
      #
      # @return [Array<Hash>] The search results, including the configured fields and score.
      #
      # @example Basic search with configured result fields
      #   results = CognitiveResponse.search("What is AI?")
      #
      # @example Search with custom result fields
      #   results = CognitiveResponse.search(
      #     "What is AI?",
      #     limit: 10,
      #     custom_result_fields: { "some_additional_field": 1, "another_field": 1 }
      #   )
      #
      # @example Search with additional filtering using scopes
      #   results = CognitiveResponse.search(
      #     "What is AI?",
      #     limit: 10,
      #     additional_scopes: [{ "$match": { "some_field": "some_value" } }]
      #   )
      #
      # @example Combining custom result fields and additional scopes
      #   results = CognitiveResponse.search(
      #     "What is AI?",
      #     limit: 10,
      #     additional_scopes: [{ "$match": { "some_field": "some_value" } }],
      #     custom_result_fields: { "some_additional_field": 1, "another_field": 1 }
      #   )
      #
      def search(query, limit: 5, additional_scopes: [], custom_result_fields: nil)
        # Generate the embedding for the query string
        embedded_query = Spectre.provider_module::Embeddings.generate(query)

        # Build the MongoDB aggregation pipeline
        pipeline = [
          {
            "$vectorSearch": {
              "queryVector": embedded_query,
              "path": search_path,
              "numCandidates": 100,
              "limit": limit,
              "index": search_index
            }
          }
        ]

        # Add any additional scopes provided
        pipeline.concat(additional_scopes) if additional_scopes.any?

        # Determine the fields to include in the results
        fields_to_project = custom_result_fields || result_fields || {}
        fields_to_project["score"] = { "$meta": "vectorSearchScore" }

        # Add the project stage with the fields to project
        pipeline << { "$project": fields_to_project }

        self.collection.aggregate(pipeline).to_a
      end
    end
  end
end
