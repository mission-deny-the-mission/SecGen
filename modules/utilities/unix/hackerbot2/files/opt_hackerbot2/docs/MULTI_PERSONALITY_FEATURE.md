# Multi-Personality Feature for Hackerbot

## Overview

The Multi-Personality feature allows Hackerbot assistants to have multiple distinct personalities that users can switch between dynamically. Each personality has its own system prompt, greeting messages, help text, and communication style, enabling the same bot to serve different educational and operational purposes.

## Features

- **Dynamic Personality Switching**: Users can switch between personalities on-demand
- **Personality-Specific System Prompts**: Each personality has its own AI behavior and expertise focus
- **Custom Messages**: Personalities can override default messages (greetings, help, etc.)
- **Per-User State**: Each user's current personality is tracked independently
- **Fallback Support**: Graceful fallback to default messages when personality-specific ones aren't available
- **Backward Compatibility**: Existing single-personality bots continue to work unchanged

## Configuration

### XML Schema Extension

Bot configurations now support a `<personalities>` section with multiple `<personality>` elements:

```xml
<hackerbot>
  <name>MyMultiPersonalityBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  
  <!-- Multiple Personalities Configuration -->
  <personalities>
    <personality>
      <name>red_team</name>
      <title>Red Team Specialist</title>
      <description>Offensive security expert focusing on penetration testing</description>
      <system_prompt>You are an offensive security expert...</system_prompt>
      <greeting>Welcome to Red Team operations!...</greeting>
      <help>Available commands: ...</help>
      <!-- Other optional message overrides -->
    </personality>
    
    <personality>
      <name>blue_team</name>
      <title>Blue Team Defender</title>
      <description>Defensive security expert focused on threat detection</description>
      <system_prompt>You are a defensive security expert...</system_prompt>
      <greeting>Welcome to defensive operations!...</greeting>
      <help>Available commands: ...</help>
    </personality>
  </personalities>
  
  <!-- Default personality -->
  <default_personality>red_team</default_personality>
  
  <!-- Global fallback messages (optional) -->
  <messages>
    <next>Moving to the next scenario...</next>
    <previous>Going back to the previous scenario...</previous>
    <!-- Other global messages -->
  </messages>
  
  <!-- Attacks and other configuration -->
  <attacks>
    <!-- Attack scenarios that use current personality's system prompt -->
  </attacks>
</hackerbot>
```

### Personality Elements

Each personality supports the following elements:

- **`name`**: Unique identifier for the personality (required)
- **`title`**: Human-readable title (optional, defaults to name)
- **`description`**: Brief description of the personality's focus (optional)
- **`system_prompt`**: AI system prompt for this personality (optional, falls back to global)
- **Message overrides**: Any of the global message types can be overridden:
  - `greeting`, `help`, `next`, `previous`, `goto`, `ready`, `say_ready`
  - `correct_answer`, `incorrect_answer`, `no_quiz`
  - `last_attack`, `first_attack`, `invalid`
  - `getting_shell`, `got_shell`, `shell_fail_message`, `repeat`, `non_answer`

## User Commands

### Personality Management

- **`personalities`**: List all available personalities
  ```
  <user> personalities
  <bot> Available personalities:
        red_team (Red Team Specialist) [CURRENT]
        blue_team (Blue Team Defender)
        researcher (Security Researcher)
        instructor (Cybersecurity Instructor)
  ```

- **`switch [personality_name]`**: Switch to a specific personality
  ```
  <user> switch blue_team
  <bot> Switched to blue_team personality (Blue Team Defender)
  ```

- **`personality [personality_name]`**: Alternative switch syntax
  ```
  <user> personality researcher
  <bot> Switched to researcher personality (Security Researcher)
  ```

- **`personality`**: Show current personality
  ```
  <user> personality
  <bot> Current personality: blue_team (Blue Team Defender) - Defensive security expert focused on threat detection, incident response, and security operations
  ```

## Implementation Details

### Architecture

The feature extends the existing `BotManager` class with personality management capabilities:

1. **Personality Storage**: Each bot maintains a dictionary of personalities
2. **User State Tracking**: Current personality is tracked per user
3. **Message Resolution**: Personality-specific messages are used when available, falling back to global messages
4. **System Prompt Management**: The AI's system prompt is updated based on the current personality

### Key Methods

- `initialize_personalities(bot_name)`: Sets up personality data structures
- `parse_personalities(bot_name, personalities_node)`: Parses personality configuration from XML
- `get_current_personality(bot_name, user_id)`: Returns user's current personality
- `set_current_personality(bot_name, user_id, personality_name)`: Switches user to specified personality
- `get_personality_system_prompt(bot_name, user_id)`: Gets the appropriate system prompt
- `get_personality_messages(bot_name, user_id, message_type)`: Gets personality-specific or fallback messages

### Command Handling

New IRC message handlers were added:
- `/personalities$/i` - List available personalities
- `/^personality$/i` - Show current personality
- `/^(switch|personality) .+$/i` - Switch to specified personality

The existing command handlers were updated to use personality-specific messages via `get_personality_messages()`.

## Example Use Cases

### Cybersecurity Training Bot

A training bot can have personalities for different roles:

- **`red_team`**: Focuses on attack techniques and penetration testing
- **`blue_team`**: Focuses on defense strategies and incident response
- **`researcher`**: Focuses on academic analysis and vulnerability research
- **`instructor`**: Focuses on structured learning and certification prep

### Technical Support Bot

A support bot could have personalities for:

- **`beginner`**: Simple explanations and step-by-step guidance
- **`expert`**: Advanced technical details and troubleshooting
- **`architect`**: Design patterns and best practices
- **`security`**: Security-focused responses and compliance

## Backward Compatibility

The feature maintains full backward compatibility:

1. **Single-personality bots** continue to work unchanged
2. **Missing personalities** fall back to global system prompt and messages
3. **Partial personality configs** use available personality-specific settings and fall back for missing ones

## Testing

A comprehensive test suite validates:

- Personality parsing from XML configuration
- Personality switching functionality
- Message resolution with proper fallbacks
- System prompt management
- Error handling for invalid personalities
- Per-user personality tracking

Run tests with:
```bash
ruby test_personalities_only.rb
```

## Configuration Examples

See `config/example_multi_personality_bot.xml` for a complete working example with four cybersecurity-focused personalities.

## Future Enhancements

Potential future improvements:

1. **Personality Inheritance**: Allow personalities to inherit from base personalities
2. **Conditional Personalities**: Switch personalities based on conversation context
3. **Personality Metrics**: Track usage statistics for each personality
4. **Dynamic Personalities**: Load personalities from external sources
5. **Personality Templates**: Reusable personality configurations