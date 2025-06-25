# Commit Scripts Utilities

This directory contains modular utility functions for the commit scripts, providing a clean separation of concerns and improved maintainability.

## Structure

```
utils/
├── api_utils.ps1      # PowerShell API utility functions
├── api_utils.sh       # Bash API utility functions
├── ui_utils.ps1       # PowerShell UI utility functions
├── ui_utils.sh        # Bash UI utility functions
└── README.md          # This documentation
```

## API Utilities (`api_utils.*`)

### PowerShell Functions

- **`Send-ApiRequest`** - Sends HTTP requests to AI APIs (OpenAI/Azure)
- **`Get-CommitMessage`** - Extracts commit messages from API responses
- **`Test-ApiConfiguration`** - Validates API configuration settings
- **`New-ConversationMessages`** - Builds conversation message arrays for different scenarios

### Bash Functions

- **`send_api_request`** - Sends HTTP requests to AI APIs (OpenAI/Azure)
- **`get_commit_message`** - Extracts commit messages from API responses
- **`validate_api_config`** - Validates API configuration settings
- **`build_conversation_messages`** - Builds conversation message JSON for different scenarios
- **`build_json_payload`** - Creates JSON payloads for API requests
- **`build_api_config`** - Builds API URLs and authentication headers

## UI Utilities (`ui_utils.*`)

### PowerShell Functions

- **`Show-CommitOptions`** - Displays the commit message options menu
- **`Edit-CommitMessage`** - Opens Notepad for manual commit message editing
- **`Test-CommitMessageFormat`** - Validates commit message format
- **`Invoke-CommitExecution`** - Handles commit execution and push confirmation
- **`Get-UserChoice`** - Gets user input for menu options
- **`Get-ImprovementInstructions`** - Gets improvement instructions from user

### Bash Functions

- **`show_commit_options`** - Displays the commit message options menu
- **`edit_commit_message`** - Handles commit message editing with various editors
- **`validate_commit_message`** - Validates commit message format
- **`execute_commit`** - Handles commit execution and push confirmation
- **`get_user_choice`** - Gets user input for menu options
- **`get_improvement_instructions`** - Gets improvement instructions from user
- **`show_invalid_option`** - Shows error for invalid menu choices
- **`show_regeneration_success`** - Shows success message for regeneration
- **`show_improvement_success`** - Shows success message for improvement
- **`show_api_error`** - Shows error message for failed API operations

## Usage

### PowerShell

```powershell
# Load utilities
. "$ScriptDir\utils\api_utils.ps1"
. "$ScriptDir\utils\ui_utils.ps1"

# Use functions
$messages = New-ConversationMessages -UserContent $content
$response = Send-ApiRequest -Messages $messages -ApiUrl $apiUrl -ApiProvider $apiProvider -ApiKey $apiKey -Deployment $deployment -Version $version -Temperature $temperature -MaxTokens $maxToken
$commitMessage = Get-CommitMessage -Response $response
```

### Bash

```bash
# Load utilities
source "$SCRIPT_DIR/utils/api_utils.sh"
source "$SCRIPT_DIR/utils/ui_utils.sh"

# Use functions
messages=$(build_conversation_messages "$content")
response=$(send_api_request "$messages" "$api_url" "$auth_header")
commit_message=$(get_commit_message "$response")
```

## Benefits

1. **Modularity** - Functions are separated by concern (API vs UI)
2. **Reusability** - Functions can be used across different scripts
3. **Maintainability** - Easier to update and debug specific functionality
4. **Testability** - Individual functions can be tested in isolation
5. **Consistency** - Shared functions ensure consistent behavior across scripts
6. **Reduced Duplication** - Common functionality is centralized

## Error Handling

All utility functions include proper error handling and validation:

- API configuration validation
- Commit message format validation
- Editor availability checks
- Network request error handling
- User input validation

## Platform Compatibility

- **PowerShell**: Windows PowerShell 5.1+ compatible
- **Bash**: Bash 4+ and Zsh compatible (macOS/Linux)
- **Cross-platform**: Functions handle platform-specific differences automatically 