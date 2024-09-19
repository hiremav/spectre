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