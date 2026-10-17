# SecGen Build Process Flow Diagram

## Main Build Flow

```mermaid
flowchart TD
    Start([Start SecGen]) --> ParseArgs[Parse Command Line Arguments]
    ParseArgs --> ValidateArgs{Validate Arguments}
    ValidateArgs -->|Invalid| Usage[Show Usage & Exit]
    ValidateArgs -->|Valid| LoadScenario[Load Scenario XML]
    
    LoadScenario --> ReadModules[Read Available Modules]
    ReadModules --> ParseScenario[Parse Scenario with SystemReader]
    ParseScenario --> CreateSystems[Create System Objects]
    
    CreateSystems --> ResolveModules[Resolve Module Selections]
    ResolveModules --> GenerateProject[Generate Project Files]
    
    GenerateProject --> BuildVMs[Build VMs with Vagrant]
    BuildVMs --> TestsPass{Post-Provision Tests Pass?}
    
    TestsPass -->|No| CleanupVMs[Clean up Failed VMs]
    CleanupVMs --> RetryCheck{Retries Available?}
    RetryCheck -->|Yes| BuildVMs
    RetryCheck -->|No| ErrorExit[Exit with Error]
    
    TestsPass -->|Yes| PostBuildActions{Post-Build Actions?}
    PostBuildActions -->|Yes| CreateSnapshots[Create VM Snapshots]
    PostBuildActions -->|No| Complete[Build Complete]
    CreateSnapshots --> Complete
    
    subgraph "Command Options"
        Run[run: Full build]
        BuildProject[build-project: Config only]
        BuildVMsOnly[build-vms: VMs only]
        CreateImage[create-forensic-image: Forensic images]
        ListScenarios[list-scenarios]
        ListProjects[list-projects]
        DeleteProjects[delete-all-projects]
    end
```

## Module Resolution Flow

```mermaid
flowchart TD
    StartResolution([Module Resolution Start]) --> GetAvailable[Get All Available Modules]
    
    GetAvailable --> LoadVulns[Load Vulnerability Modules]
    GetAvailable --> LoadServices[Load Service Modules]
    GetAvailable --> LoadUtilities[Load Utility Modules]
    GetAvailable --> LoadBases[Load Base Modules]
    GetAvailable --> LoadGenerators[Load Generator Modules]
    GetAvailable --> LoadEncoders[Load Encoder Modules]
    
    LoadVulns --> FilterVulns[Filter by Scenario Constraints]
    LoadServices --> FilterServices[Filter by Scenario Constraints]
    LoadUtilities --> FilterUtilities[Filter by Scenario Constraints]
    LoadBases --> FilterBases[Filter by Scenario Constraints]
    LoadGenerators --> FilterGenerators[Filter by Scenario Constraints]
    LoadEncoders --> FilterEncoders[Filter by Scenario Constraints]
    
    FilterVulns --> RandomSelectVuln[Random Selection]
    FilterServices --> RandomSelectService[Random Selection]
    FilterUtilities --> RandomSelectUtility[Random Selection]
    FilterBases --> RandomSelectBase[Random Selection]
    FilterGenerators --> RandomSelectGenerator[Random Selection]
    FilterEncoders --> RandomSelectEncoder[Random Selection]
    
    RandomSelectVuln --> CheckConflicts[Check Module Conflicts]
    RandomSelectService --> CheckConflicts
    RandomSelectUtility --> CheckConflicts
    RandomSelectBase --> CheckConflicts
    RandomSelectGenerator --> CheckConflicts
    RandomSelectEncoder --> CheckConflicts
    
    CheckConflicts -->|No Conflicts| BuildSystem[Build System Configuration]
    CheckConflicts -->|Conflicts Found| ResolveConflict[Resolve Conflicts]
    ResolveConflict --> CheckConflicts
    
    BuildSystem --> CompleteResolution[Resolution Complete]
```

## Project Generation Flow

```mermaid
flowchart TD
    StartGen([Project Generation Start]) --> CreateProjectDir[Create Project Directory]
    
    CreateProjectDir --> GenerateVagrant[Generate Vagrantfile]
    GenerateVagrant --> GeneratePuppet[Generate Puppet Configuration]
    
    GeneratePuppet --> ProcessModules[Process Selected Modules]
    ProcessModules --> ValidateModules[Validate Module Dependencies]
    
    ValidateModules --> GenerateManifests[Generate Puppet Manifests]
    GenerateManifests --> CopyModuleFiles[Copy Module Files to Project]
    
    CopyModuleFiles --> GenerateMetadata[Generate Metadata Files]
    GenerateMetadata --> GenerateFlags[Create Flag Hints File]
    GenerateMetadata --> GenerateIPs[Create IP Addresses File]
    GenerateMetadata --> GenerateCyBOK[Create CyBOK Mapping]
    
    GenerateFlags --> GenerateCTFd[Generate CTFd Config - Optional]
    GenerateIPs --> GenerateCTFd
    GenerateCyBOK --> GenerateCTFd
    
    GenerateCTFd --> ProjectComplete[Project Generation Complete]
    
    subgraph "Generated Files"
        VagrantFile[Vagrantfile]
        PuppetFile[Puppetfile]
        Manifests[Site Manifests]
        Modules[Puppet Modules]
        Metadata[flag_hints.xml]
        IPFile[IP_addresses.json]
        CyBOKFile[cybok.xml]
        CTFdConfig[CTFd Configuration]
    end
```

