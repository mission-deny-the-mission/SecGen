# SecGen - AI Agent Guide

## Project Overview

SecGen (Security Scenario Generator) is a Ruby-based system that creates randomized vulnerable virtual machines for security education, penetration testing training, and Capture The Flag (CTF) events. The system uses XML-based scenario definitions, Puppet for configuration management, and Vagrant for VM provisioning.

## Project Structure

```
SecGen/
├── secgen.rb                    # Main entry point and orchestrator
├── Gemfile                      # Ruby dependencies
├── README.md                    # User documentation
├── AGENTS.md                    # This file - AI agent guide
├── lib/                         # Core Ruby libraries
│   ├── helpers/                 # Utility functions and helpers
│   │   ├── constants.rb         # Global constants and paths
│   │   ├── print.rb             # Output formatting and logging
│   │   ├── gem_exec.rb          # External command execution
│   │   ├── ovirt.rb             # oVirt cloud provider integration
│   │   ├── proxmox.rb           # Proxmox cloud provider integration
│   │   └── scenario.rb          # Scenario processing utilities
│   ├── readers/                 # XML and configuration readers
│   │   ├── system_reader.rb     # Scenario XML parsing
│   │   ├── module_reader.rb     # Module discovery and loading
│   │   └── xml_reader.rb        # Generic XML parsing utilities
│   ├── objects/                 # Core data models
│   │   ├── system.rb            # System object representation
│   │   ├── module.rb            # Module object representation
│   │   └── post_provision_test.rb # Test framework
│   ├── output/                  # File generation utilities
│   │   ├── project_files_creator.rb # Main project file generator
│   │   ├── ctd_generator.rb     # CTFd platform integration
│   │   └── xml_*.rb             # Various XML generators
│   └── templates/               # ERB templates for file generation
├── modules/                     # Module definitions (vulnerabilities, services, etc.)
│   ├── vulnerabilities/         # Exploitable security flaws
│   ├── services/                # Network services and applications
│   ├── utilities/               # Helper tools and system utilities
│   ├── generators/              # Content creation tools
│   ├── encoders/                # Data encoding utilities
│   ├── bases/                   # Base operating system images
│   ├── networks/                # Network configuration modules
│   └── build/                   # Build-time resources and scripts
├── scenarios/                   # XML scenario definitions
│   ├── default_scenario.xml     # Default scenario
│   ├── ctf/                     # CTF-specific scenarios
│   ├── labs/                    # Educational lab scenarios
│   └── security_audit/          # Security audit scenarios
├── documentation/               # Generated documentation
└── projects/                    # Generated project output (created during runtime)
```

## Core Architecture

### Main Components

1. **secgen.rb** - Main orchestrator that:
   - Parses command-line arguments
   - Loads and validates scenarios
   - Coordinates module resolution
   - Manages VM building process
   - Handles error recovery and retries

2. **System Objects** (lib/objects/system.rb):
   - Represent individual VMs to be created
   - Contain module selections and configuration
   - Handle conflict resolution
   - Manage resource allocation

3. **Module System**:
   - Each module type has a specific directory under `modules/`
   - Modules contain `secgen_metadata.xml` with capabilities
   - Modules are selected based on scenario constraints
   - Randomization ensures unique builds

4. **Project Generation** (lib/output/project_files_creator.rb):
   - Creates Vagrant configuration files
   - Generates Puppet manifests
   - Copies module files to project directory
   - Creates metadata and hint files

## Key Patterns and Conventions

### File Naming
- Ruby files use snake_case: `system_reader.rb`
- Class names use CamelCase: `SystemReader`
- XML files use snake_case: `default_scenario.xml`
- Module directories use plural nouns: `vulnerabilities/`, `services/`

### Error Handling
- Use `Print.err()` for error messages
- Use `Print.info()` for informational messages
- Use `Print.debug()` for debug output
- Always validate inputs and provide meaningful error messages

### Module Structure
Each module directory typically contains:
- `secgen_metadata.xml` - Module definition and capabilities
- `files/` - Static files to be copied to VM
- `templates/` - ERB templates for configuration files
- `manifests/` - Puppet manifests for installation
- `secgen_test/` - Post-provision test scripts

### XML Schema Validation
- All XML files are validated against XSD schemas in `lib/schemas/`
- Scenario files use `scenario_schema.xsd`
- Module metadata files use respective schema files
- Always validate XML before processing

## Important Rules for AI Agents

### 1. NEVER Modify Core Constants
- Do not change paths or constants in `lib/helpers/constants.rb`
- These values are used throughout the system
- Changes may break the entire build process

### 2. Preserve Module Interface
- Maintain compatibility with existing `secgen_metadata.xml` format
- Do not change required module attributes
- Preserve existing module selection logic

### 3. Error Recovery
- Always implement proper error handling
- Use the retry mechanism for transient failures
- Clean up failed VMs before retrying
- Log errors appropriately for debugging

### 4. Resource Management
- Respect memory and CPU limits specified in options
- Implement parallel processing where appropriate
- Clean up temporary files and resources
- Handle edge cases gracefully

### 5. Testing
- Create post-provision tests for new modules
- Test with multiple scenarios and configurations
- Validate on different platforms when possible
- Ensure tests are deterministic and reliable

## Common Tasks

### Adding a New Module Type
1. Create new directory under `modules/`
2. Update module reader to discover new modules
3. Add schema validation file
4. Update system object to handle new module type
5. Add tests and documentation

### Modifying Scenario Processing
1. Update XML schema if changing structure
2. Modify `SystemReader` to handle changes
3. Update system object logic
4. Test with various scenario files
5. Update documentation

### Adding Cloud Provider Support
1. Create helper in `lib/helpers/`
2. Add command-line options to `secgen.rb`
3. Implement provider-specific logic
4. Add post-build actions
5. Test with target platform

## Development Guidelines

### Code Style
- Follow Ruby conventions
- Use meaningful variable and method names
- Add comments for complex logic
- Keep methods focused and small

### Testing
- Write tests for new functionality
- Test edge cases and error conditions
- Validate with different scenarios
- Test on multiple platforms when possible

### Documentation
- Update README.md for user-facing changes
- Add inline comments for complex code
- Document new configuration options
- Update this file for architectural changes

## Security Considerations

- Never hardcode credentials or sensitive information
- Validate all user inputs
- Use secure temporary file handling
- Follow principle of least privilege
- Be aware of security implications of vulnerabilities

## Performance Considerations

- Optimize for large-scale builds
- Implement efficient file operations
- Use parallel processing where beneficial
- Cache expensive operations when possible
- Monitor resource usage

## Debugging Tips

- Use `Print.debug()` for debugging output
- Check generated project files in `projects/` directory
- Examine Vagrant logs for VM build issues
- Review Puppet manifests for configuration problems
- Use `--no-parallel` option for sequential debugging

## Common Issues and Solutions

### Module Resolution Failures
- Check module metadata XML syntax
- Validate against appropriate schema
- Ensure module dependencies are satisfied
- Verify module compatibility with scenario constraints

### VM Build Failures
- Check Vagrant and VirtualBox versions
- Verify base box availability
- Examine Puppet manifest syntax
- Review resource allocation

### Test Failures
- Verify test script permissions
- Check test dependencies
- Validate test assumptions
- Review VM state before tests

This guide should help AI agents understand the SecGen architecture and contribute effectively while maintaining system integrity and compatibility.