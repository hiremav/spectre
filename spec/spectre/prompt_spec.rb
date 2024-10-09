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
        Context: <%= @objects.join(", ") %>
    ERB
  end

  before do
    # Create a temporary directory to hold the prompts
    @tmpdir = Dir.mktmpdir

    # Create the necessary folders and files for the test
    prompts_folder = File.join(@tmpdir, 'rag')
    FileUtils.mkdir_p(prompts_folder)

    # Write the mock system.yml.erb and user.yml.erb files
    File.write(File.join(prompts_folder, 'system.yml.erb'), system_prompt_content)
    File.write(File.join(prompts_folder, 'user.yml.erb'), user_prompt_content)

    # Temporarily set the prompts_path to the tmp directory
    allow(Spectre::Prompt).to receive(:prompts_path).and_return(@tmpdir)
  end

  after do
    # Clean up the temporary directory after the test
    FileUtils.remove_entry @tmpdir
  end

  describe '.render' do
    context 'when generating the system prompt' do
      it 'returns the rendered system prompt' do
        result = described_class.render(template: 'rag/system')
        expect(result).to eq("You are a helpful assistant.\n")
      end
    end

    context 'when generating the user prompt with locals' do
      let(:query) { 'What is AI?' }
      let(:objects) { ['AI is cool', 'AI is the future'] }

      it 'returns the rendered user prompt with local variables' do
        result = described_class.render(
          template: 'rag/user',
          locals: { query: query, objects: objects }
        )

        expected_result = "User's query: What is AI?\nContext: AI is cool, AI is the future\n"
        expect(result).to eq(expected_result)
      end
    end

    context 'when locals contain special characters' do
      let(:query) { 'What is <AI> & why is it important?' }
      let(:objects) { ['AI & ML', 'Future of AI'] }

      it 'escapes and restores special characters in the user prompt' do
        result = described_class.render(
          template: 'rag/user',
          locals: { query: query, objects: objects }
        )

        expected_result = "User's query: What is <AI> & why is it important?\nContext: AI & ML, Future of AI\n"
        expect(result).to eq(expected_result)
      end
    end

    context 'when the prompt file is not found' do
      it 'raises an error indicating the file is missing' do
        expect {
          described_class.render(template: 'nonexistent_template')
        }.to raise_error(RuntimeError, /Prompt file not found/)
      end
    end

    context 'when there is a YAML syntax error in the prompt file' do
      let(:invalid_yaml_content) do
        <<~ERB
      system: |
        You are a helpful assistant.
      This line should cause a YAML error because it is missing indentation or a key
    ERB
      end

      before do
        File.write(File.join(@tmpdir, 'rag/system.yml.erb'), invalid_yaml_content)
      end

      it 'raises a YAML syntax error' do
        expect {
          described_class.render(template: 'rag/system')
        }.to raise_error(RuntimeError, /YAML Syntax Error/)
      end
    end
  end
end
