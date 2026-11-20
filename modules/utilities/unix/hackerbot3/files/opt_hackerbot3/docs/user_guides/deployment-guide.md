# Hackerbot Deployment Guide

This guide provides comprehensive instructions for deploying Hackerbot in various environments, from development setups to production deployments.

## 🎯 Deployment Scenarios

### Development Environment
- Single machine deployment
- Local LLM processing
- Minimal configuration
- Quick startup and testing

### Production Environment
- Multi-bot deployment
- High availability requirements
- Load balancing considerations
- Security hardening

### Education/Training Environment
- Classroom deployment
- Multiple concurrent users
- Controlled access
- Monitoring and analytics

### Air-Gapped/Offline Environment
- No internet connectivity
- Local-only processing
- Enhanced security
- Self-contained knowledge bases

## 🖥️ System Requirements

### Minimum Requirements
- **CPU**: 2+ cores (x86_64 or ARM64)
- **Memory**: 4GB RAM
- **Storage**: 10GB free space
- **Network**: Optional (offline mode supported)
- **OS**: Linux, macOS, or Windows with Ruby support

### Recommended Requirements
- **CPU**: 4+ cores (modern processor)
- **Memory**: 8GB+ RAM
- **Storage**: 50GB+ SSD storage
- **Network**: Gigabit for online features
- **OS**: Ubuntu 20.04+ or RHEL 8+

### Production Requirements
- **CPU**: 8+ cores with high clock speed
- **Memory**: 16GB+ RAM
- **Storage**: 100GB+ fast SSD
- **Network**: Redundant high-speed connections
- **OS**: Enterprise Linux distribution
- **Additional**: Load balancer, monitoring, backup systems

## 📦 Installation Methods

### Method 1: Quick Start (Development)

```bash
# 1. Clone the repository
git clone <repository-url>
cd hackerbot

# 2. Install Ruby dependencies
gem install bundler
bundle install

# 3. Install Ollama (recommended)
curl -fsSL https://ollama.ai/install.sh | sh

# 4. Pull a model
ollama pull gemma3:1b

# 5. Start the service
ollama serve

# 6. Run Hackerbot
ruby hackerbot.rb --config config/example_ollama.xml
```

### Method 2: Production Deployment

```bash
# 1. System preparation
sudo apt update
sudo apt install -y ruby-dev build-essential git

# 2. Create deployment user
sudo useradd -r -s /bin/bash -d /opt/hackerbot hackerbot
sudo mkdir -p /opt/hackerbot
sudo chown hackerbot:hackerbot /opt/hackerbot

# 3. Deploy application
sudo -u hackerbot -i
git clone <repository-url> /opt/hackerbot/current
cd /opt/hackerbot/current
bundle install --deployment --without development test

# 4. Install Ollama (system-wide)
curl -fsSL https://ollama.ai/install.sh | sh
sudo systemctl enable ollama
sudo systemctl start ollama

# 5. Pull required models
sudo -u ollama ollama pull gemma3:1b
sudo -u ollama ollama pull llama2

# 6. Configure knowledge bases
ruby setup_offline_rag_cag.rb
```

### Method 3: Docker Deployment

```dockerfile
# Dockerfile
FROM ruby:3.1-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Create app directory
WORKDIR /app

# Copy application code
COPY . .

# Install Ruby gems
RUN bundle install --without development test

# Pull models
RUN ollama pull gemma3:1b

# Expose ports
EXPOSE 6667 11434

# Start services
CMD ["ollama", "serve"] & \
    ["ruby", "hackerbot.rb", "--irc-server", "0.0.0.0"]
```

### Method 4: Kubernetes Deployment

