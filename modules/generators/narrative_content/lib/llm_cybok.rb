# CyBOK (Cyber Security Body of Knowledge) alignment helpers for narrative generation.
# Maps knowledge areas to learning objectives and generates aligned prompts.
class LlmCybok
  # CyBOK Knowledge Areas with topics and learning objectives
  KNOWLEDGE_AREAS = {
    'MAT' => {
      'name' => 'Malicious Activities and Techniques',
      'topics' => [
        'Malware taxonomy and behaviour',
        'Attack lifecycle and kill chain',
        'Social engineering techniques',
        'Exploitation techniques',
        'Adversary infrastructure'
      ],
      'learning_objectives' => [
        'Identify common malware types and their characteristics',
        'Understand the stages of a cyber attack',
        'Recognise social engineering techniques',
        'Analyse exploitation methods and their impact',
        'Describe adversary tools, techniques, and procedures (TTPs)'
      ],
      'keywords' => %w[malware exploit vulnerability attack payload trojan ransomware phishing APT kill-chain]
    },
    'SOIM' => {
      'name' => 'Security Operations and Incident Management',
      'topics' => [
        'Security monitoring and logging',
        'Incident detection and response',
        'Digital forensics fundamentals',
        'Penetration testing methodology',
        'Security information and event management'
      ],
      'learning_objectives' => [
        'Configure and interpret security monitoring tools',
        'Follow structured incident response procedures',
        'Perform basic digital forensic analysis',
        'Conduct systematic penetration testing',
        'Analyse security events and correlate indicators'
      ],
      'keywords' => %w[incident-response SIEM forensics monitoring logging IDS IPS penetration-testing evidence triage]
    },
    'NSCA' => {
      'name' => 'Network Security and Countermeasures',
      'topics' => [
        'Network defence mechanisms',
        'Firewall and filtering technologies',
        'Intrusion detection and prevention',
        'Network forensics',
        'Secure network architecture'
      ],
      'learning_objectives' => [
        'Configure network security controls',
        'Analyse network traffic for security threats',
        'Implement intrusion detection rules',
        'Perform network forensic investigation',
        'Design secure network architectures'
      ],
      'keywords' => %w[firewall IDS IPS packet-capture network-forensics snort suricata tcpdump wireshark segmentation]
    },
    'AAA' => {
      'name' => 'Authentication, Authorisation, and Accountability',
      'topics' => [
        'Authentication mechanisms',
        'Access control models',
        'Identity management',
        'Audit and accountability'
      ],
      'learning_objectives' => [
        'Evaluate authentication mechanisms and their strengths',
        'Apply access control models to scenarios',
        'Analyse identity management challenges',
        'Implement accountability through audit logging'
      ],
      'keywords' => %w[authentication authorisation access-control RBAC identity password MFA audit logging]
    },
    'CPS' => {
      'name' => 'Cyber-Physical Systems Security',
      'topics' => [
        'SCADA and ICS security',
        'IoT security challenges',
        'Physical security integration',
        'Safety-critical systems'
      ],
      'learning_objectives' => [
        'Identify security challenges in cyber-physical systems',
        'Analyse threats to industrial control systems',
        'Evaluate IoT security measures',
        'Assess safety implications of cyber attacks on physical systems'
      ],
      'keywords' => %w[SCADA ICS IoT OT PLC industrial embedded safety-critical]
    }
  }.freeze

  # Generate CyBOK alignment prompt section for a given knowledge area
  def self.alignment_prompt(ka_code, topic = nil)
    ka = KNOWLEDGE_AREAS[ka_code]
    return '' unless ka

    prompt = "This narrative must align with the CyBOK knowledge area: #{ka['name']} (#{ka_code}).\n"

    if topic
      prompt += "Focus on the topic: #{topic}.\n"
    else
      prompt += "Relevant topics include: #{ka['topics'].join(', ')}.\n"
    end

    prompt += "\nLearning objectives to embed in the narrative:\n"
    ka['learning_objectives'].each_with_index do |obj, i|
      prompt += "#{i + 1}. #{obj}\n"
    end

    prompt += "\nUse the following domain-specific terminology naturally: #{ka['keywords'].join(', ')}.\n"
    prompt
  end

  # Generate CyBOK XML tags for scenario output
  def self.xml_tags(ka_code, topic = nil)
    ka = KNOWLEDGE_AREAS[ka_code]
    return '' unless ka

    topic_text = topic || ka['topics'].first
    xml = "  <CyBOK KA=\"#{ka_code}\" topic=\"#{topic_text}\">\n"
    ka['keywords'].first(5).each do |kw|
      xml += "    <keyword>#{kw.upcase.tr('-', ' ')}</keyword>\n"
    end
    xml += "  </CyBOK>\n"
    xml
  end

  # Generate assessment questions for a knowledge area
  def self.assessment_prompt(ka_code, question_type = 'comprehension', context = '')
    ka = KNOWLEDGE_AREAS[ka_code]
    return '' unless ka

    type_descriptions = {
      'comprehension' => 'Test understanding of concepts. Ask students to explain, describe, or summarise key ideas from the scenario.',
      'application' => 'Test ability to apply knowledge. Ask students to use cybersecurity concepts to solve problems or make decisions based on the scenario.',
      'analysis' => 'Test analytical skills. Ask students to break down evidence, compare approaches, identify patterns, or draw conclusions from the scenario.'
    }

    prompt = "Generate assessment questions for the CyBOK knowledge area: #{ka['name']}.\n"
    prompt += "Question type: #{question_type} - #{type_descriptions[question_type]}\n"
    prompt += "Context: #{context}\n" unless context.empty?
    prompt += "\nFormat each question with:\n- Question text\n- Expected answer or key points\n- CyBOK learning objective addressed\n"
    prompt
  end

  # Validate that generated content covers required CyBOK concepts
  def self.validate_coverage(content, ka_code)
    ka = KNOWLEDGE_AREAS[ka_code]
    return { 'valid' => false, 'reason' => 'Unknown knowledge area' } unless ka

    found_keywords = ka['keywords'].select { |kw| content.downcase.include?(kw.downcase.tr('-', ' ')) }
    coverage = (found_keywords.length.to_f / ka['keywords'].length * 100).round(1)

    {
      'valid' => coverage >= 30,
      'coverage_percent' => coverage,
      'found_keywords' => found_keywords,
      'missing_keywords' => ka['keywords'] - found_keywords,
      'knowledge_area' => ka_code
    }
  end
end
