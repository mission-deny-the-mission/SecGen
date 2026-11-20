# Lab 1: Port Scanning Techniques

## Objective
Learn to use nmap for network reconnaissance and discover open ports on target systems.

## Tools Required
- nmap
- netstat
- wireshark

## Background

Port scanning is a fundamental technique in network reconnaissance. It involves systematically probing a target system to identify open ports, running services, and potential vulnerabilities.

## Common Scan Types

### TCP SYN Scan
The most common port scanning technique:
```bash
nmap -sS target.com
```

### UDP Scan
For UDP service detection:
```bash
nmap -sU target.com
```

### Version Detection
Identify service versions:
```bash
nmap -sV target.com
```

## Practice Exercises

### Exercise 1: Basic Port Scan
1. Scan common ports on target:
   ```bash
   nmap -F target.com
   ```

2. Scan all 65535 ports:
   ```bash
   nmap -p- target.com
   ```

### Exercise 2: Service Detection
1. Enable version detection:
   ```bash
   nmap -sV -p 22,80,443 target.com
   ```

2. Aggressive scan with scripts:
   ```bash
   nmap -A target.com
   ```

## Security Considerations

- Always get permission before scanning
- Some scans may be detected by intrusion detection systems
- Rate limiting may be necessary for stealth
- Document findings responsibly

## Expected Results

After completing this lab, you should be able to:
- Identify open ports on target systems
- Detect running services and versions
- Choose appropriate scan types for different scenarios
- Understand the network footprint of a target