```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hackerbot
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hackerbot
  template:
    metadata:
      labels:
        app: hackerbot
    spec:
      containers:
      - name: hackerbot
        image: hackerbot:latest
        ports:
        - containerPort: 6667
        env:
        - name: OLLAMA_HOST
          value: "ollama-service"
        - name: RAG_CAG_ENABLED
          value: "true"
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
---
apiVersion: v1
kind: Service
metadata:
  name: hackerbot-service
spec:
  selector:
    app: hackerbot
  ports:
  - port: 6667
    targetPort: 6667
  type: LoadBalancer
```

## ⚙️ Configuration Management

### Environment Variables

```bash
# LLM Configuration
export OLLAMA_HOST="localhost"
export OLLAMA_PORT="11434"
export OPENAI_API_KEY="your-api-key"
export VLLM_HOST="localhost"
export VLLM_PORT="8000"

# Application Configuration
export IRC_SERVER="localhost"
export IRC_PORT="6667"
export CONFIG_DIR="/opt/hackerbot/config"
export LOG_LEVEL="INFO"
export RAG_CAG_ENABLED="true"
export OFFLINE_MODE="false"

# Security Configuration
export API_KEY_ROTATION_DAYS="30"
export SESSION_TIMEOUT="3600"
export MAX_CONCURRENT_USERS="100"
```

### Configuration File Structure

```
/opt/hackerbot/
├── config/
│   ├── production/
│   │   ├── cybersecurity_bot.xml
│   │   ├── social_engineering_bot.xml
│   │   └── network_security_bot.xml
│   ├── development/
│   │   └── test_bot.xml
│   └── common/
│       └── default_settings.xml
├── logs/
│   ├── application.log
│   ├── security.log
│   └── access.log
├── cache/
│   ├── rag_cache/
│   └── cag_cache/
└── data/
    ├── knowledge_bases/
    └── user_data/
```

### Production Configuration Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<hackerbot>
  <name>ProductionCyberBot</name>
  <llm_provider>ollama</llm_provider>
  <ollama_model>gemma3:1b</ollama_model>
  <ollama_host>localhost</ollama_host>
  <ollama_port>11434</ollama_port>
  
  <!-- Production settings -->
  <streaming>true</streaming>
  <max_tokens>2000</max_tokens>
  <temperature>0.7</temperature>
  
  <!-- Knowledge enhancement -->
  <rag_cag_enabled>true</rag_cag_enabled>
  <rag_enabled>true</rag_enabled>
  <cag_enabled>true</cag_enabled>
  
  <!-- Production knowledge sources -->
  <knowledge_sources>
    <source>
      <type>mitre_attack</type>
      <name>mitre_attack</name>
      <enabled>true</enabled>
      <priority>1</priority>
    </source>
    <source>
      <type>man_pages</type>
      <name>security_tools</name>
      <enabled>true</enabled>
      <priority>2</priority>
    </source>
  </knowledge_sources>
  
  <!-- Performance optimization -->
  <rag_cag_config>
    <rag>
      <max_rag_results>5</max_rag_results>
      <enable_caching>true</enable_caching>
      <cache_ttl>1800</cache_ttl>
    </rag>
    <cag>
      <max_cag_depth>2</max_cag_depth>
      <max_cag_nodes>15</max_cag_nodes>
      <enable_caching>true</enable_caching>
    </cag>
  </rag_cag_config>
</hackerbot>
```

## 🔐 Security Hardening

### System Security

```bash
# 1. Firewall configuration
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 6667/tcp  # IRC
sudo ufw allow 11434/tcp # Ollama

# 2. User permissions
sudo usermod -aG sudo hackerbot  # If needed
sudo chmod 750 /opt/hackerbot
sudo chown -R hackerbot:hackerbot /opt/hackerbot

