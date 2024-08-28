# frozen_string_literal: true

require 'spectre'

class TestModel
  include Spectre

  spectre :embeddable

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
end