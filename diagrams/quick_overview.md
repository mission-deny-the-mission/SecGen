# SecGen Quick Overview - ASCII Architecture Diagram

┌─────────────────────────────────────────────────────────────────────────────┐
│                          SECGEN ARCHITECTURE                                │
│                      Security Scenario Generator                            │
└─────────────────────────────────────────────────────────────────────────────┘

                               ┌─────────────┐
                               │   INPUT     │
                               └─────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
            ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
            │  Scenarios  │  │   Modules   │  │   Options   │
            │   XML Files │  │ Directory   │  │   Command   │
            │             │  │             │  │    Line     │
            │ • Systems   │  │ • Vulns     │  │             │
            │ • Networks  │  │ • Services  │  │ • Memory    │
            │ • Constraints│  │ • Bases    │  │ • CPU       │
            └─────────────┘  └─────────────┘  └─────────────┘
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CORE PROCESSING LAYER                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
            ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
            │   Readers   │  │   Objects   │  │  Resolvers  │
            │             │  │             │  │             │
            │ • XML Parse │  │ • System    │  │ • Module    │
            │ • Validation│  │ • Module    │  │   Selection │
            │ • Load      │  │ • Conflict  │  │ • Randomize │
            │   Modules   │  │   Detection │  │ • Resolve   │
            └─────────────┘  └─────────────┘  └─────────────┘
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      OUTPUT GENERATION LAYER                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
            ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
            │  Project    │  │   Vagrant   │  │   Puppet    │
            │   Creator   │  │   Files     │  │   Config    │
            │             │  │             │  │             │
            │ • Directory │  │ • VM Config │  │ • Manifests │
            │ • Templates │  │ • Networks  │  │ • Modules   │
            │ • Metadata  │  │ • Resources │  │ • Services  │
            └─────────────┘  └─────────────┘  └─────────────┘
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VM BUILDING & DEPLOYMENT LAYER                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
            ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
            │   Vagrant   │  │    Tests    │  │    Cloud    │
            │   Engine    │  │             │  │  Providers  │
            │             │  │ • Vuln Tests│  │             │
            │ • Build VMs │  │ • Service   │  │ • oVirt     │
            │ • Provision │  │   Tests     │  │ • Proxmox   │
            │ • Configure │  │ • Functional│  │ • ESXi      │
            │ • Networks  │  │   Tests     │  │ • VBox      │
            └─────────────┘  └─────────────┘  └─────────────┘
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             FINAL OUTPUT                                   │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────┬─────────────────┬─────────────────┐
                    │   Virtual       │   Forensic      │      CTFd       │
                    │   Machines      │    Images       │   Platform      │
                    │                 │                 │                 │
                    │ • Vulnerable    │ • E01 Format    │ • Challenges    │
                    │   Systems       │ • Raw/DD        │ • Categories    │
                    │ • Randomized    │ • FTK Imager    │ • Flags         │
                    │   Scenarios     │                 │ • Hints         │
                    └─────────────────┴─────────────────┴─────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              KEY FEATURES                                   │
└─────────────────────────────────────────────────────────────────────────────┘

• Randomized Vulnerable Systems  • Multi-Cloud Support     • Automated Testing
• XML-Based Configuration        • Puppet Provisioning     • CTF Integration
• Modular Architecture           • Error Recovery          • Forensic Imaging
• Parallel VM Building           • Snapshot Management      • Educational Focus
• Conflict Resolution            • Resource Management      • Batch Processing

┌─────────────────────────────────────────────────────────────────────────────┐
│                           WORKFLOW SUMMARY                                  │
└─────────────────────────────────────────────────────────────────────────────┘

1. Parse Scenario XML → 2. Read Available Modules → 3. Resolve Module Selections
4. Generate Project Files → 5. Build VMs with Vagrant → 6. Run Post-Provision Tests
7. Create Snapshots/Images → 8. Deploy to Cloud (Optional) → 9. Complete

┌─────────────────────────────────────────────────────────────────────────────┐
│                              MODULE TYPES                                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ Vulnerabil- │ │  Services   │ │ Utilities   │ │ Generators  │ │  Encoders   │
│   ities     │ │             │ │             │ │             │ │             │
│             │ │ • FTP       │ │ • User Mgmt │ │ • Challenges│ │ • Base64    │
│ • Remote    │ │ • SSH       │ │ • Tools     │ │ • Flags     │ │ • Caesar    │
│ • Local     │ │ • Web       │ │ • Scripts   │ │ • Hints     │ │ • XOR       │
│ • Privilege │ │ • Database  │ │ • Packages  │ │ • Content   │ │ • Custom    │
│   Escalation│ │ • Email     │ │             │ │ • Stories   │ │             │
└─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘

┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│    Bases    │ │  Networks   │ │   Builds    │
│             │ │             │ │             │
│ • Debian    │ │ • Private   │ │ • Puppet    │
│ • Ubuntu    │ │ • Public    │ │ • Scripts   │
│ • CentOS    │ │ • DHCP      │ │ • Resources │
│ • Windows   │ │ • Static    │ │ • Templates │
│ • Custom    │ │ • VLANs     │ │             │
└─────────────┘ └─────────────┘ └─────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           COMMAND EXAMPLES                                  │
└─────────────────────────────────────────────────────────────────────────────┘

# Build default scenario
./secgen.rb run

# Build custom scenario with specific project directory
./secgen.rb --scenario scenarios/ctf/web_ctf.xml --project my_ctf run

# Build only project files (no VMs)
./secgen.rb build-project

# Build VMs from existing project
./secgen.rb --project projects/SecGen20240101_120000 build-vms

# Create forensic images
./secgen.rb create-forensic-image --forensic-image-type ewf

# List available scenarios and projects
./secgen.rb list-scenarios
./secgen.rb list-projects

# Cloud provider options
./secgen.rb --ovirt-url https://ovirt.example.com --ovirtuser admin run
./secgen.rb --proxmox-url https://proxmox.example.com run

┌─────────────────────────────────────────────────────────────────────────────┐
│                              USE CASES                                     │
└─────────────────────────────────────────────────────────────────────────────┘

• Security Education Labs    • Penetration Testing Training
• CTF Event Hosting          • Vulnerability Research
• Security Auditing          • Employee Training
• Cybersecurity Competitions • Academic Research
• Red Team Exercises         • Blue Team Training

Generated with SecGen v0.0.1.1 - Security Scenario Generator
For more details: https://github.com/cliffe/SecGen