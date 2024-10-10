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

  let(:nested_prompt_content) do
    <<~ERB
      nested: |
        Nested context for <%= @query %>
    ERB
  end

  let(:invalid_yaml_content) do
    <<~ERB
      system: |
        You are a helpful assistant.
      This line should cause a YAML error because it is missing indentation or a key
    ERB
  end

  before do
    # Create a temporary directory to hold the prompts
    @tmpdir = Dir.mktmpdir

    # Create the necessary folders and files for the test
    prompts_folder = File.join(@tmpdir, 'rag')
    nested_folder = File.join(@tmpdir, 'nested/folder')
    FileUtils.mkdir_p(prompts_folder)
    FileUtils.mkdir_p(nested_folder)

    # Write the mock system.yml.erb, user.yml.erb, and nested.yml.erb files
    File.write(File.join(prompts_folder, 'system.yml.erb'), system_prompt_content)
    File.write(File.join(prompts_folder, 'user.yml.erb'), user_prompt_content)
    File.write(File.join(nested_folder, 'nested.yml.erb'), nested_prompt_content)

    # Temporarily set the prompts_path to the tmp directory
    allow(Spectre::Prompt).to receive(:prompts_path).and_return(@tmpdir)
  end

  after do
    # Clean up the temporary directory after the test
    FileUtils.remove_entry @tmpdir
  end

  describe '.render' do
    subject { described_class.render(template: template, locals: locals) }

    let(:locals) { {} }
    let(:template) { 'rag/system' }

    context 'when generating the system prompt' do
      it 'returns the rendered system prompt' do
        expect(subject).to eq("You are a helpful assistant.\n")
      end
    end

    context 'when generating the user prompt with locals' do
      let(:template) { 'rag/user' }
      let(:locals) { { query: 'What is AI?', objects: ['AI is cool', 'AI is the future'] } }

      it 'returns the rendered user prompt with local variables' do
        expected_result = "User's query: What is AI?\nContext: AI is cool, AI is the future\n"
        expect(subject).to eq(expected_result)
      end
    end

    context 'when locals contain special characters' do
      let(:template) { 'rag/user' }
      let(:locals) { { query: 'What is <AI> & why is it important?', objects: ['AI & ML', 'Future of AI'] } }

      it 'escapes and restores special characters in the user prompt' do
        expected_result = "User's query: What is <AI> & why is it important?\nContext: AI & ML, Future of AI\n"
        expect(subject).to eq(expected_result)
      end
    end

    context 'when the prompt file is not found' do
      let(:template) { 'nonexistent_template' }

      it 'raises an error indicating the file is missing' do
        expect { subject }.to raise_error(RuntimeError, /Prompt file not found/)
      end
    end

    context 'when there is a YAML syntax error in the prompt file' do
      before do
        File.write(File.join(@tmpdir, 'rag/system.yml.erb'), invalid_yaml_content)
      end

      it 'raises a YAML syntax error' do
        expect { subject }.to raise_error(RuntimeError, /YAML Syntax Error/)
      end
    end

    context 'when generating a nested prompt' do
      let(:template) { 'nested/folder/nested' }
      let(:locals) { { query: 'What is AI?' } }

      it 'returns the rendered nested prompt' do
        expected_result = "Nested context for What is AI?\n"
        expect(subject).to eq(expected_result)
      end
    end
  end
end
