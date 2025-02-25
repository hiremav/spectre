# <img src='logo.svg' height='120' alt='Spectre Logo' />

[![Gem Version](https://badge.fury.io/rb/spectre_ai.svg)](https://badge.fury.io/rb/spectre_ai)

**Spectre** is a Ruby gem that makes it easy to AI-enable your Ruby on Rails application. Currently, Spectre focuses on helping developers create embeddings, perform vector-based searches, create chat completions, and manage dynamic prompts — ideal for applications that are featuring RAG (Retrieval-Augmented Generation), chatbots and dynamic prompts.

## Compatibility

| Feature                 | Compatibility  |
|-------------------------|----------------|
| Foundation Models (LLM) | OpenAI, Ollama |
| Embeddings              | OpenAI, Ollama |
| Vector Searching        | MongoDB Atlas  |
| Prompt Templates        | ✅            |

**💡 Note:** We will first prioritize adding support for additional foundation models (Claude, Cohere, etc.), then look to add support for more vector databases (Pgvector, Pinecone, etc.). If you're looking for something a bit more extensible, we highly recommend checking out [langchainrb](https://github.com/patterns-ai-core/langchainrb).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'spectre_ai'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install spectre_ai
```

## Usage

### 🔧 Configuration

First, you’ll need to generate the initializer. Run the following command to create the initializer:

```bash
rails generate spectre:install
```

This will create a file at `config/initializers/spectre.rb`, where you can set your llm provider and configure the provider-specific settings.

```ruby
Spectre.setup do |config|
  config.default_llm_provider = :openai

  config.openai do |openai|
    openai.api_key = ENV['OPENAI_API_KEY']
  end

  config.ollama do |ollama|
    ollama.host = ENV['OLLAMA_HOST']
    ollama.api_key = ENV['OLLAMA_API_KEY']
  end
end
```

### 📡 Embeddings & Vector Search

#### For Embedding

To use Spectre for generating embeddings in your Rails model, follow these steps:

1. Include the Spectre module.
2. Declare the model as embeddable.
3. Define the embeddable fields.

Here is an example of how to set this up in a model:

```ruby
class Model
  include Mongoid::Document
  include Spectre

  spectre :embeddable
  embeddable_field :message, :response, :category
end
```

#### For Vector Searching (MongoDB Only)

**Note:** Currently, the `Searchable` module is designed to work exclusively with Mongoid models. If you attempt to include it in a non-Mongoid model, an error will be raised. This ensures that vector-based searches, which rely on MongoDB's specific features, are only used in appropriate contexts.

To enable vector-based search in your Rails model:

1. Include the Spectre module.
2. Declare the model as searchable.
3. Configure search parameters.

Use the following methods to configure the search path, index, and result fields:

- **configure_spectre_search_path:** The path where the embeddings are stored.
- **configure_spectre_search_index:** The index used for the vector search.
- **configure_spectre_result_fields:** The fields to include in the search results.

Here is an example of how to set this up in a model:

```ruby
class Model
  include Mongoid::Document
  include Spectre

  spectre :searchable
  configure_spectre_search_path 'embedding'
  configure_spectre_search_index 'vector_index'
  configure_spectre_result_fields({ "message" => 1, "response" => 1 })
end
```

### 3. Create Embeddings

**Create Embedding for a Single Record**

To create an embedding for a single record, you can call the `embed!` method on the instance record:

```ruby
record = Model.find(some_id)
record.embed!
```

This will create the embedding and store it in the specified embedding field, along with the timestamp in the `embedded_at` field.

**Create Embeddings for Multiple Records**

To create embeddings for multiple records at once, use the `embed_all!` method:

```ruby
Model.embed_all!(
  scope: -> { where(:response.exists => true, :response.ne => nil) },
  validation: ->(record) { !record.response.blank? }
)
```

This method will create embeddings for all records that match the given scope and validation criteria. The method will also print the number of successful and failed embeddings to the console.

**Directly Create Embeddings Using `Spectre.provider_module::Embeddings.create`**

If you need to create an embedding directly without using the model integration, you can use the `Spectre.provider_module::Embeddings.create` method. This can be useful if you want to create embeddings for custom text outside of your models. For example, with OpenAI:

```ruby
Spectre.provider_module::Embeddings.create("Your text here")
```

This method sends the text to OpenAI’s API and returns the embedding vector. You can optionally specify a different model by passing it as an argument:

```ruby
Spectre.provider_module::Embeddings.create("Your text here", model: "text-embedding-ada-002")
```

**NOTE:** Different providers have different available args for the `create` method. Please refer to the provider-specific documentation for more details.

### 4. Performing Vector-Based Searches

Once your model is configured as searchable, you can perform vector-based searches on the stored embeddings:

```ruby
Model.vector_search('Your search query', custom_result_fields: { "response" => 1 }, additional_scopes: [{ "$match" => { "category" => "science" } }])
```

This method will:

- **Embed the Search Query:** Uses the configured LLM provider to embed the search query.  
  **Note:** If your text is already embedded, you can pass the embedding (as an array), and it will perform just the search.

- **Perform Vector-Based Search:** Searches the embeddings stored in the specified `search_path`.

- **Return Matching Records:** Provides the matching records with the specified `result_fields` and their `vectorSearchScore`.

**Keyword Arguments:**

- **custom_result_fields:** Limit the fields returned in the search results.
- **additional_scopes:** Apply additional MongoDB filters to the search results.

### 💬 Chat Completions

Spectre provides an interface to create chat completions using your configured LLM provider, allowing you to create dynamic responses, messages, or other forms of text.

**Basic Completion Example**

To create a simple chat completion, use the `Spectre.provider_module::Completions.create` method. You can provide a user prompt and an optional system prompt to guide the response:

```ruby
messages = [
        { role: 'system', content: "You are a funny assistant." },
        { role: 'user', content: "Tell me a joke." }
]

Spectre.provider_module::Completions.create(messages: messages)
```

This sends the request to the LLM provider’s API and returns the chat completion.

**Customizing the Completion**

You can customize the behavior by specifying additional parameters such as the model, any tools needed for function calls:

```ruby
messages = [
        { role: 'system', content: "You are a funny assistant." },
        { role: 'user', content: "Tell me a joke." },
        { role: 'assistant', content: "Sure, here's a joke!" }
]

Spectre.provider_module::Completions.create(
        messages: messages,
        model: "gpt-4",
        openai: { max_tokens: 50 }
)

```

**Using a JSON Schema for Structured Output**

For cases where you need structured output (e.g., for returning specific fields or formatted responses), you can pass a `json_schema` parameter. The schema ensures that the completion conforms to a predefined structure:

```ruby
json_schema = {
  name: "completion_response",
  schema: {
    type: "object",
    properties: {
      response: { type: "string" },
      final_answer: { type: "string" }
    },
    required: ["response", "final_answer"],
    additionalProperties: false
  }
}

messages = [
  { role: 'system', content: "You are a knowledgeable assistant." },
  { role: 'user', content: "What is the capital of France?" }
]

Spectre.provider_module::Completions.create(
  messages: messages,
  json_schema: json_schema
)

```

This structured format guarantees that the response adheres to the schema you’ve provided, ensuring more predictable and controlled results.

**NOTE:** The JSON schema is different for each provider. OpenAI uses [JSON Schema](https://json-schema.org/overview/what-is-jsonschema.html), where you can specify the name of schema and schema itself. Ollama uses just plain JSON object. 
But you can provide OpenAI's schema to Ollama as well. We just convert it to Ollama's format.

⚙️ Function Calling (Tool Use)

You can incorporate tools (function calls) in your completion to handle more complex interactions such as fetching external information via API or performing calculations. Define tools using the function call format and include them in the request:

```ruby
tools = [
  {
    type: "function",
    function: {
      name: "get_delivery_date",
      description: "Get the delivery date for a customer's order.",
      parameters: {
        type: "object",
        properties: {
          order_id: { type: "string", description: "The customer's order ID." }
        },
        required: ["order_id"],
        additionalProperties: false
      }
    }
  }
]

messages = [
  { role: 'system', content: "You are a helpful customer support assistant." },
  { role: 'user', content: "Can you tell me the delivery date for my order?" }
]

Spectre.provider_module::Completions.create(
  messages: messages,
  tools: tools
)
```

This setup allows the model to call specific tools (or functions) based on the user's input. The model can then generate a tool call to get necessary information and integrate it into the conversation.

**Handling Responses from Completions with Tools**

When tools (function calls) are included in a completion request, the response might include `tool_calls` with relevant details for executing the function.

Here’s an example of how the response might look when a tool call is made:

```ruby
response = Spectre.provider_module::Completions.create(
  messages: messages,
  tools: tools
)

# Sample response structure when a tool call is triggered:
# {
#   :tool_calls=>[{
#     "id" => "call_gqvSz1JTDfUyky7ghqY1wMoy",
#     "type" => "function",
#     "function" => {
#       "name" => "get_lead_count",
#       "arguments" => "{\"account_id\":\"acc_12312\"}"
#     }
#   }],
#   :content => nil
# }

if response[:tool_calls]
  tool_call = response[:tool_calls].first

  # You can now perform the function using the provided data
  # For example, get the lead count by account_id
  account_id = JSON.parse(tool_call['function']['arguments'])['account_id']
  lead_count = get_lead_count(account_id) # Assuming you have a method for this

  # Respond back with the function result
  completion_response = Spectre.provider_module::Completions.create(
    messages: [
      { role: 'assistant', content: "There are #{lead_count} leads for account #{account_id}." }
    ]
  )
else
  puts "Model response: #{response[:content]}"
end
```

**NOTE:** Completions class also supports different `**args` for different providers. Please refer to the provider-specific documentation for more details.

### 🎭 Dynamic Prompt Rendering

Spectre provides a system for creating dynamic prompts based on templates. You can define reusable prompt templates and render them with different parameters in your Rails app (think Ruby on Rails view partials).

**Example Directory Structure for Prompts**

Create a folder structure in your app to hold the prompt templates:

```
app/spectre/prompts/
└── rag/
    ├── system.yml.erb
    └── user.yml.erb
```

Each `.yml.erb` file can contain dynamic content and be customized with embedded Ruby (ERB).

**Example Prompt Templates**

- **`system.yml.erb`:**

  ```yaml
  system: |
    You are a helpful assistant designed to provide answers based on specific documents and context provided to you.
    Follow these guidelines:
    1. Only provide answers based on the context provided.
    2. Be polite and concise.
  ```

- **`user.yml.erb`:**

  ```yaml
  user: |
    User's query: <%= @query %>
    Context: <%= @objects.join(", ") %>
  ```

**Rendering Prompts**

You can render prompts in your Rails application using the `Spectre::Prompt.render` method, which loads and renders the specified prompt template:

```ruby
# Render a system prompt
Spectre::Prompt.render(template: 'rag/system')

# Render a user prompt with local variables
Spectre::Prompt.render(
  template: 'rag/user',
  locals: {
    query: query,
    objects: objects
  }
)
```

- **`template`:** The path to the prompt template file (e.g., `rag/system`).
- **`locals`:** A hash of variables to be used inside the ERB template.

**Using Nested Templates for Prompts**

Spectre's `Prompt` class now supports rendering templates from nested directories. This allows you to better organize your prompt files in a structured folder hierarchy.

You can organize your prompt templates in subfolders. For instance, you can have the following structure:

```
app/
  spectre/
    prompts/
      rag/
        system.yml.erb
        user.yml.erb
      classification/
        intent/
          system.yml.erb
          user.yml.erb
        entity/
          system.yml.erb
          user.yml.erb
```

To render a prompt from a nested folder, simply pass the full path to the `template` argument:

```ruby
# Rendering from a nested folder
Spectre::Prompt.render(template: 'classification/intent/user', locals: { query: 'What is AI?' })
```

This allows for more flexibility when organizing your prompt files, particularly when dealing with complex scenarios or multiple prompt categories.

**Combining Completions with Prompts**

You can also combine completions and prompts like so:

```ruby
Spectre.provider_module::Completions.create(
  messages: [
    { role: 'system', content: Spectre::Prompt.render(template: 'rag/system') },
    { role: 'user', content: Spectre::Prompt.render(template: 'rag/user', locals: { query: @query, user: @user }) }
  ]
)

```

## 📜 Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/hiremav/spectre](https://github.com/hiremav/spectre). This project is intended to be a safe, welcoming space for collaboration, and your contributions are greatly appreciated!

1. **Fork** the repository.
2. **Create** a new feature branch (`git checkout -b my-new-feature`).
3. **Commit** your changes (`git commit -am 'Add some feature'`).
4. **Push** the branch (`git push origin my-new-feature`).
5. **Create** a pull request.

## 📜 License

This gem is available as open source under the terms of the MIT License.