# Epic Description

## Existing System Context

**Current Relevant Functionality**:
- IRC bot framework with chat history management
- Chat history stored only when LLM generates a response (`add_to_history` called after LLM response)
- History format: User/Assistant pairs stored in `@user_chat_histories`
- Context assembly includes chat history via `get_chat_context` method
- History excludes messages that don't trigger LLM responses (e.g., command messages like "next", "ready", etc.)

**Technology Stack**:
- Language: Ruby 3.1+
- IRC Framework: Cinch library for IRC bot functionality
- Chat History: Stored in `@user_chat_histories` hash structure
- Context Assembly: `assemble_prompt` method combines chat history with other context

**Integration Points**:
- bot_manager.rb - Chat history management and context assembly
- IRC message handlers - Capture all channel messages
- LLM prompt assembly - Include full conversation context

## Current Problem

**Existing Behavior**:
- Chat history is only added when `add_to_history` is called after an LLM response (lines 929, 937)
- Only messages that trigger LLM responses are stored
- Commands and other non-LLM messages are not captured in chat context
- When LLM responds, it only sees previous LLM exchanges, not the full IRC conversation

**Desired Behavior**:
- All IRC channel messages should be captured
- Full conversation context (all messages from all users and bots) should be included in LLM context
- LLM should see the complete conversation flow, including commands, bot responses, and all user messages

## Enhancement Details

**What's Being Added/Changed**:

1. **Comprehensive Message Capture**
   - Capture all IRC channel messages in chat history
   - Track messages from all users (not just the current user)
   - Store bot response messages (including non-LLM responses like "next", "ready", etc.)
   - Maintain chronological order of all messages

2. **Enhanced Chat History Structure**
   - Extend history format to include message metadata (timestamp, user, type)
   - Store message type classification (user message, bot LLM response, bot command response, system message)
   - Support multi-user conversation tracking
   - Optional filtering of message types for context inclusion

3. **Full Context Assembly**
   - Modify `get_chat_context` to return complete conversation thread
   - Include all channel messages in chronological order
   - Format messages clearly (e.g., "User alice: message", "Bot: response", "User bob: message")
   - Support configurable message history window (last N messages)

4. **IRC Message Tracking**
   - Add global message handler to capture all channel messages
   - Store messages in chronological order per channel/user
   - Track both user messages and bot responses
   - Handle message filtering (optional exclusion of certain message types)

5. **Context Formatting Enhancements**
   - Format full conversation context clearly for LLM consumption
   - Include message timestamps (optional)
   - Distinguish between different message types
   - Support compact vs. verbose formatting options

**How It Integrates**:
- Extends `bot_manager.rb` message handlers to capture all IRC messages
- Modifies `add_to_history` or creates new method to capture all messages (not just LLM-triggered)
- Enhances `get_chat_context` to return full conversation thread
- Updates `assemble_prompt` to include complete conversation context
- Maintains backward compatibility - existing history structure supported, new format is enhancement

**Success Criteria**:
- ✅ All IRC channel messages are captured and stored
- ✅ LLM context includes complete conversation history (all messages)
- ✅ Conversation context shows chronological flow of all participants
- ✅ Message format clearly identifies speakers (users, bot)
- ✅ Existing chat history functionality continues to work
- ✅ Configurable message history window size
- ✅ Optional filtering of message types (commands, system messages, etc.)

---
