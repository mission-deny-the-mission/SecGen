# Notes

This epic addresses the core requirement of including the entire IRC conversation as context for LLM responses, rather than just LLM-triggered exchanges. This provides:

- **Better Context Awareness**: LLM sees complete conversation flow
- **Multi-User Support**: Can track conversations with multiple users
- **Command Awareness**: LLM understands what commands were issued and responses received
- **Natural Conversation Flow**: Context reflects actual IRC channel state

The implementation maintains backward compatibility while adding comprehensive message tracking and enhanced context assembly.

