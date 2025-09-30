# SecGen Architecture Documentation

## Overview

SecGen (Security Scenario Generator) is a sophisticated Ruby-based system designed to create randomized vulnerable virtual machines for security education, penetration testing training, and Capture The Flag (CTF) events. The system leverages XML-based configuration, Puppet for configuration management, and Vagrant for VM provisioning to generate diverse security scenarios.

## System Architecture

### Core Components

1. **Main Controller (`secgen.rb`)**
   - Entry point and orchestrator of the entire system
   - Handles command-line argument parsing and validation
   - Manages the build workflow and error handling
   - Supports multiple cloud providers (VirtualBox, oVirt, Proxmox, ESXi)

2. **Input Layer**
   - **Scenarios**: XML files defining system requirements, constraints, and network configurations
   - **Modules**: Directory structure containing vulnerabilities, services, utilities, generators, and base images
   - **Configuration**: Command-line options and configuration files

3. **Processing Layer**
   - **Readers**: Parse XML scenarios and module metadata
   - **Objects**: System and module data models with conflict resolution
   - **Resolvers**: Map scenario requirements to specific modules

4. **Generation Layer**
   - **Project Files Creator**: Generates Vagrant and Puppet configurations
   - **Specialized Generators**: Creates CTFd configs, forensic images, and metadata

5. **Deployment Layer**
   - **Vagrant Engine**: Builds and provisions virtual machines
   - **Cloud Providers**: Integrates with oVirt, Proxmox, and ESXi
   - **Testing Framework**: Validates built systems

## Build Process Flow

### 1. Initialization Phase
```
Parse command line arguments → Validate options → Load scenario XML → Read available modules
```

### 2. Resolution Phase
```
Parse scenario constraints → Filter available modules → Randomly select modules → Resolve conflicts → Create system objects
```

### 3. Generation Phase
```
Create project directory → Generate Vagrantfile → Create Puppet manifests → Copy module files → Generate metadata files
```

### 4. Building Phase
```
Vagrant up → Provision with Puppet → Run post-provision tests → Handle failures with retry mechanism → Create snapshots
```

### 5. Deployment Phase
```
Cloud provider actions → Network configuration → Snapshot creation → Forensic image generation (optional)
```

## Module System Architecture

### Module Categories

- **Vulnerabilities**: Exploitable security flaws with varying privilege levels
- **Services**: Network services and applications to be deployed
- **Utilities**: Helper tools and system utilities
- **Generators**: Content creation tools (challenges, flags, hints)
- **Encoders**: Data encoding and transformation utilities
- **Bases**: Base operating system images
- **Networks**: Network configuration modules

### Module Resolution Strategy

1. **Constraint Matching**: Filter modules based on scenario requirements
2. **Random Selection**: Ensure uniqueness across builds
3. **Conflict Detection**: Identify incompatible module combinations
4. **Dependency Resolution**: Handle module prerequisites
5. **Resource Allocation**: Manage memory, CPU, and disk resources

## Key Design Patterns

### 1. Pipeline Architecture
The system follows a linear processing pipeline where each stage transforms data and passes it to the next stage.

### 2. Module Resolution Pattern
```
Scenario Constraints → Module Filters → Available Modules → Random Selection → Conflict Resolution
```

### 3. Template Generation Pattern
```
System Configuration → Template Processing → File Generation → Output Files
```

### 4. Error Recovery Pattern
```
Error Detection → Logging → Cleanup → Retry Mechanism → Fallback Handling
```

## Configuration Management

### Scenario Configuration
- **XML Schema Validation**: Ensures structural integrity
- **System Definitions**: Specify base OS, vulnerabilities, services
- **Network Configuration**: Define network topology and ranges
- **Resource Constraints**: Control memory, CPU, and disk allocation

### Module Configuration
- **Metadata Files**: XML files describing module capabilities
- **Validation**: Schema-based validation of module definitions
- **Dependency Management**: Handle inter-module dependencies
- **Resource Requirements**: Specify system resource needs

