# Hackerbot LLM Knowledge Enhancement PRD

**Version**: v2.0
**Date**: 2025-10-22
**Type**: LLM Knowledge Enhancement (Two-Phase Implementation)
**Status**: Updated

---

## Table of Contents

1. [Intro Project Analysis and Context](#1-intro-project-analysis-and-context)
2. [Requirements](#2-requirements)
3. [Technical Constraints and Integration Requirements](#3-technical-constraints-and-integration-requirements)
4. [Epic and Story Structure](#4-epic-and-story-structure)
5. [Epic 1: LLM Feature Stabilization](#5-epic-1-llm-feature-stabilization)

---

## 1. Intro Project Analysis and Context

### 1.1 Analysis Source

**Analysis Source**: IDE-based fresh analysis + existing documentation review

Analyzed documentation:
- README.md - Comprehensive project overview
- docs/development/architecture.md - Detailed architecture documentation
- docs/development/RAG_CAG_IMPLEMENTATION_SUMMARY.md - LLM feature documentation
- AGENTS.md - Development guide
- Core codebase structure and configuration

### 1.2 Current Project State

**Hackerbot** is a Ruby-based IRC bot framework designed for cybersecurity training exercises. It combines traditional attack simulation with modern AI capabilities.

**Current Functionality**:
- **LLM Integration**: Multiple provider support (Ollama, OpenAI, VLLM, SGLang) with streaming responses and per-user chat history
- **RAG System**: Retrieval-Augmented Generation using vector database for document retrieval and semantic search (functional and validated)
- **CAG System**: **REMOVED** - decision made to go RAG-only for maintainability (Epic 2 will implement CAG from scratch)
- **Knowledge Bases**: MITRE ATT&CK framework, man pages, markdown files
- **Training Scenarios**: Progressive attack simulation with dynamic bot personalities
- **Deployment**: Service-based operation with offline/air-gapped support

**Primary Purpose**: Educational cybersecurity training platform providing realistic, AI-powered attack and defense scenarios in controlled lab environments

### 1.3 Available Documentation

**Existing Documentation Quality**: ✅ Excellent

**Available Documentation**:
- ✅ Tech Stack Documentation (README.md, AGENTS.md)
- ✅ Source Tree/Architecture (docs/development/architecture.md - comprehensive)
- ✅ API Documentation (docs/development/api-reference.md)
- ✅ Technical Implementation Summaries (RAG/CAG, multi-personality features)
- ✅ User Guides (configuration, deployment, user manual)
- ✅ Development Guide (docs/development/development-guide.md)
- ⚠️ UX/UI Guidelines (N/A - CLI/IRC interface)
- ⚠️ Technical Debt Documentation (implicit in code, not formally documented)

**Assessment**: No need to run document-project task - existing documentation is comprehensive and well-maintained.

### 1.4 Enhancement Scope Definition

**Enhancement Type**:
- ☑ **System Validation and Optimization** (PRIMARY - Epic 1)
- ☑ **New Feature Implementation** (Epic 2 - CAG system from scratch)
- ☑ **Performance/Scalability Improvements** (Both epics include performance work)

**Enhancement Description**:

This PRD documents two-phase enhancement of the Hackerbot LLM knowledge enhancement capabilities:

**Phase 1 (Epic 1)**: Validate and optimize the existing RAG system for production deployment. The CAG system was removed due to complexity and maintainability concerns, leaving RAG as the primary knowledge enhancement approach. This phase focuses on comprehensive testing, performance validation, and optimization of the RAG system to ensure it's production-ready for SecGen integration.

**Phase 2 (Epic 2)**: Implement a modern Cache-Augmented Generation (CAG) system from scratch based on current research. This new implementation will pre-load knowledge into long-context LLM windows with KV cache precomputation, offering faster response times as an alternative to RAG. Epic 2 depends on Epic 1 completion and will provide both standalone CAG capability and hybrid CAG-RAG routing.

**Impact Assessment**:
- ☑ **Significant Impact**
  - Epic 1: Comprehensive RAG system validation and optimization
  - Epic 2: Complete new CAG system implementation from scratch
  - Testing infrastructure expansion for both systems
  - Performance benchmarking between RAG and new CAG approach
  - Hybrid system development for intelligent routing
  - Core IRC bot functionality unaffected

### 1.5 Goals and Background Context

**Goals**:

**Epic 1 Goals**:
- Validate and optimize the RAG system for production deployment
- Create comprehensive test suite for RAG system with ≥80% coverage
- Establish performance baselines and implement optimizations
- Ensure RAG system meets all requirements for SecGen integration
- Document RAG-only architectural decision and rationale

**Epic 2 Goals**:
- Implement modern Cache-Augmented Generation system from scratch
- Create CAG system based on current research (KV cache precomputation)
- Develop hybrid CAG-RAG routing system for optimal performance
- Validate CAG performance improvements over RAG (target: 50-80% latency reduction)
- Provide alternative knowledge enhancement approach for specific use cases

**Overall Project Goals**:
- Validate at least one production-ready knowledge enhancement system
- Provide both RAG and CAG options for different use cases
- Establish comprehensive performance metrics and baselines
- Enable intelligent routing between RAG and CAG based on query characteristics
- Complete SecGen integration with robust LLM knowledge enhancement

**Background Context**:

The Hackerbot project originally implemented both RAG (Retrieval-Augmented Generation) and CAG (Cache-Augmented Generation) systems as alternative LLM knowledge enhancement approaches. However, after evaluation, the CAG system was removed due to complexity and maintainability concerns, leaving RAG as the primary functional system.

**Current State**: The RAG system is operational and provides semantic document retrieval using vector embeddings and similarity search. However, it requires comprehensive validation, testing, and optimization to ensure it's production-ready for SecGen integration.

**Modern CAG Research**: Recent advances in CAG technology have shown that pre-loading knowledge into long-context LLM windows with KV cache precomputation can provide significant performance advantages (50-80% latency reduction) over traditional RAG approaches. This new implementation approach eliminates the need for complex knowledge graphs and focuses on efficient cache management.

**Two-Phase Approach**: 
1. **Epic 1** validates and optimizes the existing RAG system, ensuring it meets production requirements
2. **Epic 2** implements a modern CAG system from scratch based on current research, providing both an alternative approach and hybrid routing capabilities

This enhancement strategy ensures Hackerbot has robust LLM knowledge enhancement capabilities while exploring cutting-edge approaches for optimal performance in cybersecurity training scenarios. The RAG system provides a proven baseline, while the new CAG implementation offers performance advantages for specific use cases.

### 1.6 Change Log

| Change | Date | Version | Description | Author |
|--------|------|---------|-------------|--------|
| Initial PRD Creation | 2025-10-17 | v1.0 | Brownfield PRD for LLM Feature Stabilization | PM Agent |
| Corrected CAG Definition | 2025-10-17 | v1.0 | Fixed CAG = Cache-Augmented Generation | PM Agent |
| Updated for CAG Removal & Epic 2 | 2025-10-22 | v2.0 | Updated PRD to reflect CAG removal and Epic 2 creation | Product Owner Agent |

---

## 2. Requirements

### 2.1 Functional Requirements

**Epic 1 Requirements (RAG System Validation)**:

**FR1**: The RAG system shall have comprehensive test coverage (≥80%) validating document retrieval accuracy and relevance.

**FR2**: The RAG system shall meet performance requirements for production deployment (≤5s query response time).

**FR3**: The system shall provide performance validation metrics for RAG system including response time, memory usage, and answer quality.

**FR4**: The system shall document RAG-only architectural decision with clear rationale.

**FR5**: The system shall maintain existing IRC bot functionality, LLM provider integrations, and attack scenario features during RAG optimization.

**FR6**: The system shall support offline operation for RAG system without external API dependencies (when using Ollama).

**Epic 2 Requirements (CAG System Implementation)**:

**FR7**: The CAG system shall successfully load and pre-cache knowledge base documents for fast retrieval.

**FR8**: The CAG system shall implement KV cache precomputation for long-context LLM models.

**FR9**: The CAG system shall provide significant latency improvements over RAG (target: 50-80% reduction).

**FR10**: The system shall support hybrid CAG-RAG routing with intelligent system selection based on query characteristics.

**FR11**: The CAG system shall support offline operation with pre-computed caches.

**FR12**: The system shall provide comprehensive test coverage (≥80%) for CAG system components.

### 2.2 Non-Functional Requirements

**Epic 1 NFRs (RAG System)**:

**NFR1**: RAG system optimizations shall not break existing functionality.

**NFR2**: Memory usage for RAG system shall not exceed 4GB for typical knowledge base sizes (1000+ documents).

**NFR3**: RAG system query response times shall not exceed 5 seconds for typical cybersecurity training queries (excluding LLM inference time).

**NFR4**: RAG test suite shall achieve minimum 80% code coverage for RAG manager classes.

**NFR5**: Performance validation testing shall include minimum 100 test queries covering diverse cybersecurity topics.

**NFR6**: All RAG optimizations shall follow existing Ruby coding standards and conventions.

**Epic 2 NFRs (CAG System)**:

**NFR7**: CAG system implementation shall not degrade existing RAG system performance.

**NFR8**: Memory usage for CAG system shall not exceed 6GB for typical knowledge base sizes (including KV caches).

**NFR9**: CAG cache precomputation time shall not exceed 5 minutes for initial knowledge base population.

**NFR10**: CAG query response times shall not exceed 2 seconds for typical cybersecurity training queries (excluding LLM inference time).

**NFR11**: CAG test suite shall achieve minimum 80% code coverage for CAG manager classes.

**NFR12**: All CAG implementation shall follow existing Ruby coding standards and conventions.

**Cross-Epic NFRs**:

**NFR13**: System shall maintain backward compatibility with existing bot XML configurations.

**NFR14**: All changes shall be testable in the existing Nix development environment without additional infrastructure requirements.

**NFR15**: Hybrid CAG-RAG routing shall make intelligent decisions based on query characteristics and system performance.

### 2.3 Compatibility Requirements

**Epic 1 Compatibility (RAG System)**:

**CR1**: RAG system optimizations shall maintain compatibility with all existing LLM providers (Ollama, OpenAI, VLLM, SGLang).

**CR2**: Existing bot XML configurations shall continue to function without modification during RAG optimization.

**CR3**: RAG system shall continue to support all knowledge source types (MITRE ATT&CK, man pages, markdown files, lab sheets).

**CR4**: RAG system shall maintain offline/air-gapped operation capability.

**Epic 2 Compatibility (CAG System)**:

**CR5**: CAG system implementation shall maintain compatibility with all existing LLM providers, with special focus on long-context models.

**CR6**: New CAG configuration options shall be optional with sensible defaults; existing configurations remain valid.

**CR7**: CAG system shall support the same knowledge source types as RAG system through shared knowledge base interfaces.

**CR8**: CAG system shall maintain offline/air-gapped operation capability with pre-computed caches.

**Cross-Epic Compatibility**:

**CR9**: All enhancements shall maintain full compatibility with the existing IRC bot interface and command structure.

**CR10**: Hybrid CAG-RAG routing shall be transparent to end users and configurable per bot instance.

**CR11**: Both systems shall support the same knowledge base sources and formats.

---

## 3. Technical Constraints and Integration Requirements

### 3.1 Existing Technology Stack

**Languages**: Ruby 3.1+

**Frameworks & Libraries**:
- **IRC**: ircinch (IRC bot framework)
- **XML Parsing**: nokogiri, nori
- **HTTP**: httparty (for LLM API calls)
- **Standard Library**: json, set, time, etc.

**LLM Providers**:
- Ollama (local, offline-capable)
- OpenAI API
- VLLM (open-source inference server)
- SGLang (fast LLM serving)

**Knowledge Enhancement Systems**:
- **RAG**: Vector database (ChromaDB in-memory), embedding services (OpenAI, Ollama) - **OPERATIONAL**
- **CAG**: **REMOVED** (will be reimplemented in Epic 2 with modern approach)

**Database**:
- In-memory data structures (no external database)
- Vector database: ChromaDB (in-memory mode) - **OPERATIONAL**
- CAG system: To be implemented with KV cache precomputation (Epic 2)

**Infrastructure**:
- Ruby runtime via Nix development environment
- IRC server (custom Python implementation - simple_irc_server.py)
- Offline/air-gapped deployment support
- Service-based deployment (systemd or equivalent)

**External Dependencies**:
- Ollama server (optional, for local LLM)
- External LLM APIs (optional, based on provider choice)
- Man pages (system documentation)
- Knowledge base files (markdown, MITRE ATT&CK data)

**Development Environment**:
- Nix flakes for reproducible builds
- Local gem installation (.gems/ directory)
- Makefile for common operations
- Test suite (test/ directory)

### 3.2 Integration Approach

**Database Integration Strategy**:
- No traditional database required
- RAG system uses in-memory ChromaDB vector store - **OPERATIONAL**
- CAG system to be implemented with KV cache precomputation (Epic 2)
- All data structures must support offline operation

**API Integration Strategy**:
- LLM providers accessed through factory pattern (llm_client_factory.rb)
- All LLM API calls go through abstract llm_client.rb interface
- RAG system integrated via rag/rag_manager.rb - **OPERATIONAL**
- CAG system to be integrated via new cag/cag_manager.rb (Epic 2)
- No changes to LLM client interfaces required

**Frontend Integration Strategy**:
- N/A - IRC text-based interface only
- Bot responses enhanced with RAG/CAG context transparently to users
- No UI changes required

**Testing Integration Strategy**:
- Test files in test/ directory following existing patterns
- Epic 1 test files: test/test_rag_comprehensive.rb, test/test_rag_performance.rb
- Epic 2 test files: test/test_cag_comprehensive.rb, test/test_cag_performance.rb, test/test_hybrid_system.rb
- Integration with existing test runner: test/run_tests.rb
- Tests must run in Nix development environment

### 3.3 Code Organization and Standards

**File Structure Approach**:
```
opt_hackerbot/
├── rag/                          # RAG system (operational, optimization in Epic 1)
│   ├── rag_manager.rb           # Main coordinator
│   ├── chromadb_client.rb       # Vector database client
│   └── embedding_service_*.rb   # Embedding clients
├── cag/                          # CAG system (to be implemented in Epic 2)
│   ├── cag_manager.rb           # Main coordinator
│   ├── context_manager.rb       # Context window management
│   ├── cache_manager.rb         # KV cache management
│   ├── knowledge_loader.rb      # Knowledge preprocessing
│   └── inference_engine.rb      # Response generation
├── knowledge_bases/              # Knowledge sources (shared by RAG/CAG)
│   ├── sources/                  # Knowledge source implementations
│   └── data/                     # Knowledge base data files
├── test/                         # Test suites
│   ├── test_rag_comprehensive.rb     # Epic 1
│   ├── test_rag_performance.rb       # Epic 1
│   ├── test_cag_comprehensive.rb     # Epic 2
│   ├── test_cag_performance.rb       # Epic 2
│   └── test_hybrid_system.rb         # Epic 2
└── docs/                         # Documentation updates
```

**Naming Conventions**:
- Ruby snake_case for files, methods, variables
- CamelCase for class names
- Descriptive names following existing patterns (e.g., cag_manager.rb, test_cag_*.rb)

**Coding Standards**:
- Ruby 3.1+ idioms
- Error handling with rescue blocks and Print.err logging
- Factory pattern for component creation
- Interface-based abstractions (base classes with raise NotImplementedError)
- Configuration via XML files or hash parameters
- Offline-first design (graceful degradation when services unavailable)

**Documentation Standards**:
- Inline comments for complex logic
- Method-level documentation for public APIs
- Update docs/development/RAG_CAG_IMPLEMENTATION_SUMMARY.md with findings
- Architecture decisions documented in PRD and architecture docs

### 3.4 Deployment and Operations

**Build Process Integration**:
- No build step required (interpreted Ruby)
- Gem dependencies managed via Gemfile and local .gems/ directory
- Nix environment ensures reproducible dependencies

**Deployment Strategy**:
- Service-based deployment (systemd unit or equivalent)
- Offline deployment support (no external dependencies required)
- Configuration via XML files in config/ directory
- Knowledge bases deployed as files in knowledge_bases/ directory

**Monitoring and Logging**:
- Print utility class for structured logging (Print.info, Print.err, Print.debug)
- IRC bot logs to stdout/stderr
- Performance metrics collected during testing phase
- No external monitoring systems required

**Configuration Management**:
- Bot configuration: XML files in config/ directory
- RAG/CAG configuration: Embedded in bot XML or passed as hash
- Environment variables for IRC server, ports
- Knowledge source paths configurable per bot

### 3.5 Risk Assessment and Mitigation

**Technical Risks**:

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| CAG requires complete reimplementation beyond 2-week time-box | High | Medium | Time-box at 2 weeks; fallback to RAG-only mode |
| RAG has undiscovered issues during testing | Medium | Low | Test RAG early; address before comparison |
| Neither RAG nor CAG meets latency requirements | Medium | Low | Document findings; optimization becomes follow-on work |

**Integration Risks**:

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| CAG fixes break existing RAG functionality | High | Low | Comprehensive regression testing; isolate changes |
| Knowledge base loading issues affect both systems | High | Medium | Fix at knowledge source level; test both systems |

**Deployment Risks**:

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Nix environment issues prevent testing | Medium | Low | Document environment setup; test in clean shell |
| Offline operation breaks due to new dependencies | High | Low | Explicit requirement; test offline mode |

**Mitigation Strategies**:
1. **Time-boxing**: Hard 2-week limit on CAG fixes; decision point after diagnosis
2. **Incremental testing**: Test RAG first, then CAG, then comparison
3. **Architectural flexibility**: Open to simpler CAG implementation (pre-cached vs graph)
4. **Regression protection**: Run existing tests before and after changes
5. **Documentation**: Record all architectural decisions and trade-offs
6. **Fallback plan**: RAG-only mode is acceptable outcome

---

## 4. Epic and Story Structure

### 4.1 Epic Approach

**Epic Structure Decision**: Two-phase approach with sequential epics

**Rationale**:

This enhancement uses a two-phase approach to ensure production-ready LLM knowledge enhancement capabilities:

**Phase 1 (Epic 1)**: RAG System Validation and Optimization
- Focuses on validating and optimizing the existing operational RAG system
- Ensures production readiness for SecGen integration
- Provides proven baseline for CAG comparison
- Critical path for project timeline

**Phase 2 (Epic 2)**: CAG System Implementation 
- Implements modern CAG system from scratch based on current research
- Depends on Epic 1 completion for baseline and comparison
- Provides performance advantages and alternative approach
- Enhances system capabilities with hybrid routing

**Estimated Timeline**: 
- **Epic 1**: 2-4 weeks (critical path)
- **Epic 2**: 3-5 weeks (can start after Epic 1 completion)
- **Total**: 5-9 weeks for complete LLM knowledge enhancement suite

This approach ensures we have a production-ready system (Epic 1) while exploring advanced capabilities (Epic 2) without blocking critical project timelines.

---

## 5. Epic 1: RAG System Validation and Optimization

**Epic Goal**: Validate and optimize the RAG system for production deployment, ensuring robust performance for cybersecurity training use cases through comprehensive testing and performance validation.

**Integration Requirements**:
- Maintain backward compatibility with existing bot configurations
- Preserve all LLM provider integrations (Ollama, OpenAI, VLLM, SGLang)
- Ensure offline operation capability throughout
- No breaking changes to IRC bot interface or attack scenario functionality

---

### Story 1.1: Create Comprehensive RAG Test Suite

As a **developer**,
I want to **create thorough automated tests for the RAG system**,
so that I can validate its correctness and establish performance baseline.

**Acceptance Criteria**:
1. Test file created: test/test_rag_comprehensive.rb
2. Tests cover document loading from all knowledge source types (MITRE ATT&CK, man pages, markdown)
3. Tests verify vector embedding generation and storage
4. Tests verify similarity search returns relevant results for sample queries
5. Tests validate RAG context formatting for LLM consumption
6. Edge cases tested: empty queries, no matches, large result sets
7. Test coverage >80% for rag/rag_manager.rb and related classes
8. All tests pass in Nix development environment

**Integration Verification**:
- **IV1**: Verify tests don't modify production knowledge bases
- **IV2**: Verify test execution time reasonable (<5 minutes for full suite)
- **IV3**: Verify tests can run offline (no external API dependencies for core functionality)

**Dependencies**: None

**Estimated Effort**: 2-3 days

---

### Story 1.2: Implement RAG Performance Validation and Optimization

As a **developer**,
I want to **validate RAG system performance and identify optimization opportunities**,
so that I can ensure the RAG system meets production requirements and performs optimally.

**Acceptance Criteria**:
1. Test file created: test/test_rag_performance.rb
2. Performance test suite includes ≥100 cybersecurity-focused queries
3. Metrics collected: query latency, memory usage, vector index loading time
4. Result relevance evaluation performed
5. Statistical analysis performed on collected metrics (mean, median, percentiles, standard deviation)
6. Performance validation report generated with charts/tables
7. Performance optimizations implemented based on findings
8. All tests pass in Nix development environment

**Integration Verification**:
- **IV1**: Verify performance testing doesn't interfere with normal bot operation
- **IV2**: Verify test data representative of actual training scenarios
- **IV3**: Verify results reproducible across test runs

**Dependencies**: Story 1.1 (RAG tests complete)

**Estimated Effort**: 3-4 days

---

### Story 1.3: Document RAG System Findings and SecGen Integration

As a **product manager**,
I want to **comprehensive documentation of RAG system validation and SecGen integration planning**,
so that stakeholders have clear guidance for production deployment.

**Acceptance Criteria**:
1. Update docs/development/RAG_IMPLEMENTATION_SUMMARY.md with complete findings
2. Performance validation results documented with charts/tables
3. RAG-only architectural decision documented with rationale
4. Optimization recommendations documented with priorities
5. SecGen integration considerations documented
6. Baseline performance metrics established for future reference
7. Test coverage summary included

**Integration Verification**:
- **IV1**: Verify documentation accuracy against actual test results
- **IV2**: Verify recommendations align with project constraints (offline, performance)
- **IV3**: Verify documentation useful for SecGen integration planning

**Dependencies**: Story 1.2 (performance validation complete)

**Estimated Effort**: 1-2 days

---

### Epic Success Criteria

✅ **Mandatory**:
- RAG system validated and tested with ≥80% coverage
- RAG performance meets all NFR requirements
- RAG-only architectural decision documented
- SecGen integration approach documented

✅ **Preferred** (target outcome):
- RAG system fully optimized based on testing findings
- Performance exceeds requirements with identified optimizations
- Comprehensive documentation for future maintenance
- Clear roadmap for SecGen integration

**Total Epic Estimated Effort**: 6-9 days (aligns with 2-3 week timeline)

---

## 6. Epic 2: CAG System Implementation

**Epic Goal**: Implement a Cache-Augmented Generation (CAG) system from scratch to provide an alternative knowledge enhancement approach, enabling faster query responses and reduced system complexity for cybersecurity training use cases.

**Dependencies**: Epic 1 (RAG system validation and optimization complete)

**Integration Requirements**:
- Maintain compatibility with existing RAG system
- Support hybrid CAG-RAG routing
- Preserve all existing LLM provider integrations
- Ensure offline operation capability
- No breaking changes to existing functionality

---

### Story 2.1: Design CAG System Architecture

As a **developer**,
I want to **design the complete CAG system architecture**,
so that I have clear technical specifications for implementation.

**Acceptance Criteria**:
1. Complete CAG system architecture documented
2. Component interfaces and data flow defined
3. Context management strategy designed
4. Integration points with existing systems specified
5. Implementation plan with technical specifications created

**Dependencies**: Epic 1 complete

**Estimated Effort**: 2-3 days

---

### Story 2.2-2.10: CAG Implementation Stories

[Complete set of 9 additional stories for CAG system implementation, covering:]
- Knowledge base loader for CAG
- Context manager implementation  
- Cache manager with KV cache precomputation
- Inference engine
- CAG manager coordinator
- Comprehensive test suite
- Hybrid CAG-RAG system
- Performance validation and optimization
- Documentation and integration guide

**Estimated Total Effort for Epic 2**: 3-5 weeks

---

### Epic Success Criteria

✅ **Mandatory**:
- CAG system functional with basic knowledge retrieval
- Performance improvement over RAG demonstrated (≥30% latency reduction)
- Integration with IRC bot working
- Basic test coverage achieved (≥60%)
- Existing RAG system unaffected

✅ **Preferred** (target outcome):
- CAG system fully optimized with target performance achieved
- Comprehensive test coverage (≥80%)
- Hybrid CAG-RAG system operational
- Complete documentation and integration guides
- Performance characteristics well understood and documented

**Total Epic Estimated Effort**: 15-25 days (3-5 weeks)

---

## Appendix: Glossary

**RAG (Retrieval-Augmented Generation)**: Knowledge enhancement approach using vector embeddings and similarity search to retrieve relevant documents for LLM context. **CURRENT STATUS**: Operational and validated in Epic 1.

**CAG (Cache-Augmented Generation)**: Modern knowledge enhancement approach that pre-loads all relevant knowledge into a long-context LLM's KV cache, enabling direct response generation without real-time retrieval. **CURRENT STATUS**: To be implemented in Epic 2.

**KV Cache**: Key-Value cache in LLMs that stores attention parameters, enabling faster inference for pre-loaded context.

**SecGen (Security Scenario Generator)**: Larger project into which Hackerbot will be re-integrated after LLM feature stabilization.

**Ollama**: Local LLM inference server enabling offline operation.

**IRC (Internet Relay Chat)**: Text-based communication protocol used for bot-user interaction.

**MITRE ATT&CK**: Comprehensive knowledge base of adversary tactics and techniques used in cybersecurity training.

**Hybrid CAG-RAG System**: Intelligent routing system that selects between CAG and RAG approaches based on query characteristics, knowledge base size, and performance requirements.

---

**End of PRD Document**
