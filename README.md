# Spectre

**Spectre** is a Ruby gem designed to provide an abstraction layer for generating embeddings using OpenAI's API. This gem simplifies the process of embedding data fields within your Rails models.

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
end
```
### 2. Integrate Spectre with Your Model

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

## Contributing
Bug reports and pull requests are welcome on GitHub at https://github.com/hiremav/spectre. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