# 3. Service hardening
sudo systemctl edit ollama
# Add: [Service]
#       PrivateTmp=true
#       ProtectHome=true
#       ProtectSystem=strict
```

### Application Security

```ruby
# config/security.rb
module Security
  # Input validation
  def self.validate_input(input)
    return nil if input.nil? || input.strip.empty?
    
    # Remove potentially dangerous content
    sanitized = input.gsub(/<script[^>]*>.*?<\/script>/i, '')
                   .gsub(/javascript:/i, '')
    
    # Length validation
    raise InputTooLongError if sanitized.length > 10_000
    
    sanitized
  end
  
  # API key management
  def self.get_api_key(provider)
    key = ENV["#{provider.upcase}_API_KEY"]
    raise MissingAPIKeyError, "API key for #{provider} not configured" if key.nil?
    
    key
  end
end
```

### Network Security

```bash
# SSL/TLS configuration for IRC
sudo openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
  -keyout /etc/ssl/private/hackerbot.key \
  -out /etc/ssl/certs/hackerbot.crt \
  -subj "/CN=hackerbot.example.com"

# Configure IRC for SSL
echo "irc.use_ssl = true
irc.ssl_cert = /etc/ssl/certs/hackerbot.crt
irc.ssl_key = /etc/ssl/private/hackerbot.key" >> config/irc_settings.conf
```

## 📊 Monitoring and Logging

### Application Monitoring

```ruby
# config/monitoring.rb
module Monitoring
  def self.track_metrics
    # Memory usage
    memory_usage = `ps -o rss= -p #{Process.pid}`.to_i / 1024
    
    # Response times
    response_time = Benchmark.realtime do
      yield
    end
    
    # Log metrics
    log_metric('memory_usage_mb', memory_usage)
    log_metric('response_time_ms', response_time * 1000)
    
    # Alert if thresholds exceeded
    alert_admin('High memory usage') if memory_usage > 8000
    alert_admin('Slow response') if response_time > 5
  end
end
```

### System Monitoring

```bash
# monitoring/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'hackerbot'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

### Log Management

```bash
# /etc/logrotate.d/hackerbot
/opt/hackerbot/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 hackerbot hackerbot
    postrotate
        systemctl reload hackerbot
    endscript
}
```

## 🔄 High Availability Setup

### Load Balancer Configuration

```nginx
# /etc/nginx/nginx.conf
upstream hackerbot_backend {
    server 10.0.1.10:6667;
    server 10.0.1.11:6667;
    server 10.0.1.12:6667;
}

server {
    listen 6667;
    proxy_pass hackerbot_backend;
    
    # Health checks
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
}
```

### Multi-Instance Deployment

```bash
# systemd service for multiple instances
# /etc/systemd/system/hackerbot@.service
[Unit]
Description=Hackerbot Instance %i
After=network.target ollama.service

[Service]
Type=simple
User=hackerbot
WorkingDirectory=/opt/hackerbot/current
ExecStart=/usr/bin/ruby hackerbot.rb \
    --config /opt/hackerbot/config/production/instance_%i.xml \
    --irc-port $((6667 + %i))
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Database Clustering (for knowledge bases)

```yaml
# docker-compose.yml for clustered deployment
version: '3.8'
services:
  redis-cluster:
    image: redis:7-alpine
    command: redis-server --cluster-enabled yes
    ports:
      - "6379:6379"
  
  hackerbot-1:
    image: hackerbot:latest
    environment:
      - REDIS_HOST=redis-cluster
      - INSTANCE_ID=1
    depends_on:
      - redis-cluster
  
  hackerbot-2:
    image: hackerbot:latest
    environment:
      - REDIS_HOST=redis-cluster
      - INSTANCE_ID=2
    depends_on:
      - redis-cluster
```

## 🚀 Scaling Strategies

### Vertical Scaling

```bash
# Resource allocation for single powerful instance
# /etc/systemd/system/hackerbot.service.d/resources.conf
[Service]
LimitNOFILE=65536
MemoryMax=16G
CPUQuota=800%
```

### Horizontal Scaling

```bash
# Auto-scaling script
#!/bin/bash
# /opt/hackerbot/scripts/auto-scale.sh

CURRENT_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{print $1}' | sed 's/,//')
INSTANCES=$(systemctl list-units --type=service --state=running | grep hackerbot@ | wc -l)

