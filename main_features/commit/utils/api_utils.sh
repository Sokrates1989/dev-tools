#!/bin/bash
# -----------------------------------------------------------------------------
# Script: api_utils.sh
# Description: Utility functions for API operations in commit scripts
# Platform: Bash/Zsh compatible
# -----------------------------------------------------------------------------

# Function to send API request
send_api_request() {
  local messages_json="$1"
  local api_url="$2"
  local auth_header="$3"
  
  local response
  response=$(curl -s -X POST "$api_url" \
    -H "Content-Type: application/json" \
    -H "$auth_header" \
    -d "$messages_json")
  
  echo "$response"
}

# Function to extract commit message from response
get_commit_message() {
  local response="$1"
  
  local commit_line
  commit_line=$(echo "$response" | jq -r '.choices[0].message.content' | sed -n 's/.*\(git commit -m .*"\).*/\1/p')
  
  if [[ -n "$commit_line" ]]; then
    echo "$commit_line"
  else
    echo ""
  fi
}

# Function to build JSON payload
# Uses stdin for messages_json to avoid "Argument list too long" errors
build_json_payload() {
  local messages_json="$1"
  local api_provider="$2"
  local deployment="$3"
  local temperature="$4"
  local max_tokens="$5"
  
  if [[ "$api_provider" == "openai" ]]; then
    printf '%s' "$messages_json" | jq \
      --arg model "$deployment" \
      --arg temp "$temperature" \
      --argjson max_tokens "$max_tokens" \
      '. as $messages |
      {
        model: $model,
        messages: $messages,
        temperature: ($temp | tonumber),
        max_tokens: $max_tokens
      }'
  else
    printf '%s' "$messages_json" | jq \
      --arg temp "$temperature" \
      --argjson max_tokens "$max_tokens" \
      '. as $messages |
      {
        messages: $messages,
        temperature: ($temp | tonumber),
        max_tokens: $max_tokens
      }'
  fi
}

# Function to validate API configuration
validate_api_config() {
  local api_key="$1"
  local api_provider="$2"
  local api_url="$3"
  
  if [[ -z "$api_key" ]]; then
    echo "❌ API_KEY is not set in .env file. Aborting."
    return 1
  fi
  
  if [[ "$api_provider" != "openai" && "$api_provider" != "azure" ]]; then
    echo "❌ Invalid API_PROVIDER in .env: $api_provider. Must be 'openai' or 'azure'."
    return 1
  fi
  
  if [[ -z "$api_url" ]]; then
    echo "❌ API_BASE is not set in .env file. Aborting."
    return 1
  fi
  
  return 0
}

# Function to build conversation messages for different scenarios
# Uses stdin for user_content to avoid "Argument list too long" errors with large diffs
build_conversation_messages() {
  local user_content="$1"
  local system_prompt="${2:-You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git commit messages.}"
  local previous_message="$3"
  local additional_prompt="$4"
  
  local messages_json
  if [[ -n "$previous_message" && -n "$additional_prompt" ]]; then
    # Use printf + pipe to pass large content via stdin instead of command-line args
    messages_json=$(printf '%s' "$user_content" | jq -Rs \
      --arg system "$system_prompt" \
      --arg prev_msg "$previous_message" \
      --arg add_prompt "$additional_prompt" \
      '. as $content |
      [
        { role: "system", content: $system },
        { role: "user", content: $content },
        { role: "assistant", content: $prev_msg },
        { role: "user", content: $add_prompt }
      ]')
  elif [[ -n "$previous_message" ]]; then
    messages_json=$(printf '%s' "$user_content" | jq -Rs \
      --arg system "$system_prompt" \
      --arg prev_msg "$previous_message" \
      '. as $content |
      [
        { role: "system", content: $system },
        { role: "user", content: $content },
        { role: "assistant", content: $prev_msg }
      ]')
  else
    messages_json=$(printf '%s' "$user_content" | jq -Rs \
      --arg system "$system_prompt" \
      '. as $content |
      [
        { role: "system", content: $system },
        { role: "user", content: $content }
      ]')
  fi
  
  echo "$messages_json"
}

# Function to build API URL and auth header
build_api_config() {
  local api_provider="$1"
  local api_base="$2"
  local api_key="$3"
  local deployment="$4"
  local api_version="$5"
  
  local api_url
  local auth_header
  
  if [[ "$api_provider" == "openai" ]]; then
    api_url="${api_base}chat/completions"
    auth_header="Authorization: Bearer ${api_key}"
  elif [[ "$api_provider" == "azure" ]]; then
    api_url="${api_base}openai/deployments/${deployment}/chat/completions?api-version=${api_version}"
    auth_header="api-key: ${api_key}"
  fi
  
  echo "$api_url|$auth_header"
} 