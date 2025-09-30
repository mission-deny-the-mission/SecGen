# SecGen Architecture Diagram

## Overview
SecGen (Security Scenario Generator) is a Ruby-based tool that creates randomized vulnerable virtual machines for security education and CTF events. The system uses XML scenarios, Puppet for configuration management, and Vagrant for VM provisioning.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                   SecGen System                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────────────────┐   │
│  │   Input     │    │   Processing │    │            Output               │   │
│  │             │    │              │    │                                 │   │
│  │ ┌─────────┐ │    │ ┌──────────┐ │    │ ┌─────────────┐  ┌────────────┐ │   │
│  │ │Scenarios│ │    │ │Scenario  │ │    │ │ Project     │  │    VMs     │ │   │
│  │ │  XML    │ └────►│  Reader   │ └────►│   Files     │  │ (Vagrant)  │ │   │
│  │ └─────────┘ │    │ └──────────┘ │    │ └─────────────┘  └────────────┘ │   │
│  │             │    │              │    │                                 │   │
│  │ ┌─────────┐ │    │ ┌──────────┐ │    │ ┌─────────────┐  ┌────────────┐ │   │
│  │ │Modules  │ │    │ │Module    │ │    │ │Forensic     │  │   CTFd     │ │   │
│  │ │ Directory│ └────►│ Resolver  │ └────► │   Images    │  │ Platform   │ │   │
│  │ └─────────┘ │    │ └──────────┘ │    │ └─────────────┘  └────────────┘ │   │
│  └─────────────┘    └──────────────┘    └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Detailed Component Architecture

### 1. Main Entry Point (secgen.rb)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          secgen.rb                                │
│                        (Main Controller)                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │   Command Line  │  │   Argument      │  │   Command       │    │
│  │   Parser        │  │   Processing    │  │   Dispatcher    │    │
│  │                 │  │                 │  │                 │    │
│  │ • --scenario    │  │ • Validate      │  │ • run           │    │
│  │ • --project     │  │ • Set defaults  │  │ • build-project │    │
│  │ • --memory      │  │ • Store options │  │ • build-vms     │    │
│  │ • --retries     │  │ • Cloud config  │  │ • create-image  │    │
│  │ • --snapshot    │  │                 │  │ • list-*        │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Core Workflow                             │    │
│  │                                                             │    │
│  │ 1. Parse arguments → 2. Read scenario → 3. Resolve modules │    │
│  │ 4. Generate project → 5. Build VMs → 6. Post-provision      │    │
│  │                                                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### 2. Input Layer

```
┌─────────────────────────────────────────────────────────────────────┐
│                              Input Layer                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐              ┌─────────────────────────────┐  │
│  │   Scenarios     │              │         Modules              │  │
│  │                 │              │                             │  │
│  │ • XML Files     │              │ ┌─────────┐ ┌─────────────┐ │  │
│  │ • System defs   │              │ │Vulnerab-│ │   Services  │ │  │
│  │ • Constraints   │              │ │ilities  │ │             │ │  │
│  │ • Networks      │              │ └─────────┘ └─────────────┘ │  │
│  │                 │              │ ┌─────────┐ ┌─────────────┐ │  │
│  │ Example:        │              │ │Bases    │ │Utilities   │ │  │
│  │ <system>        │              │ └─────────┘ └─────────────┘ │  │
│  │   <base/>       │              │ ┌─────────┐ ┌─────────────┐ │  │
│  │   <vuln/>       │              │ │Genera-  │ │   Encoders  │ │  │
│  │   <service/>    │              │ │tors     │ │             │ │  │
│  │   <network/>    │              │ └─────────┘ └─────────────┘ │  │
│  │ </system>       │              │ ┌─────────┐ ┌─────────────┐ │  │
│  └─────────────────┘              │ │Networks │ │    Builds   │ │  │
│                                    │ └─────────┘ └─────────────┘ │  │
│                                    └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 3. Core Processing Layer

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Core Processing Layer                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                      Readers                               │    │
│  │                                                             │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │    │
│  │ │ System      │ │ Module      │ │ XML                     │ │    │
│  │ │ Reader      │ │ Reader      │ │ Reader                  │ │    │
│  │ │             │ │             │ │                         │ │    │
│  │ • Parse XML   │ • Scan dirs   │ • XML Schema validation   │ │    │
│  │ • Create      │ • Load        │ • Nori parsing            │ │    │
│  │   System objs │   metadata    │ • Error handling          │ │    │
│  │ • Validate    │ • Categorize  │                         │ │    │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │    │
│                                                                 │    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Objects & Models                        │    │
│  │                                                             │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │    │
│  │ │ System      │ │ Module      │ │ Post Provision          │ │    │
│  │ │ Object      │ │ Object      │ │ Tests                   │ │    │
│  │ │             │ │             │ │                         │ │    │
│  │ • Properties  │ • Metadata   │ • Test execution          │ │    │
│  │ • Module      │ • Validation │ • Result validation       │ │    │
│  │   selections  │ • Dependencies│ • Error reporting         │ │    │
│  │ • Conflict    │ • Resources  │                         │ │    │
│  │   resolution  │             │                         │ │    │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │    │
└─────────────────────────────────────────────────────────────────────┘
```

