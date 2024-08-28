# frozen_string_literal: true

require 'spec_helper'
require 'spectre'

RSpec.describe Spectre do
  describe '.setup' do
    it 'yields the configuration to the block' do
      yielded = false
      Spectre.setup do |config|
        yielded = true
      end
      expect(yielded).to be true
    end

    it 'allows setting the api_key' do
      api_key = 'test_api_key'
      Spectre.setup do |config|
        config.api_key = api_key
      end
      expect(Spectre.api_key).to eq(api_key)
    end
  end

  describe '.configuration' do
    it 'returns the current configuration' do
      Spectre.setup do |config|
        config.api_key = 'test_key'
      end
      expect(Spectre.api_key).to eq('test_key')
    end
  end

  describe '.version' do
    it 'returns the correct version' do
      expect(Spectre::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
