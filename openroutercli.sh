#!/bin/bash

# ------------------------------------------------------------------------------------
# 2025, by dkucic  
# Description: A shell script wrapper for OpenRouter API. 
# OpenRouter: https://openrouter.ai
# Note: The API key is securely retrieved using `pass` or by reading the value from
# environment variable OPENROUTER_API_KEY 
# Disclaimer:  
# This script is free to use but provided "AS IS," without any warranties,  
# express or implied. The author is not liable for any damages, data loss,  
# or other issues arising from its use. Use at your own risk.  
# ------------------------------------------------------------------------------------

# Initialize variables with default values
MODEL="anthropic/claude-3-haiku"
SYSTEM_PROMPT="You are a useful assistant. You do not speculate but state clearly what you don't know."
USER_PROMPT=""
TEMP_DIR=""
MARKDOWN_OUTPUT="false"
STREAMING="false"

# Check if OPENROUTER_API_KEY environment variable exists and has value, otherwise attempt to fetch
# it via pass util. Environment variables are added for conteinerization purpose.
if [ -z "$OPENROUTER_API_KEY" ]; then
  OPENROUTER_API_KEY=$(pass show registrations/openrouter | grep API | cut -d ':' -f 2 | xargs)
  if [ -z "$OPENROUTER_API_KEY" ]; then
        echo "Error: Failed to retrieve API key from pass." >&2
        exit 1
    fi
fi

# Create help message
HELP_MESSAGE=$(cat <<EOF
OpenRouter API CLI Interface

Usage: $0 [options]

Options:
  -m <model>           Specify the model (default: anthropic/claude-3-haiku)
  -s <system_prompt>   Set custom system prompt
  -u <user_prompt>     User prompt/question (required unless stdin is provided)
  -l                   List available models
  -c                   Check API credit usage and credits remaining
  -d                   Output response in markdown format
  -t                   Enable streaming mode for real-time responses
  -h                   Display this help message

Examples:
  $0 -u "Explain quantum computing"
  $0 -m anthropic/claude-3-opus -u "Write a short story" -d
  $0 -u "Tell me a long story" -t
  cat prompt.txt | $0 -m anthropic/claude-3-sonnet
EOF
)

# Function to clean markdown output
clean_markdown() {
  sed 's/\\n/\n/g' | sed 's/^"//; s/"$//'
}

# Function to list available models
list_models() {
  curl -s https://openrouter.ai/api/v1/models | jq '.data[].id'
}

# Function to check remaining credits
credits_remaining() {
  local response=""  
  response=$(curl --silent -H "Authorization: Bearer $OPENROUTER_API_KEY" \
                  -H "Content-Type: application/json" \
                  "https://openrouter.ai/api/v1/auth/key")
  
  # Extract and display credit information
  local credits_used=""
  credits_used=$(echo "$response" | jq -r '.data.usage')
  local credits_remaining=""
  credits_remaining=$(echo "$response" | jq -r '.data.limit_remaining')

  echo "Credits used:$credits_used$, credits remaining:$credits_remaining$"
}

# Function to create a temporary directory for processing
create_temp_dir() {
  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_DIR"' EXIT
}

# Function to handle streamed response chunks
process_stream() {
  #local in_content=false
  local content=""
  local last_chunk=""
  
  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Check if this is a data line
    if [[ "$line" == data:* ]]; then
      # Extract the JSON part
      json_data="${line#data: }"
      
      # Skip [DONE] marker
      [[ "$json_data" == "[DONE]" ]] && continue
      
      # Extract content delta
      delta=$(echo "$json_data" | jq -r '.choices[0].delta.content // empty')
      
      # Print content delta if it exists
      if [ -n "$delta" ]; then
        # If markdown is enabled, we need to buffer the content
        if [ "$MARKDOWN_OUTPUT" == "true" ]; then
          content="$content$delta"
          last_chunk="$delta"
        else
          # Print directly for non-markdown output
          printf "%s" "$delta"
        fi
      fi
    fi
  done
  
  # If we're in markdown mode, clean and output the entire content at the end
  if [ "$MARKDOWN_OUTPUT" == "true" ] && [ -n "$content" ]; then
    echo "$content" | clean_markdown
  fi
  
  # Add a newline at the end if needed
  if [ -n "$last_chunk" ] && [[ "$last_chunk" != *$'\n' ]]; then
    echo ""
  fi
}