## Cloud Provider Integration

### Supported Providers
1. **VirtualBox**: Local development and testing
2. **oVirt**: Enterprise virtualization platform
3. **Proxmox**: Open-source virtualization solution
4. **ESXi**: VMware enterprise hypervisor

### Provider-Specific Features
- **Network Configuration**: VLANs, private networks, DHCP ranges
- **Resource Management**: Memory allocation, CPU cores, disk types
- **Snapshot Management**: Automated snapshot creation
- **High Availability**: Cluster integration and affinity groups

## Testing and Validation

### Post-Provision Testing
- **Vulnerability Validation**: Verify exploitability of vulnerabilities
- **Service Testing**: Confirm service availability and functionality
- **Network Testing**: Validate network connectivity and configuration
- **Functional Testing**: Ensure overall system functionality

### Test Execution
- **Automated Test Scripts**: Ruby-based test framework
- **Parallel Execution**: Run tests across multiple VMs simultaneously
- **Result Aggregation**: Collect and report test results
- **Error Reporting**: Detailed failure reporting and logging

## Error Handling and Recovery

### Failure Scenarios
1. **Build Failures**: VM creation or provisioning errors
2. **Test Failures**: Post-provision validation failures
3. **Configuration Errors**: Invalid scenario or module configurations
4. **Resource Exhaustion**: Memory, CPU, or disk limitations

### Recovery Mechanisms
- **Retry Logic**: Automatic retry with configurable limits
- **Failed VM Cleanup**: Remove partially built VMs
- **Resource Reallocation**: Adjust resource allocation
- **Graceful Degradation**: Continue with partial success when possible

## Output Generation

### Primary Outputs
- **Virtual Machines**: Fully provisioned vulnerable systems
- **Project Files**: Vagrant and Puppet configurations
- **Metadata**: Flag hints, IP addresses, CyBOK mappings
- **CTFd Configuration**: Challenge platform integration

### Optional Outputs
- **Forensic Images**: E01 and raw disk images
- **Documentation**: Auto-generated scenario documentation
- **Network Diagrams**: Visual network topology representations

## Security Considerations

### Isolation
- **Network Segmentation**: Separate VMs into appropriate network segments
- **Resource Limits**: Prevent resource exhaustion attacks
- **Access Control**: Restrict VM access and permissions

### Vulnerability Management
- **Controlled Environment**: Deploy vulnerabilities in isolated lab environments
- **Educational Focus**: Designed for learning and training purposes
- **Responsible Disclosure**: Follow ethical disclosure practices

## Performance Optimization

### Build Optimization
- **Parallel Processing**: Build multiple VMs simultaneously
- **Resource Management**: Optimize memory and CPU usage
- **Caching**: Cache module dependencies and resources
- **Incremental Builds**: Reuse successful components when possible

### Scalability
- **Batch Processing**: Support for building multiple scenarios
- **Cloud Integration**: Scale to enterprise virtualization platforms
- **Resource Pooling**: Efficient resource utilization across builds

## Future Extensibility

### Modular Architecture
- **Plugin System**: Support for custom module types
- **Provider Expansion**: Easy addition of new cloud providers
- **Template System**: Customizable output templates
- **API Integration**: RESTful API for external integration

### Enhancement Opportunities
- **Web Interface**: Browser-based scenario management
- **Real-time Monitoring**: Build progress and system health monitoring
- **Advanced Analytics**: Usage statistics and learning analytics
- **Collaboration Features**: Multi-user scenario development

## Conclusion

SecGen represents a comprehensive solution for generating randomized security scenarios with a robust architecture that emphasizes modularity, automation, and educational value. The system's pipeline architecture, combined with its sophisticated module resolution system and multi-cloud support, makes it an invaluable tool for security education and training programs.

The architecture successfully balances complexity with usability, providing powerful customization options while maintaining an intuitive workflow for users. Its emphasis on randomization ensures that each build produces unique scenarios, making it ideal for educational environments where plagiarism prevention and skill assessment are important considerations.