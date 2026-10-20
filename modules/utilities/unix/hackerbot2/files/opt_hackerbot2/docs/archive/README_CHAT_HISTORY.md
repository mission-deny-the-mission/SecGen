# Chat History Feature for Hackerbot

This document describes the new chat history functionality that has been added to Hackerbot, allowing the LLM to maintain context from previous conversations when answering questions.

## Overview

The chat history feature enables the LLM to remember previous exchanges with each user, providing more contextual and coherent responses. This is particularly useful for:

- Maintaining conversation context across multiple messages
- Providing more relevant responses based on previous interactions
- Improving the overall user experience with more natural conversations

## Features

### Per-User Chat History
- Each user has their own separate chat history
- Chat history is maintained using the user's nickname as the identifier
- History is automatically managed and doesn't interfere between different users

### Automatic History Management
- Chat history is automatically updated with each user-assistant exchange
- History is limited to the last 10 exchanges to prevent context overflow
- Old exchanges are automatically removed when the limit is exceeded

### Context Integration
- Chat history is included in the prompt sent to the LLM
- Current attack context is also provided to make responses more relevant
- The LLM can reference previous conversations when formulating responses

## New Commands

### `clear_history`
Clears the chat history for the current user.

**Usage:**
```
clear_history
```

**Response:**
```
Chat history cleared for [username].
```

### `show_history`
Displays the current chat history for the current user.

**Usage:**
```
show_history
```

**Response:**
```
Chat history for [username]:
User: [previous message]
Assistant: [previous response]
...
```

## Technical Implementation

### OllamaClient Class Changes

The `OllamaClient` class has been enhanced with the following new methods:

- `add_to_history(user_message, assistant_response, user_id = nil)` - Adds an exchange to the chat history
- `get_chat_context(user_id = nil)` - Retrieves formatted chat history for a user
- `clear_user_history(user_id)` - Clears chat history for a specific user
- `generate_response(message, context = '', user_id = nil)` - Enhanced to include user-specific history

### Chat History Storage

- Chat history is stored in memory using a hash structure
- Each user's history is stored separately in `@user_chat_histories`
- History is maintained as an array of exchange objects with `user` and `assistant` keys

### Context Format

The chat history is formatted as:
```
User: [user message]
Assistant: [assistant response]

User: [user message]
Assistant: [assistant response]
...
```

This format is then included in the prompt sent to the LLM along with the current attack context.

## Configuration

### History Length
The maximum number of exchanges kept in history can be configured by modifying the `@max_history_length` variable in the `OllamaClient` class (default: 10).

### System Prompt Integration
The chat history is integrated with the existing system prompt, maintaining the bot's personality while adding conversation context.

## Testing

A test script `test_chat_history.rb` is provided to verify the functionality:

```bash
ruby test_chat_history.rb
```

This script tests:
- Per-user chat history isolation
- History retrieval and formatting
- History clearing functionality
- Context integration

## Usage Examples

### Basic Conversation Flow
1. User: "Hello, what's your name?"
2. Assistant: "Hello! I'm Hackerbot, your AI assistant for this hacking challenge."
3. User: "What did I just ask you?"
4. Assistant: "You just asked me what my name is. I told you I'm Hackerbot, your AI assistant for this hacking challenge."

### With Attack Context
The LLM also receives information about the current attack, allowing for more relevant responses:

```
Current attack (1): Exploit the vulnerable web application
```

This context helps the LLM provide more targeted assistance related to the current hacking challenge.

## Benefits

1. **Improved Context Awareness**: The LLM can reference previous conversations
2. **Better User Experience**: More natural and coherent conversations
3. **Relevant Responses**: Context-aware responses based on current attack state
4. **User Isolation**: Each user's conversation history is kept separate
5. **Memory Management**: Automatic cleanup prevents memory issues

## Limitations

- Chat history is stored in memory and will be lost when the bot restarts
- History is limited to 10 exchanges per user to prevent context overflow
- No persistent storage of chat history across bot restarts

## Future Enhancements

Potential improvements could include:
- Persistent storage of chat history to disk
- Configurable history length per user
- Export/import of chat history
- Chat history analytics and insights 