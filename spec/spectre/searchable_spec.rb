# frozen_string_literal: true

require 'spec_helper'
require 'support/test_model'

RSpec.describe Spectre::Searchable do
  before do
    TestModel.clear_all
    TestModel.create!(field1: 'What is AI?', field2: 'Artificial Intelligence')
    TestModel.create!(field1: 'Machine Learning', field2: 'AI in ML')

    Spectre.setup do |config|
      config.llm_provider = :openai
    end

    allow(Spectre::Openai::Embeddings).to receive(:generate).and_return([0.1, 0.2, 0.3])

    # Mock the aggregate method on the collection to simulate MongoDB's aggregation pipeline
    allow(TestModel.collection).to receive(:aggregate).and_return([
                                                                    { 'field1' => 'What is AI?', 'field2' => 'Artificial Intelligence', 'score' => 0.99 },
                                                                    { 'field1' => 'Machine Learning', 'field2' => 'AI in ML', 'score' => 0.95 }
                                                                  ])
  end

  describe '.vector_search' do
    context 'with default configuration' do
      it 'returns matching records with vectorSearchScore' do
        results = TestModel.vector_search('AI')
        expect(results).to be_an(Array)
        expect(results.size).to be > 0
        expect(results.first.keys).to include('field1', 'field2', 'score')
      end
    end

    context 'with custom result fields' do
      it 'returns only specified fields and vectorSearchScore' do
        custom_fields = { 'field2' => 1 }
        allow(TestModel.collection).to receive(:aggregate).and_return([
                                                                        { 'field2' => 'Artificial Intelligence', 'score' => 0.99 }
                                                                      ])

        results = TestModel.vector_search('AI', custom_result_fields: custom_fields)
        expect(results.first.keys).to include('field2', 'score')
        expect(results.first.keys).not_to include('field1')
      end
    end

    context 'with additional scopes' do
      it 'applies additional filtering to the search results' do
        additional_scopes = [{ "$match": { "field1": "Machine Learning" } }]
        allow(TestModel.collection).to receive(:aggregate).and_return([
                                                                        { 'field1' => 'Machine Learning', 'field2' => 'AI in ML', 'score' => 0.95 }
                                                                      ])

        results = TestModel.vector_search('AI', additional_scopes: additional_scopes)
        expect(results.size).to eq(1)
        expect(results.first['field1']).to eq('Machine Learning')
      end
    end

    context 'when query is already an embedding array' do
      it 'uses the provided embedding directly' do
        embedded_query = [0.1, 0.2, 0.3]

        # Ensure that the generate method is not called
        expect(Spectre::Openai::Embeddings).not_to receive(:generate)

        results = TestModel.vector_search(embedded_query)
        expect(results).to be_an(Array)
        expect(results.first.keys).to include('field1', 'field2', 'score')
      end
    end

    context 'when query is neither string nor array of floats' do
      it 'raises an ArgumentError' do
        expect {
          TestModel.vector_search(12345)
        }.to raise_error(ArgumentError, 'Query must be a String or an Array of Floats')
      end
    end
  end
end
