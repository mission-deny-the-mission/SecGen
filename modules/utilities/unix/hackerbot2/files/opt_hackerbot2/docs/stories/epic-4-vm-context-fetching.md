# Epic 4: VM Context Fetching from Student Machines

**Epic ID**: EPIC-4
**Status**: Done
**Priority**: High
**Created**: 2025-01-XX
**Target Completion**: 3-4 weeks
**Related PRD**: [docs/prd.md](../prd.md)
**Depends on**: Epic 1 (RAG system validation and optimization complete), Epic 2I (Full IRC Channel Context Integration), Epic 3 (Stage-aware context injection)

---

## Epic Goal

Enable fetching of contextual information from student VMs (bash history, command outputs, and file contents) and injecting this runtime state information into LLM context, allowing the bot to provide responses based on actual student machine state.

---

## Epic Description

### Existing System Context

**Current Relevant Functionality**:
- IRC bot framework with SSH connectivity via `<get_shell>` configuration
- SSH command execution using `sshpass` and `ssh` with variable substitution (`{{chat_ip_address}}`)
- Post-command execution capability that runs commands after shell access is gained
- Command output capture and storage in bot state (`post_command_output`, `post_command_outputs`)
- Attack progression system with stage tracking
- Context enhancement system for LLM responses

**Technology Stack**:
- Language: Ruby 3.1+
- SSH Integration: Uses `Open3.popen2e` for command execution via SSH
- SSH Tooling: `sshpass` and `ssh` for remote access
- Context Assembly: bot_manager.rb handles context assembly for LLM prompts
- Configuration: XML-based bot configuration with `<attack>` elements

**Integration Points**:
- bot_manager.rb - SSH command execution and output capture
- `get_shell` configuration - SSH connection mechanism
- Context assembly system - Integration with LLM prompt generation
- XML configuration - Attack-level configuration for VM context fetching

### Enhancement Details

**What's Being Added/Changed**:

1. **Bash History Fetching**
   - Ability to retrieve bash history from student VMs via SSH
   - Configuration to specify which history file to read (e.g., `.bash_history`, `.zsh_history`)
   - Support for user-specific history files
   - Optional filtering/limiting of history entries (e.g., last N commands, recent commands)
   - Privacy/security considerations (Note: Student VMs are disposable lab environments)

2. **Command Output Fetching (XML-Configurable)**
   - XML configuration for defining commands to execute on student VMs
   - Per-attack command definitions (e.g., `ps aux`, `netstat -tuln`, `whoami`)
   - Execution of multiple commands per attack stage
   - Command output capture and storage
   - Support for command chaining and conditional execution
   - Error handling for failed commands

3. **File Content Reading**
   - Ability to read specific files from student VMs via SSH
   - XML configuration for specifying file paths to read per attack
   - Support for both absolute and relative paths
   - File content retrieval (Note: Student VMs are disposable lab environments, sanitization not needed for local LLM usage)
   - Support for reading multiple files per attack stage

4. **VM Context Integration**
   - Assembly of VM context (history + command outputs + files) into structured format
   - Integration with existing context enhancement system
   - VM context included in LLM prompt assembly
   - Context formatting that clearly distinguishes VM state from other context
   - Context size management (truncation, summarization for large outputs)

5. **XML Configuration Extensions**
   - `<vm_context>` element within `<attack>` for VM context configuration
   - `<bash_history>` sub-element with options (path, limit, sanitize)
   - `<commands>` sub-element with individual `<command>` elements
   - `<files>` sub-element with individual `<file>` elements specifying paths
   - Per-attack control over VM context fetching

**How It Integrates**:
- Extends `bot_manager.rb` to support VM context fetching via existing SSH infrastructure
- New `VMContextManager` class to coordinate SSH operations and context assembly
- XML configuration parser extended to read `<vm_context>` from attack definitions
- Context assembly in `get_enhanced_context` incorporates VM context
- Leverages existing SSH connection mechanism (`get_shell` configuration)
- Maintains backward compatibility - attacks without VM context config work unchanged

**Success Criteria**:
- ✅ Bash history can be fetched from student VMs via SSH
- ✅ Command outputs can be captured from XML-configured commands executed on student VMs
- ✅ File contents can be read from student VMs via SSH
- ✅ VM context is integrated into LLM prompt assembly
- ✅ XML configuration allows per-attack specification of VM context sources
- ✅ VM context is clearly formatted and attributed in LLM context
- ✅ Error handling gracefully manages SSH failures and command errors
- ✅ Existing attacks without VM context configuration continue to work unchanged

