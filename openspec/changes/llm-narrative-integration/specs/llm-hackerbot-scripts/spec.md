## ADDED Requirements

### Requirement: Interactive Dialogue Generation
The system SHALL generate interactive investigation dialogues for hackerbot/chatbot-guided exercises.

#### Scenario: Generate live analysis dialogue
- **WHEN** generator receives investigation_type="live_analysis"
- **THEN** output includes interactive dialogue for compromised server investigation

#### Scenario: Generate dead analysis dialogue
- **WHEN** generator receives investigation_type="dead_analysis"
- **THEN** output includes interactive dialogue for forensic image investigation

#### Scenario: Generate IDS investigation dialogue
- **WHEN** generator receives investigation_type="ids_investigation"
- **THEN** output includes interactive dialogue for intrusion detection system alerts

### Requirement: Branching Narrative Paths
The system SHALL generate branching narrative paths based on potential student actions.

#### Scenario: Generate correct path dialogue
- **WHEN** student follows correct investigation path
- **THEN** hackerbot provides confirmation and progresses to next clue

#### Scenario: Generate incorrect path feedback
- **WHEN** student follows incorrect investigation path
- **THEN** hackerbot provides gentle redirection without revealing solution

#### Scenario: Generate hint progression
- **WHEN** student requests hints
- **THEN** hackerbot provides escalating hint levels from subtle to explicit

### Requirement: Dynamic Clue Generation
The system SHALL generate dynamic clues based on scenario state and student progress.

#### Scenario: Generate context-aware clues
- **WHEN** student reaches investigation milestone
- **THEN** hackerbot provides clue relevant to current evidence discovered

#### Scenario: Adapt clues to student actions
- **WHEN** student has discovered specific evidence files
- **THEN** hackerbot references discovered evidence in subsequent dialogue

### Requirement: Personalised Hint System
The system SHALL generate personalised hints based on student progress and struggle indicators.

#### Scenario: Generate progress-based hints
- **WHEN** student completes 50% of investigation steps
- **THEN** hints reference completed work and guide toward remaining objectives

#### Scenario: Generate struggle-based hints
- **WHEN** student spends extended time on single step
- **THEN** hints become more explicit to prevent frustration

### Requirement: Template File Integration
The system SHALL output hackerbot scripts compatible with existing template structure.

#### Scenario: Generate live_investigation.md format
- **WHEN** generator creates live analysis hackerbot script
- **THEN** output follows `modules/generators/structured_content/hackerbot_config/live_analysis/templates/live_investigation.md` structure

#### Scenario: Generate dead_investigation.md format
- **WHEN** generator creates dead analysis hackerbot script
- **THEN** output follows `modules/generators/structured_content/hackerbot_config/dead_analysis/templates/dead_investigation.md` structure

#### Scenario: Generate integrity.md format
- **WHEN** generator creates integrity detection hackerbot script
- **THEN** output follows `modules/generators/structured_content/hackerbot_config/integrity_detection/templates/integrity.md` structure

#### Scenario: Generate IDS.md format
- **WHEN** generator creates IDS investigation hackerbot script
- **THEN** output follows `modules/generators/structured_content/hackerbot_config/ids/templates/IDS.md` structure
