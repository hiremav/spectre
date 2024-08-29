# frozen_string_literal: true

require 'spectre'

class TestModel
  include Spectre

  spectre :embeddable, :searchable

  attr_accessor :id, :field1, :field2, :embedding, :embedded_at

  @@id_counter = 0

  def initialize(field1:, field2:)
    @id = (@@id_counter += 1) # Simple incremental ID
    @field1 = field1
    @field2 = field2
    @embedding = nil
    @embedded_at = nil
  end

  def save!
    # Simulate saving to a database
    true
  end

  def self.all
    @all ||= []
  end

  def self.create!(attributes)
    new_instance = new(**attributes)
    @all << new_instance
    new_instance
  end

  def self.clear_all
    @all = []
  end

  # Implement the `collection` method to return self (for mocking)
  def self.collection
    self
  end

  def self.aggregate(pipeline)
    # This will be mocked in the spec file
  end

  # Configure search path, index, and result fields
  configure_spectre_search_path 'embedding'
  configure_spectre_search_index 'vector_index'
  configure_spectre_result_fields({ "field1": 1, "field2": 1 })
end
