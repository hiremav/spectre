# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'support/test_model'

RSpec.describe Spectre::Embeddable do
  before do
    TestModel.clear_all
    TestModel.embeddable_field :field1, :field2
    Spectre.setup do |config|
      config.llm_provider = :openai
    end
  end

  describe '#as_vector' do
    context 'when embeddable fields are defined' do
      it 'returns a JSON representation of the embeddable fields' do
        model = TestModel.new(field1: 'value1', field2: 'value2')
        expected_json = { 'field1' => 'value1', 'field2' => 'value2' }.to_json

        expect(model.as_vector).to eq(expected_json)
      end
    end

    context 'when no embeddable fields are defined' do
      it 'raises a NoEmbeddableFieldsError' do
        # Reset embeddable_fields to simulate a model without defined embeddable fields
        allow(TestModel).to receive(:embeddable_fields).and_return([])

        model = TestModel.new(field1: 'value1', field2: 'value2')

        expect { model.as_vector }.to raise_error(Spectre::Embeddable::NoEmbeddableFieldsError, 'Embeddable fields are not defined')
      end
    end
  end

  describe '#embed!' do
    before do
      allow(Spectre::Openai::Embeddings).to receive(:generate).and_return('embedded_value')
    end

    context 'when validation passes' do
      it 'embeds and saves the vectorized content' do
        model = TestModel.new(field1: 'value1', field2: 'value2')

        expect { model.embed! }.to change { model.embedding }.from(nil).to('embedded_value')
        expect(model.embedded_at).not_to be_nil
      end
    end

    context 'when validation fails' do
      it 'raises an EmbeddingValidationError' do
        model = TestModel.new(field1: 'value1', field2: 'value2')

        expect {
          model.embed!(validation: ->(model) { false })
        }.to raise_error(Spectre::Embeddable::EmbeddingValidationError, 'Validation failed for embedding')
      end
    end
  end

  describe '.embeddable_field' do
    it 'sets the embeddable fields for the class' do
      expect(TestModel.embeddable_fields).to eq([:field1, :field2])
    end
  end

  describe '.embed_all!' do
    before do
      allow(Spectre::Openai::Embeddings).to receive(:generate).and_return('embedded_value')
    end

    context 'for all records' do
      it 'embeds and saves the vectorized content' do
        TestModel.create!(field1: 'value1', field2: 'value2')
        TestModel.create!(field1: 'value3', field2: 'value4')

        expect(TestModel.all.size).to eq(2)

        TestModel.embed_all!(embedding_field: :embedding, timestamp_field: :embedded_at)

        TestModel.all.each do |record|
          expect(record.embedding).to eq('embedded_value')
          expect(record.embedded_at).not_to be_nil
        end
      end
    end

    context 'when errors occur during embedding' do
      it 'handles errors gracefully' do
        allow_any_instance_of(TestModel).to receive(:embed!).and_raise(Spectre::Embeddable::EmbeddingValidationError)

        TestModel.create!(field1: 'value1', field2: 'value2')

        expect {
          TestModel.embed_all!(embedding_field: :embedding, timestamp_field: :embedded_at)
        }.to_not raise_error
      end
    end
  end
end