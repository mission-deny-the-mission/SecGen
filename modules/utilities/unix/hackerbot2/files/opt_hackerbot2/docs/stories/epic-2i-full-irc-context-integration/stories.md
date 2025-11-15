# Stories

## Story 2I.1: Capture All IRC Channel Messages
**Priority**: Critical
**Estimated Effort**: 2-3 days
**Dependencies**: None

**Brief Description**: Modify IRC message handlers to capture all channel messages, not just those that trigger LLM responses. Store messages with metadata (user, timestamp, type) in an enhanced chat history structure.

**Acceptance Criteria**:
- [ ] Global message handler captures all IRC channel messages
- [ ] Messages stored with metadata: user, timestamp, message type, content
- [ ] Message types classified: user_message, bot_llm_response, bot_command_response, system_message
- [ ] Messages stored per channel or per user (configurable)
- [ ] Chronological ordering maintained
- [ ] Unit tests verify message capture for all message types
- [ ] Integration tests verify message storage across multiple users and messages

---

## Story 2I.2: Enhance Chat History Structure and Storage
**Priority**: Critical
**Estimated Effort**: 2-3 days
**Dependencies**: Story 2I.1

**Brief Description**: Redesign chat history storage to accommodate full conversation context. Update data structures to store all messages with metadata, supporting multi-user conversations and message type classification.

**Acceptance Criteria**:
- [ ] Chat history structure enhanced to store message metadata
- [ ] Support for multi-user conversation history
- [ ] Chronological ordering of messages maintained
- [ ] Message history window size configurable (default: last N messages)
- [ ] Backward compatibility: existing history format still supported
- [ ] History cleanup/pruning when exceeding max size
- [ ] Unit tests verify history structure and operations

---

## Story 2I.3: Update Context Assembly for Full Conversation
**Priority**: Critical
**Estimated Effort**: 2-3 days
**Dependencies**: Story 2I.2

**Brief Description**: Modify `get_chat_context` and `assemble_prompt` to include complete conversation context. Format all messages clearly for LLM consumption, showing full conversation flow with all participants.

**Acceptance Criteria**:
- [ ] `get_chat_context` returns complete conversation thread (all messages)
- [ ] Message formatting clearly identifies speakers: "User alice: ...", "Bot: ..."
- [ ] Chronological order of messages preserved in context
- [ ] LLM prompt includes full conversation context
- [ ] Configurable message filtering (which message types to include)
- [ ] Context length management (truncate oldest messages if needed)
- [ ] Integration tests verify full conversation context in LLM prompts

---

## Story 2I.4: Message Type Filtering and Configuration
**Priority**: Medium
**Estimated Effort**: 1-2 days
**Dependencies**: Story 2I.3

**Brief Description**: Add configuration options for filtering which message types are included in LLM context. Allow control over whether commands, system messages, and other message types are included in conversation context.

**Acceptance Criteria**:
- [ ] Configuration option for message type filtering
- [ ] XML/config option to specify which message types to include/exclude
- [ ] Default behavior: include all message types
- [ ] Message filtering respects configured rules
- [ ] Tests verify filtering works correctly
- [ ] Documentation on message type filtering options

---