# Function to handle the API chat request
chat() {

  # Update system prompt based on markdown preference
  local final_system_prompt="$SYSTEM_PROMPT"
  if [ "$MARKDOWN_OUTPUT" == "true" ]; then
    final_system_prompt="$SYSTEM_PROMPT Your response is in markdown format."
  fi

  # Start building the JSON payload
  local json_payload
  
    # Simple text-only user message
    json_payload=$(cat <<EOF
{
  "model": "$MODEL",
  "stream": $STREAMING,
  "messages": [
    {"role": "system", "content": "$final_system_prompt"},
    {"role": "user", "content": "$USER_PROMPT"}
  ]
}
EOF
)
  
  # Save the payload to a temporary file
  if [ -n "$TEMP_DIR" ]; then
    echo "$json_payload" > "$TEMP_DIR/payload.json"
  else
    create_temp_dir
    echo "$json_payload" > "$TEMP_DIR/payload.json"
  fi
  
  # Make the API request - handle streaming differently
  if [ "$STREAMING" == "true" ]; then
    # Make streaming request and process the stream
    curl --silent -N https://openrouter.ai/api/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENROUTER_API_KEY" \
      -d @"$TEMP_DIR/payload.json" | process_stream
  else
    # Regular non-streaming request
    local response
    response=$(curl --silent https://openrouter.ai/api/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENROUTER_API_KEY" \
      -d @"$TEMP_DIR/payload.json"
    )
    
    # Extract the response message
    local response_message
    response_message=$(echo "$response" | jq -r '.choices[0].message.content // empty')
    
    if [ -z "$response_message" ]; then
      echo "Error: Failed to get a valid response. API returned:" >&2
      echo "$response" | jq . >&2
      exit 1
    fi
    
    # Display the response - with or without markdown cleaning based on the flag
    if [ "$MARKDOWN_OUTPUT" == "true" ]; then
      echo "$response_message" | clean_markdown
    else
      echo "$response_message"
    fi
  fi
}

# Check for required dependencies
for cmd in jq curl; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: $cmd is not installed. Please install it first." >&2
    exit 1
  fi
done

# Check if stdin has data
if [ -t 0 ]; then
  # No stdin data
  STDIN_DATA=""
else
  # Read from stdin
  STDIN_DATA=$(cat)
  if [ -n "$STDIN_DATA" ]; then
    USER_PROMPT="$STDIN_DATA"
  fi
fi

# Process command line arguments
while getopts "m:u:s:lcdth" opt; do
  case "$opt" in
    m) MODEL="$OPTARG" ;;
    u) USER_PROMPT="$OPTARG" ;;
    s) SYSTEM_PROMPT="$OPTARG" ;;
    l) list_models; exit 0 ;;
    c) credits_remaining; exit 0 ;; 
    d) MARKDOWN_OUTPUT="true" ;;
    t) STREAMING="true" ;;
    h) echo "$HELP_MESSAGE"; exit 0 ;;
    ?) echo "$HELP_MESSAGE" >&2; exit 1 ;;
  esac
done

# Check if no command line arguments were provided and no stdin
if [ $OPTIND -eq 1 ] && [ -z "$STDIN_DATA" ]; then
    echo -e "No arguments provided." >&2
    echo "$HELP_MESSAGE" >&2
    exit 1
fi

# Only invoke chat if user prompt has been provided
if [ -n "$USER_PROMPT" ]; then
    chat
else
    echo "Error: User prompt is required. Use -u <user_prompt> or pipe content to the script." >&2
    echo "$HELP_MESSAGE" >&2
    exit 1
fi