if (( $(echo "$CURRENT_LOAD > 2.0" | bc -l) )) && [ $INSTANCES -lt 5 ]; then
    systemctl start hackerbot@$((INSTANCES + 1))
    echo "Scaled up to $((INSTANCES + 1)) instances"
elif (( $(echo "$CURRENT_LOAD < 0.5" | bc -l) )) && [ $INSTANCES -gt 1 ]; then
    systemctl stop hackerbot@$INSTANCES
    echo "Scaled down to $((INSTANCES - 1)) instances"
fi
```

### Geographic Distribution

```bash
# Regional deployment with CDN
# /opt/hackerbot/config/regions.conf
regions:
  us-east-1:
    endpoint: us-east-1.hackerbot.example.com
    load_balancer: us-east-1-lb.example.com
    primary: true
  
  eu-west-1:
    endpoint: eu-west-1.hackerbot.example.com
    load_balancer: eu-west-1-lb.example.com
    failover: true
  
  ap-southeast-1:
    endpoint: ap-southeast-1.hackerbot.example.com
    load_balancer: ap-southeast-1-lb.example.com
    readonly: true
```

## 🛠️ Maintenance and Updates

### Automated Updates

```bash
#!/bin/bash
# /opt/hackerbot/scripts/update.sh

# Backup current deployment
tar -czf /opt/hackerbot/backups/pre-update-$(date +%Y%m%d-%H%M%S).tar.gz \
    /opt/hackerbot/current

# Pull latest code
cd /opt/hackerbot/current
git pull origin main

# Update dependencies
bundle install --deployment --without development test

# Update Ollama models
ollama pull gemma3:1b
ollama pull llama2

# Restart services
systemctl restart hackerbot*
systemctl restart ollama

# Verify deployment
curl -f http://localhost:6667/health || exit 1

echo "Update completed successfully"
```

### Backup Strategy

```bash
#!/bin/bash
# /opt/hackerbot/scripts/backup.sh

BACKUP_DIR="/opt/hackerbot/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup application files
tar -czf "$BACKUP_DIR/application.tar.gz" \
    /opt/hackerbot/current \
    --exclude=*.log \
    --exclude=tmp/*

# Backup knowledge bases
tar -czf "$BACKUP_DIR/knowledge_bases.tar.gz" \
    /opt/hackerbot/data/knowledge_bases

# Backup configurations
tar -czf "$BACKUP_DIR/config.tar.gz" \
    /opt/hackerbot/config

# Database backup (if using external DB)
mysqldump -u hackerbot -p hackerbot_db > "$BACKUP_DIR/database.sql"

# Clean old backups (keep 30 days)
find /opt/hackerbot/backups -name "20*" -mtime +30 -exec rm -rf {} \;
```

### Performance Tuning

```ruby
# config/performance.rb
module Performance
  # Connection pooling for HTTP clients
  @connection_pool = ConnectionPool.new(size: 10, timeout: 5) do
    HTTPClient.new
  end
  
  # Memory-efficient caching
  @cache = LruCache.new(max_size: 1000, ttl: 3600)
  
  def self.optimize_rag_processing
    # Process documents in batches
    batch_size = 50
    documents.each_slice(batch_size) do |batch|
      process_batch(batch)
      GC.start if memory_usage > 8000 # Force GC if memory high
    end
  end
end
```

## 🔍 Troubleshooting

### Common Issues and Solutions

#### High Memory Usage
```bash
# Check memory usage
ps aux | grep hackerbot

# Reduce RAG context size
# In configuration: <max_rag_results>3</max_rag_results>

# Enable individual systems only
ruby hackerbot.rb --rag-only
```

#### Slow Response Times
```bash
# Check Ollama performance
curl http://localhost:11434/api/tags

# Use smaller model
ruby hackerbot.rb --ollama-model gemma3:1b

# Disable streaming if causing issues
ruby hackerbot