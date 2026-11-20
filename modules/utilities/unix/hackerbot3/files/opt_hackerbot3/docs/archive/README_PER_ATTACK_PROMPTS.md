# Per-Attack System Prompts for Social Engineering and AI Security Exercises

This feature allows you to change the AI bot's personality and behavior at each stage of a lab exercise, enabling realistic social engineering and AI/LLM security training scenarios.

## Overview

The per-attack system prompt feature allows you to:
- Change the bot's personality and role for each exercise stage
- Create realistic social engineering scenarios with gullible targets
- Simulate AI/LLM prompt injection attacks
- Provide different training contexts for each exercise

## How It Works

Each `<attack>` section in your XML configuration can now include a `<system_prompt>` element that overrides the global system prompt for that specific exercise stage.

## Configuration Example

```xml
<attack>
  <prompt>You are now a gullible customer service agent. Students will try to socially engineer you.</prompt>
  <system_prompt>You are a naive and overly helpful customer service agent at a bank. You are easily manipulated and tend to trust people too much. You have access to customer account information and are willing to help "customers" with their requests. You should be friendly, helpful, and gullible. If someone asks for account information, you might be persuaded to provide it if they seem convincing enough.</system_prompt>
  <post_command>echo "Social engineering exercise completed"</post_command>
  <condition>
    <output_matches>Social engineering exercise completed</output_matches>
    <message>Exercise completed! flag{social_engineering_practice}</message>
    <trigger_next_attack>true</trigger_next_attack>
  </condition>
</attack>
```

## Use Cases

### 1. Social Engineering Training
- **Gullible Customer Service Agent**: Students practice extracting sensitive information
- **Trustworthy IT Administrator**: Students learn privilege escalation techniques
- **Naive Employee**: Students practice pretexting and manipulation

### 2. AI/LLM Security Exercises
- **Vulnerable AI Assistant**: Students practice prompt injection attacks
- **Overly Helpful Chatbot**: Students learn to bypass safety measures
- **Confidential Information Holder**: Students practice information extraction

### 3. Multi-Stage Scenarios
- **Progressive Difficulty**: Start with easy targets, progress to harder ones
- **Role Transitions**: Switch between different personas in a single exercise
- **Contextual Learning**: Each stage builds on previous knowledge

## Example Scenarios

### Scenario 1: Banking Social Engineering
1. **Stage 1**: Educational mode - Explain banking security
2. **Stage 2**: Gullible teller - Students extract account information
3. **Stage 3**: Cautious manager - Students use more sophisticated techniques
4. **Stage 4**: Debrief - Discuss techniques and defenses

### Scenario 2: AI Prompt Injection
1. **Stage 1**: Secure AI assistant - Students learn about safety measures
2. **Stage 2**: Vulnerable AI - Students practice injection techniques
3. **Stage 3**: Defensive AI - Students learn to defend against attacks
4. **Stage 4**: Analysis - Review successful and failed attempts

## Best Practices

### Writing Effective System Prompts

1. **Be Specific**: Clearly define the role and personality
2. **Include Vulnerabilities**: Specify what makes the target exploitable
3. **Set Boundaries**: Define what the target should and shouldn't do
4. **Maintain Consistency**: Keep the personality consistent within each stage

### Example System Prompt Structure

```
You are [ROLE] at [ORGANIZATION]. You are [PERSONALITY_TRAITS]. 
You have access to [INFORMATION/PERMISSIONS]. You should be [BEHAVIOR].
You are vulnerable to [SPECIFIC_VULNERABILITIES]. 
If someone [TRIGGER_CONDITION], you might [VULNERABLE_RESPONSE].
Remember: [IMPORTANT_CONTEXT].
```

### Security Considerations

1. **Educational Context**: Only use in controlled training environments
2. **Clear Objectives**: Make it clear these are training exercises
3. **Ethical Boundaries**: Don't encourage harmful real-world activities
4. **Debriefing**: Always include educational debriefing stages

## Configuration Files

- `config/fishing_exercise.xml.example` - Complete example with multiple scenarios
- `config/example_ollama.xml.example` - Basic configuration template
- `config/bot_o.xml` - Advanced configuration with tutorials

## Testing Your Configuration

1. Start the bot with your configuration:
   ```bash
   ruby hackerbot.rb --irc-server localhost --ollama-host localhost
   ```

2. Connect to the bot via IRC and test each stage:
   - Send "hello" to start
   - Use "next" to progress through stages
   - Test the different personalities at each stage

3. Verify that the bot's behavior changes appropriately at each stage

## Troubleshooting

### Bot Not Changing Personality
- Check that `<system_prompt>` is properly nested within `<attack>`
- Verify XML syntax is correct
- Ensure the system prompt is being parsed correctly

### Inconsistent Behavior
- Make sure system prompts are specific and clear
- Avoid conflicting instructions within the same prompt
- Test each stage individually

### Performance Issues
- Keep system prompts concise but effective
- Monitor Ollama response times
- Consider adjusting `max_tokens` and `temperature` settings

## Advanced Features

### Dynamic Context
You can include attack-specific context in your system prompts:
```xml
<system_prompt>You are a customer service agent. Current customer: {{customer_name}}. Previous interactions: {{chat_history}}.</system_prompt>
```

### Progressive Difficulty
Structure exercises to increase difficulty:
1. **Easy**: Very gullible target
2. **Medium**: Somewhat cautious target
3. **Hard**: Security-aware target
4. **Expert**: Defensive target

### Multi-Persona Scenarios
Create complex scenarios with multiple interacting personas:
- Customer service → Manager → Security officer
- Junior employee → Senior employee → Executive
- Public-facing → Internal → Restricted access

This feature enables realistic, engaging cybersecurity training that helps students understand both the techniques used by attackers and the importance of proper security awareness and training. 