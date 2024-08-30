# Spectre

**Spectre** is a Ruby gem designed to provide an abstraction layer for generating embeddings using OpenAI's API and for performing vector-based searches. This gem simplifies the process of embedding data fields and searching within your Rails models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'spectre'
```
And then execute:
```bash
bundle install
```
Or install it yourself as:
```bash
gem install spectre
```
## Usage

### 1. Setup

First, you’ll need to generate the initializer to configure your OpenAI API key. Run the following command to create the initializer:
```bash
rails generate spectre:install
```
This will create a file at config/initializers/spectre.rb, where you can set your OpenAI API key:
```ruby
Spectre.setup do |config|
  config.api_key = 'your_openai_api_key'
  config.llm_provider = :openai # Options: :openai
end
```
### 2. Integrate Spectre with Your Model

**2.1. Embeddable Module**

To use Spectre for generating embeddings in your Rails model, follow these steps:

1.	Include the Spectre module:
Include Spectre in your model to enable the spectre method.
2.	Declare the Model as Embeddable:
Use the spectre :embeddable declaration to make the model embeddable.
3.	Define the Embeddable Fields:
Use the embeddable_field method to specify which fields should be used to generate the embeddings.

Here is an example of how to set this up in a model:
```ruby
class Model
  include Mongoid::Document
  include Spectre

  spectre :embeddable
  embeddable_field :message, :response, :category
end
```

**2.2. Searchable Module**

To enable vector-based search in your Rails model:

1.	Include the Spectre module:
Include Spectre in your model to enable the spectre method.
2.	Declare the Model as Searchable:
Use the spectre :searchable declaration to make the model searchable.
3.	Configure Search Parameters:
Use the following methods to configure the search path, index, and result fields:
•	configure_spectre_search_path: Set the path where the embeddings are stored.
•	configure_spectre_search_index: Set the index used for the vector search.
•	configure_spectre_result_fields: Set the fields to include in the search results.

Here is an example of how to set this up in a model:

```ruby
class Model
  include Mongoid::Document
  include Spectre

  spectre :searchable
  configure_spectre_search_path 'embedding'
  configure_spectre_search_index 'vector_index'
  configure_spectre_result_fields({ "message": 1, "response": 1 })
end
```

### 3. Generating Embeddings

**Generate Embedding for a Single Record**

To generate an embedding for a single record, you can call the embed! method on the instance:
```ruby
record = Model.find(some_id)
record.embed!
```
This will generate the embedding and store it in the specified embedding field, along with the timestamp in the embedded_at field.

**Generate Embeddings for Multiple Records**

To generate embeddings for multiple records at once, use the embed_all! method:
```ruby
Model.embed_all!(
  scope: -> { where(:response.exists => true, :response.ne => nil) },
  validation: ->(record) { !record.response.blank? }
)
```
This method will generate embeddings for all records that match the given scope and validation criteria. The method will also print the number of successful and failed embeddings to the console.

**Directly Generate Embeddings Using Spectre.provider_module::Embeddings.generate**

If you need to generate an embedding directly without using the model integration, you can use the Spectre::Openai::Embeddings.generate method. This can be useful if you want to generate embeddings for custom text outside of your models:

```ruby
Spectre.provider_module::Embeddings.generate("Your text here")
```

This method sends the text to OpenAI’s API and returns the embedding vector. You can optionally specify a different model by passing it as an argument:

```ruby
Spectre.provider_module::Embeddings.generate("Your text here", model: "text-embedding-3-large")
```

### 4. Performing Vector-Based Searches

Once your model is configured as searchable, you can perform vector-based searches on the stored embeddings:

```ruby
Model.search('Your search query', custom_result_fields: { "response" => 1 }, additional_scopes: [{ "$match": { "category": "science" } }])
```

This method will:

•	Embed the search query using the configured LLM provider.

•	Perform a vector-based search on the embeddings stored in the specified search_path.

•	Return the matching records with the specified result_fields and their vectorSearchScore.

**Examples:**

•	**Custom Result Fields**: Limit the fields returned in the search results.

•	**Additional Scopes**: Apply additional MongoDB filters to the search results.

### 5. Generating Completions

Spectre also provides an interface to generate text completions using the LLM provider. This can be useful for generating responses, messages, or other forms of text.

**Generate a Completion**

To generate a text completion, use the Spectre.provider_module::Completions.generate method:
    
```ruby
Spectre.provider_module::Completions.generate(
  user_prompt: "Tell me a joke.",
  system_prompt: "You are a funny assistant."
)
```

This method sends the prompts to the LLM provider’s API and returns the generated completion. You can optionally specify a different model by passing it as an argument:

```ruby
Spectre.provider_module::Completions.generate(
  user_prompt: "Tell me a joke.",
  system_prompt: "You are a funny assistant.",
  model: "gpt-4-turbo"
)
```

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/hiremav/spectre. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