## VM Build & Test Flow

```mermaid
flowchart TD
    StartBuild([VM Build Start]) --> VagrantUp[vagrant up]
    
    VagrantUp --> ParallelBuild{Parallel Build?}
    ParallelBuild -->|Yes| BuildParallel[Build VMs in Parallel]
    ParallelBuild -->|No| BuildSequential[Build VMs Sequentially]
    
    BuildParallel --> MonitorBuild[Monitor Build Progress]
    BuildSequential --> MonitorBuild
    
    MonitorBuild --> BuildSuccess{Build Successful?}
    BuildSuccess -->|No| IdentifyFailures[Identify Failed VMs]
    
    IdentifyFailures --> DestroyFailed[Destroy Failed VMs]
    DestroyFailed --> RetryAvailable{Retry Available?}
    RetryAvailable -->|Yes| VagrantUp
    RetryAvailable -->|No| BuildFailed[Build Failed]
    
    BuildSuccess -->|Yes| ShutdownVMs[Shutdown VMs if Required]
    ShutdownVMs --> RebootCycle[Reboot for Tests]
    
    RebootCycle --> RunTests[Run Post-Provision Tests]
    RunTests --> TestsResult{Tests Pass?}
    
    TestsResult -->|No| TestFailed[Tests Failed]
    TestsResult -->|Yes| TestSuccess[Tests Successful]
    
    TestSuccess --> CloudActions{Cloud Provider Actions?}
    CloudActions -->|oVirt| OVirtActions[oVirt Post-Build]
    CloudActions -->|Proxmox| ProxmoxActions[Proxmox Post-Build]
    CloudActions -->|VirtualBox| VBoxActions[VirtualBox Actions]
    CloudActions -->|None| BuildComplete[Build Complete]
    
    OVirtActions --> BuildComplete
    ProxmoxActions --> BuildComplete
    VBoxActions --> BuildComplete
    
    subgraph "Test Categories"
        VulnTests[Vulnerability Tests]
        ServiceTests[Service Tests]
        FunctionalTests[Functional Tests]
        NetworkTests[Network Tests]
    end
```

## Cloud Provider Integration Flow

```mermaid
flowchart TD
    StartCloud([Cloud Provider Start]) --> ProviderCheck{Provider Type?}
    
    ProviderCheck -->|VirtualBox| VBoxFlow[VirtualBox Flow]
    ProviderCheck -->|oVirt| OVirtFlow[oVirt Flow]
    ProviderCheck -->|Proxmox| ProxmoxFlow[Proxmox Flow]
    ProviderCheck -->|ESXi| ESXiFlow[ESXi Flow]
    
    VBoxFlow --> VBoxBuild[Local VirtualBox Build]
    VBoxBuild --> VBoxSnapshot[Local Snapshots]
    
    OVirtFlow --> OVirtAuth[Authenticate to oVirt]
    OVirtAuth --> OVirtBuild[Deploy to oVirt Cluster]
    OVirtBuild --> OVirtNetwork[Configure Networks]
    OVirtNetwork --> OVirtAffinity[Set Affinity Groups]
    OVirtAffinity --> OVirtSnapshot[oVirt Snapshots]
    
    ProxmoxFlow --> ProxmoxAuth[Authenticate to Proxmox]
    ProxmoxAuth --> ProxmoxBuild[Deploy to Proxmox Node]
    ProxmoxBuild --> ProxmoxNetwork[Configure Networks/VLANs]
    ProxmoxNetwork --> ProxmoxSnapshot[Proxmox Snapshots]
    
    ESXiFlow --> ESXiAuth[Authenticate to ESXi]
    ESXiAuth --> ESXiBuild[Deploy to ESXi Host]
    ESXiBuild --> ESXiConfig[Configure ESXi Settings]
    ESXiConfig --> ESXiComplete[ESXi Build Complete]
    
    VBoxSnapshot --> CloudComplete[Cloud Build Complete]
    OVirtSnapshot --> CloudComplete
    ProxmoxSnapshot --> CloudComplete
    ESXiComplete --> CloudComplete
```