---

## Stories

### Story 4.1: Create VM Context Manager and SSH Helper Utilities
**Priority**: Critical
**Estimated Effort**: 4-5 days
**Dependencies**: None (Epic 1 completion recommended)

**Brief Description**: Create a new `VMContextManager` class that handles SSH-based operations for fetching context from student VMs. Implement SSH command execution, file reading, and output capture utilities. Reuse existing SSH connection mechanism from `get_shell` configuration.

**Acceptance Criteria**:
- [ ] `VMContextManager` class created in `vm_context_manager.rb`
- [ ] Method to execute SSH commands and capture output: `execute_command(ssh_config, command)`
- [ ] Method to read files via SSH: `read_file(ssh_config, file_path)`
- [ ] Method to read bash history: `read_bash_history(ssh_config, user=nil, limit=nil)`
- [ ] Error handling for SSH connection failures, timeouts, and command errors
- [ ] Support for `{{chat_ip_address}}` variable substitution in SSH configs
- [ ] Unit tests verify SSH command execution and file reading functionality
- [ ] Integration tests verify VM context manager with mock SSH connections

---

### Story 4.2: XML Configuration for VM Context Sources
**Priority**: Critical
**Estimated Effort**: 2-3 days
**Dependencies**: Story 4.1

**Brief Description**: Extend XML configuration schema to support attack-level VM context configuration. Allow `<attack>` elements to contain `<vm_context>` with `<bash_history>`, `<commands>`, and `<files>` sub-elements for specifying what to fetch from student VMs.

**Acceptance Criteria**:
- [ ] XML schema supports optional `<vm_context>` within `<attack>` elements
- [ ] `<bash_history>` element supports attributes: `path` (default: `~/.bash_history`), `limit` (number of lines), `user` (username)
- [ ] `<commands>` element contains individual `<command>` elements (e.g., `<command>ps aux</command>`)
- [ ] `<files>` element contains individual `<file>` elements with `path` attribute (e.g., `<file path="/etc/passwd"/><file path="./config.txt"/>`)
- [ ] Configuration parser reads and stores attack-level VM context settings in bot state
- [ ] Default behavior when no attack-level VM context config specified (no VM context fetched)
- [ ] Configuration examples added to existing XML config files
- [ ] XML schema validation ensures valid VM context configuration

---

### Story 4.3: Implement VM Context Fetching and Assembly
**Priority**: Critical
**Estimated Effort**: 5-6 days
**Dependencies**: Story 4.1, Story 4.2

**Brief Description**: Implement VM context fetching in `bot_manager.rb` that reads attack-level VM context configuration, executes SSH commands, reads files and bash history, and assembles the results into a structured format for LLM context.

**Acceptance Criteria**:
- [ ] `bot_manager.rb` reads attack-level VM context configuration from bot state
- [ ] When bash history specified, fetch via `VMContextManager.read_bash_history()`
- [ ] When commands specified, execute via `VMContextManager.execute_command()` for each command
- [ ] When files specified, read via `VMContextManager.read_file()` for each file
- [ ] VM context assembled into structured format with clear source attribution
- [ ] VM context formatted for LLM consumption (e.g., "VM State:\nBash History:\n...\nCommand Outputs:\n...\nFiles:\n...")
- [ ] Error handling logs warnings but continues if VM context fetching fails
- [ ] Support for optional SSH config per attack (falls back to global `get_shell` config)
- [ ] Integration tests verify VM context fetching during attack stages

---

### Story 4.4: Integrate VM Context into LLM Prompt Assembly
**Priority**: High
**Estimated Effort**: 3-4 days
**Dependencies**: Story 4.3

**Brief Description**: Integrate fetched VM context into the existing context assembly system. Modify `assemble_prompt` or `get_enhanced_context` to include VM context alongside RAG context, attack context, and chat history.

**Acceptance Criteria**:
- [ ] VM context included in `get_enhanced_context` return value
- [ ] `assemble_prompt` incorporates VM context into final LLM prompt
- [ ] VM context clearly distinguished from other context types (RAG, attack, chat)
- [ ] Context ordering: VM context appears in logical position (e.g., after attack context, before RAG)
- [ ] Context length management respects max_context_length limits (truncate VM context if needed)
- [ ] Option to enable/disable VM context injection per bot or attack (configuration flag)
- [ ] Integration tests verify VM context appears in LLM prompts
- [ ] End-to-end tests verify LLM responses incorporate VM state information