### 4. Output Generation Layer

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Output Generation Layer                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Project Files Creator                        │    │
│  │                                                             │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │    │
│  │ │ Vagrantfile │ │ Puppet      │ │ Additional              │ │    │
│  │ │ Generation  │ │ Manifests   │ │ Files                   │ │    │
│  │ │             │ │             │ │                         │ │    │
│  │ • VM configs  │ • Module      │ • Flag hints             │ │    │
│  │ • Network     │   manifests  │ • IP addresses            │ │    │
│  │ • Resources   │ • Services    │ • CyBOK mapping          │ │    │
│  │ • Cloud prov. │ • Vulnerab.   │ • Admin passwords        │ │    │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │    │
│                                                                 │    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Specialized Generators                      │    │
│  │                                                             │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │    │
│  │ │ CTFd        │ │ Forensic    │ │ XML/Metadata            │ │    │
│  │ │ Generator   │ │ Image       │ │ Generators              │ │    │
│  │ │             │ │ Creator     │ │                         │ │    │
│  │ • Challenges  │ • E01 format  │ • Scenario XML           │ │    │
│  │ • Categories  │ • Raw format  │ • CyBOK mapping          │ │    │
│  │ • Flags       │ • VBoxManage  │ • Marker files           │ │    │
│  │ • Hints       │ • Automation  │                         │ │    │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │    │
└─────────────────────────────────────────────────────────────────────┘
```

### 5. VM Building & Deployment

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VM Building & Deployment                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     Vagrant Engine                          │    │
│  │                                                             │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │    │
│  │ │ VM Creation │ │ Provision   │ │ Error Handling          │ │    │
│  │ │             │ │             │ │                         │ │    │
│  │ • vagrant up  │ • Puppet      │ • Retry mechanism        │ │    │
│  │ • Parallel    │   apply      │ • Failed VM cleanup      │ │    │
│  │ • GUI/Headless│ • Service     │ • Logging                │ │    │
│  │ • Resource    │   config     │ • Status reporting        │ │    │
│  │   allocation  │ • Vulnerab.   │                         │ │    │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │    │
│                                                                 │    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Cloud Providers                             │    │
│  │                                                             │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │    │
│  │ │ oVirt       │ │ Proxmox     │ │ ESXi                    │ │    │
│  │ │             │ │             │ │                         │    │
│  │ • API calls   │ • API calls   │ • PowerCLI                │ │    │
│  │ • Snapshots   │ • Snapshots   │ • VM templates            │ │    │
│  │ • Networks    │ • Networks    │ • Datastores              │ │    │
│  │ • Affinity    │ • VLANs       │ • Network configs         │ │    │
│  │   groups      │ • Clusters    │ • Guest NIC types         │ │    │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │    │
└─────────────────────────────────────────────────────────────────────┘
```

### 6. Testing & Validation

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Testing & Validation                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Post-Provision Tests                       │    │
│  │                                                             │    │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │    │
│  │ │ Vulnerab.   │ │ Service     │ │ Functional              │ │    │
│  │ │ Tests       │ │ Tests       │ │ Tests                   │ │    │
│  │ │             │ │             │ │                         │ │    │
│  │ • Exploit     │ • Port       │ • User accounts           │ │    │
│  │   validation │   checks     │ • File permissions        │ │    │
│  │ • Access      │ • Service    │ • Network connectivity    │ │    │
│  │   levels     │   status     │ • Service functionality    │ │    │
│  │ • Privilege   │ • Protocol   │                         │ │    │
│  │   escalation │   validation │                         │ │    │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │    │
│                                                                 │    │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Test Execution                           │    │
│  │                                                             │    │
│  │ • VM reboot cycle                                            │    │
│  │ • Ruby test scripts (secgen_test/*.rb)                      │    │
│  │ • Parallel test execution                                    │    │
│  │ • Result aggregation                                         │    │
│  │ • Pass/fail reporting                                        │    │
│  │ • Optional test skipping (--no-tests)                        │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Scenario  │    │   Module    │    │   System    │    │   Project   │
│   XML File  │───▶│   Reader    │───▶│   Object    │───▶│   Files     │
│             │    │             │    │             │    │   Creator   │
│ • Systems   │    │ • Parse XML │    │ • Resolve   │    │             │
│ • Constraints│    │ • Load      │    │   modules   │    │ • Vagrant   │
│ • Networks  │    │   modules   │    │ • Handle    │    │   files     │
│             │    │ • Validate  │    │   conflicts │    │ • Puppet    │
└─────────────┘    └─────────────┘    └─────────────┘    │   manifests │
                                                     └─────────────┘
                                                              │
                                                              ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    VMs      │    │    Tests    │    │  Snapshots  │    │  Forensic   │
│ (Vagrant)   │◀───│  Execution  │◀───│   Creation  │◀───│   Images    │
│             │    │             │    │             │    │             │
│ • Build     │    │ • Reboot    │    │ • VBox      │    │ • E01 format│
│ • Provision │    │ • Validate  │    │ • oVirt     │    │ • Raw format│
│ • Configure │    │ • Report    │    │ • Proxmox   │    │ • FTK Imager│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Key Design Patterns

### 1. Module Resolution Pattern
```
Scenario Constraints → Module Filters → Available Modules → Random Selection
```

### 2. Template Generation Pattern
``