## Forensic Image Generation Flow

```mermaid
flowchart TD
    StartForensic([Forensic Image Start]) --> ShutdownAll[Shutdown All VMs]
    
    ShutdownAll --> GetDiskPath[Get Virtual Disk Path]
    GetDiskPath --> ImageType{Image Type?}
    
    ImageType -->|Raw/DD| CreateRaw[Create Raw Image]
    ImageType -->|EWF/E01| CreateEWF[Create EWF Image]
    
    CreateRaw --> VBoxManage[VBoxManage clonemedium]
    VBoxManage --> RawComplete[Raw Image Complete]
    
    CreateEWF --> FTKImager[FTK Imager]
    FTKImager --> EWFComplete[EWF Image Complete]
    
    RawComplete --> DeleteVMs[Delete VirtualBox VMs]
    EWFComplete --> DeleteVMs
    
    DeleteVMs --> ForensicComplete[Forensic Image Complete]
    
    subgraph "Image Formats"
        Raw[.raw - DD format]
        EWF[.E01 - EnCase format]
    end
    
    subgraph "Tools Used"
        VBox[VBoxManage]
        FTK[FTK Imager]
    end
```

## Error Handling & Recovery Flow

```mermaid
flowchart TD
    StartError([Error Handling Start]) --> DetectError[Error Detected]
    
    DetectError --> ErrorType{Error Type?}
    ErrorType -->|Build Error| BuildError[VM Build Error]
    ErrorType -->|Test Error| TestError[Test Execution Error]
    ErrorType -->|Config Error| ConfigError[Configuration Error]
    
    BuildError --> LogError[Log Error Details]
    LogError --> CheckNoDestroy{No-Destroy Flag?}
    CheckNoDestroy -->|Yes| PreserveVMs[Preserve Failed VMs]
    CheckNoDestroy -->|No| CleanupFailed[Clean Up Failed VMs]
    
    TestError --> LogTestError[Log Test Error]
    LogTestError --> CheckRetry{Retry Available?}
    CheckRetry -->|Yes| RebuildVM[Rebuild VM]
    CheckRetry -->|No| TestFail[Tests Failed]
    
    ConfigError --> LogConfigError[Log Config Error]
    LogConfigError --> ValidateConfig[Validate Configuration]
    ValidateConfig --> FixConfig[Fix Configuration Issues]
    
    PreserveVMs --> ManualIntervention[Manual Intervention Required]
    CleanupFailed --> RetryBuild[Retry Build Process]
    RebuildVM --> RetryBuild
    FixConfig --> RetryBuild
    
    RetryBuild --> RetryCountCheck{Retry Count Available?}
    RetryCountCheck -->|Yes| RetryProcess[Retry Process]
    RetryCountCheck -->|No| FinalFailure[Final Failure]
    
    RetryProcess --> Success{Retry Successful?}
    Success -->|Yes| RecoveryComplete[Recovery Complete]
    Success -->|No| StartError
```

## Key Configuration Points

### Scenario Configuration
- **XML Schema Validation**: Ensures scenario files conform to defined structure
- **System Definitions**: Specify base OS, vulnerabilities, services, networks
- **Constraint Resolution**: Matches requirements with available modules
- **Conflict Detection**: Identifies and resolves module conflicts

### Module Selection
- **Randomization**: Ensures unique scenarios each run
- **Filtering**: Applies scenario constraints to module pool
- **Dependency Resolution**: Handles module dependencies and conflicts
- **Resource Allocation**: Manages memory, CPU, disk resources

### Build Optimization
- **Parallel Processing**: Builds multiple VMs simultaneously
- **Retry Mechanism**: Handles transient failures
- **Resource Management**: Controls memory and CPU usage
- **Error Recovery**: Graceful handling of build failures

### Testing Framework
- **Automated Testing**: Validates vulnerabilities and services
- **Functional Verification**: Ensures systems behave as expected
- **Network Testing**: Verifies connectivity and service availability
- **Security Validation**: Confirms exploitability of vulnerabilities
```

## Architecture Summary

SecGen follows a **pipeline architecture pattern** with these key stages:

1. **Input Processing**: Parse scenarios and modules
2. **Resolution**: Map requirements to specific modules
3. **Generation**: Create project files and configurations
4. **Provisioning**: Build and configure VMs
5. **Validation**: Test and verify systems
6. **Deployment**: Optional cloud deployment and snapshots

The system emphasizes **randomization**, **modularity**, and **automation** to create diverse security scenarios for education and training purposes.