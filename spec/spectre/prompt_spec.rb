# frozen_string_literal: true

require 'spec_helper'
require 'spectre/prompt'
require 'tmpdir'

RSpec.describe Spectre::Prompt do
  let(:system_prompt_content) do
    <<~ERB
      system: |
        You are a helpful assistant.
    ERB
  end

  let(:user_prompt_content) do
    <<~ERB
      user: |
        User's query: <%= @query %>
        Context: <%= @cognitive_responses_in_context.join(", ") %>
    ERB
  end

  before do
    # Create a temporary directory to hold the prompts
    @tmpdir = Dir.mktmpdir

    # Create the necessary folders and files for the test
    prompts_folder = File.join(@tmpdir, 'rag')
    FileUtils.mkdir_p(prompts_folder)

    # Write the mock system_prompt.yml.erb and user_prompt.yml.erb files
    File.write(File.join(prompts_folder, 'system_prompt.yml.erb'), system_prompt_content)
    File.write(File.join(prompts_folder, 'user_prompt.yml.erb'), user_prompt_content)

    # Temporarily set the PROMPTS_PATH to the tmp directory
    stub_const('Spectre::Prompt::PROMPTS_PATH', @tmpdir)
  end

  after do
    # Clean up the temporary directory after the test
    FileUtils.remove_entry @tmpdir
  end

  describe '.generate' do
    context 'when generating the system prompt' do
      it 'returns the rendered system prompt' do
        result = described_class.generate(name: 'rag', prompt: :system)

        expect(result).to eq("You are a helpful assistant.\n")
      end
    end

    context 'when generating the user prompt with locals' do
      let(:query) { 'What is AI?' }
      let(:cognitive_responses_in_context) { ['AI is cool', 'AI is the future'] }

      it 'returns the rendered user prompt with local variables' do
        result = described_class.generate(
          name: 'rag',
          prompt: :user,
          locals: { query: query, cognitive_responses_in_context: cognitive_responses_in_context }
        )
        expected_result = "User's query: What is AI?\nContext: AI is cool, AI is the future\n"
        expect(result).to eq(expected_result)
      end
    end
  end
end