---

## Compatibility Requirements

- [x] Existing APIs remain unchanged (optional parameters added)
- [x] XML configuration is backward compatible (new elements are optional)
- [x] Bots without VM context configuration continue to work unchanged
- [x] SSH connection mechanism reuses existing `get_shell` infrastructure
- [x] No breaking changes to bot_manager or context assembly interfaces
- [x] Performance impact is acceptable (SSH operations are asynchronous where possible)

## Risk Mitigation

- **Primary Risk**: SSH connection failures breaking bot functionality
  - **Mitigation**: Graceful error handling; VM context fetching failures don't break bot responses; fallback to operation without VM context
- **Primary Risk**: Security vulnerabilities from reading sensitive files/commands
  - **Mitigation**: Configurable file/command allowlists; clear documentation on security practices (Note: Student VMs are disposable lab environments, so sanitization is not necessary for local LLM usage)
- **Primary Risk**: Performance degradation from SSH operations
  - **Mitigation**: Efficient SSH command execution; optional async/background fetching; context size limits; timeouts on SSH operations
- **Primary Risk**: Student VM connectivity issues affecting bot responses
  - **Mitigation**: Timeout handling; optional VM context (opt-in per attack); fallback behavior when SSH unavailable
- **Rollback Plan**: VM context features can be disabled via configuration; existing behavior is preserved as default when no VM context config specified

## Definition of Done

- [x] All stories completed with acceptance criteria met
- [x] Existing bot functionality verified through integration testing
- [x] VM context fetching works reliably across different SSH configurations
- [x] VM context appears correctly in LLM prompts and improves response quality
- [x] XML configuration documented with examples
- [x] Security considerations documented (student VMs are disposable lab environments)
- [x] No regression in existing features or performance
- [x] Code coverage maintained for new functionality
- [x] Documentation updated (configuration guide, architecture docs)

---

## Epic Completion Summary

**Completed**: 2025-01-30  
**All Stories Completed**: ✅

### Deliverables

1. **VMContextManager** (`vm_context_manager.rb`)
   - SSH command execution, file reading, and bash history retrieval
   - Comprehensive error handling and timeout management
   - 25 unit and integration tests

2. **XML Configuration Support**
   - VM context parsing with `<vm_context>`, `<bash_history>`, `<commands>`, and `<files>` elements
   - Schema validation in `hackerbot_schema.xsd`
   - Configuration examples in `config/example_stage_aware_context.xml`
   - 19 tests covering all parsing scenarios

3. **VM Context Fetching Integration**
   - `fetch_vm_context` and `assemble_vm_context` methods in `bot_manager.rb`
   - Per-attack and global SSH config support
   - Graceful error handling with partial context support
   - 13 integration tests

4. **LLM Prompt Integration**
   - VM context integrated into `get_enhanced_context` and `assemble_prompt`
   - Context ordering: System → Attack → VM State → Enhanced Context (RAG) → Chat History
   - Context length management with truncation
   - Bot-level and attack-level enable/disable flags
   - 12 tests (7 integration + 5 E2E)

### Test Coverage

- **70+ test methods** across 5 test files
- All acceptance criteria verified
- Error scenarios and edge cases covered
- E2E flow validation included

### QA Gate Status

- Story 4.1: PASS (Quality Score: 95/100)
- Story 4.2: PASS (Quality Score: 98/100)
- Story 4.3: PASS (Gate: PASS)
- Story 4.4: PASS (Gate: PASS)

**Epic Status**: ✅ **READY FOR MERGE**

---

## Notes

This epic enables the bot to have awareness of student VM state, allowing for more contextual and relevant responses. The bot can see what commands students have run, what files exist on their machines, and the current state of their systems. This is particularly valuable for:

- **Guided Learning**: Bot can see if students are using correct commands
- **Troubleshooting**: Bot can diagnose issues based on actual system state
- **Progressive Hints**: Bot can provide hints based on what students have already done
- **Real-time Adaptation**: Bot responses adapt to actual student progress rather than assumptions

Epic 3 (Stage-aware context injection) provides the foundation for attack-level configuration, which this epic extends with VM-specific context sources. The implementation reuses existing SSH infrastructure and integrates seamlessly with the context enhancement system.

