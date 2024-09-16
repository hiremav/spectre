# frozen_string_literal: true

require 'spectre'
require 'webmock/rspec'
require 'pry'

RSpec.configure do |config|
  WebMock.disable_net_connect!(allow_localhost: true)
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = "progress" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  config.before(:suite) do
    require 'pry'
  end
end
