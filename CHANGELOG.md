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

**Release Date:** [11th Oct 2024]

**New Features:**

* **Root Attribute in Configuration:**

    * Introduced a `root` attribute to the Spectre configuration. This allows users to specify a custom root directory for loading prompts or other templates.
    * Example usage in initializer:
    ```ruby
    Spectre.setup do |config|
        config.api_key = 'your_openai_api_key'
        config.root = Rails.root # or any custom path
    end
    ```
    * If `root` is not set, Spectre will default to the current working directory (Dir.pwd).
    * This is especially useful when integrating Spectre into other gems or non-Rails projects where the root directory might differ.


* **Prompt Path Detection:**
    * Prompt paths now use the configured `root` to locate the template files. This ensures that Spectre works correctly in various environments where template paths may vary.
    