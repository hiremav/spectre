# Changelog for Version 1.0.1

**Release Date:** [19th Sep 2024]

**Improvements to Prompt Class**

1.	Escaping Special Characters in YAML/ERB:

•	Implemented automatic escaping of special characters in YAML/ERB templates, such as &, <, >, ", and ' to prevent parsing issues.

•	Special characters are escaped before rendering the YAML file to ensure compatibility with YAML parsers.

•	After rendering, the escaped characters are converted back to their original form, ensuring the final output is clean and readable.

•	This update prevents errors that occur when rendering templates with complex queries or strings containing special characters.

Example:

```yaml
user: |
  User's query: <%= @query %>
  Context: <%= @responses.join(", ") %>
```

Before this change, queries or responses containing special characters might have caused YAML parsing errors. This update ensures that even complex strings are handled safely and returned in their original form.

To upgrade, update your Gemfile to version 1.0.1 and run bundle install. Make sure your YAML/ERB templates do not manually escape special characters anymore, as the Prompt class will handle it automatically.

# Changelog for Version 1.1.0

**Release Date:** [7th Oct 2024]

**New Features:**

* **Tool _(Function Calling)_ Integration:** Added support for tools parameter to enable function calling during completions. Now you can specify an array of tool definitions that the model can use to call specific functions.

* **Enhanced Message Handling:** Replaced individual prompt parameters (user_prompt, system_prompt, assistant_prompt) with a single messages array parameter, which accepts a sequence of messages with their roles and contents. This provides more flexibility in managing conversations.

* **Response Validation:** Introduced a handle_response method to handle different finish_reason cases more effectively, including content filtering and tool call handling.

* **Improved Error Handling:**
Added more specific error messages for cases like refusal (Refusal), incomplete response due to token limits (Incomplete response), and content filtering (Content filtered).
Enhanced JSON parsing error handling with more descriptive messages.

* **Request Validation:** Implemented message validation to ensure the messages parameter is not empty and follows the required format. Raises an error if validation fails.

* **Support for Structured Output:** Integrated support for json_schema parameter in the request body to enforce structured output responses.

* **Skip Request on Empty Messages:** The class will now skip sending a request if the messages parameter is empty or invalid, reducing unnecessary API calls.

**Breaking Changes:**

**Message Parameter Refactor**: The previous individual prompt parameters (user_prompt, system_prompt, assistant_prompt) have been consolidated into a single messages array. This may require updating any existing code using the old parameters.

**Bug Fixes:**

* **API Key Check:** Improved error handling for cases when the API key is not configured, providing a more specific exception.

* **Error Messages:** Enhanced error messages for various edge cases, including content filtering and incomplete responses due to token limits.

**Refinements:**

Code Refactoring:
* Moved message validation into a dedicated validate_messages! method for clarity and reusability.
* Simplified the generate_body method to include the tools and json_schema parameters more effectively.

**Documentation:** Updated class-level documentation and method comments for better clarity and understanding of the class’s functionality and usage.

This version enhances the flexibility and robustness of the Completions class, enabling more complex interactions and better error handling for different types of API responses.

# Changelog for Version 1.1.1

**Release Date:** [10th Oct 2024]

**New Features:**

* **Nested Template Support in Prompts**
  * You can now organize your prompt files in nested directories and render them using the `Spectre::Prompt.render` method.
  * **Example**: To render a template from a nested folder:
    ```ruby
    Spectre::Prompt.render(template: 'classification/intent/user', locals: { query: 'What is AI?' })
    ```
  * This feature allows for better organization and scalability when dealing with multiple prompt categories and complex scenarios.


# Changelog for Version 1.1.2

**Release Date:** [11th Oct 2024]

**New Features:**

* **Dynamic Project Root Detection for Prompts**
  * The `Spectre::Prompt.render` method now dynamically detects the project root based on the presence of project-specific markers, such as `Gemfile`, `.git`, or `config/application.rb`.
  * This change allows for greater flexibility when using spectre in different environments and projects, ensuring the prompt templates are found regardless of where spectre is used.
  *	**Example**: If you're using `spectre` inside a gem, the `detect_prompts_path` method will now correctly resolve the prompts path within the gem project root.
  *	If no markers are found, the system falls back to the current working directory (`Dir.pwd`).


# Changelog for Version 1.1.3

**Release Date:** [2nd Dec 2024]

**Fixes:**

* **Removed unnecessary validations in `Completions` class**
  * Removed redundant validations in the `Completions` class that were causing unnecessary errors in specific edge cases. LLM providers returns a proper errors messages now.


# Changelog for Version 1.1.4

**Release Date:** [5th Dec 2024]

**New Features:**

* Customizable Timeout for API Requests
* Introduced DEFAULT_TIMEOUT constant (set to 60 seconds) for managing request timeouts across the Completions and Embeddings classes.
* Added optional arguments (args) to create methods, allowing users to override read_timeout and open_timeout dynamically.
* This change ensures greater flexibility when dealing with varying network conditions or API response times.

**Example Usage:**

```ruby
Spectre::Openai::Completions.create(
  messages: messages,
  read_timeout: 30,
  open_timeout: 20
)
```

**Key Changes:**

* **Updated Completions class:**
  * http.read_timeout = args.fetch(:read_timeout, DEFAULT_TIMEOUT)
  * http.open_timeout = args.fetch(:open_timeout, DEFAULT_TIMEOUT)
  * Updated Embeddings class with the same timeout handling logic.

**Fixes:**

* Simplified Exception Handling for Timeouts
* Removed explicit handling of Net::OpenTimeout and Net::ReadTimeout exceptions in both Completions and Embeddings classes.
* Letting these exceptions propagate ensures clearer and more consistent error messages for timeout issues.


# Changelog for Version 1.2.0

**Release Date:** [30th Jan 2025]

### **New Features & Enhancements**

1️⃣ **Unified Configuration for LLM Providers**

🔧 Refactored the configuration system to provide a consistent interface for setting up OpenAI and Ollama within config/initializers/spectre.rb.\
•	Now, developers can seamlessly switch between OpenAI and Ollama by defining a single provider configuration block.\
•	Ensures better modularity and simplifies adding support for future providers (Claude, Cohere, etc.).

🔑 **Example Configuration:**

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

Key Improvements:\
✅ API key validation added: Now properly checks if api_key is missing and raises APIKeyNotConfiguredError.\
✅ Host validation added: Now checks if host is missing for Ollama and raises HostNotConfiguredError.

2️⃣ **Added Ollama Provider Support**

🆕 Introduced full support for Ollama, allowing users to use local LLM models efficiently.\
•	Supports Ollama-based completions for generating text using local models like llama3.\
•	Supports Ollama-based embeddings for generating embeddings using local models like nomic-embed-text.\
•	Automatic JSON Schema Conversion: OpenAI’s json_schema format is now automatically translated into Ollama’s format key.

3️⃣ **Differences in OpenAI Interface: max_tokens Moved to `**args`**

💡 Refactored the OpenAI completions request so that max_tokens is now passed as a dynamic argument inside `**args` instead of a separate parameter.\
•	Why? To ensure a consistent interface across different providers, making it easier to switch between them seamlessly.\
•	Before:
```ruby
Spectre.provider_module::Completions.create(messages: messages, max_tokens: 50)
```
•	After:
```ruby
Spectre.provider_module::Completions.create(messages: messages, openai: { max_tokens: 50 })
```

Key Benefits:\
✅ Keeps the method signature cleaner and future-proof.\
✅ Ensures optional parameters are handled dynamically without cluttering the main method signature.\
✅ Improves consistency across OpenAI and Ollama providers.
