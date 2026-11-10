# Security Auditor — Extended Reference

## OWASP Top 10:2025

| Rank | Category | Your Focus |
|------|----------|------------|
| **A01** | Broken Access Control | Authorization gaps, IDOR, SSRF |
| **A02** | Security Misconfiguration | Cloud configs, headers, defaults |
| **A03** | Software Supply Chain 🆕 | Dependencies, CI/CD, lock files |
| **A04** | Cryptographic Failures | Weak crypto, exposed secrets |
| **A05** | Injection | SQL, command, XSS patterns |
| **A06** | Insecure Design | Architecture flaws, threat modeling |
| **A07** | Authentication Failures | Sessions, MFA, credential handling |
| **A08** | Integrity Failures | Unsigned updates, tampered data |
| **A09** | Logging & Alerting | Blind spots, insufficient monitoring |
| **A10** | Exceptional Conditions 🆕 | Error handling, fail-open states |

---

## Risk Prioritization

### Decision Framework

```
Is it actively exploited (EPSS >0.5)?
├── YES → CRITICAL: Immediate action
└── NO → Check CVSS
         ├── CVSS ≥9.0 → HIGH
         ├── CVSS 7.0-8.9 → Consider asset value
         └── CVSS <7.0 → Schedule for later
```

### Severity Classification

| Severity | Criteria |
|----------|----------|
| **Critical** | RCE, auth bypass, mass data exposure |
| **High** | Data exposure, privilege escalation |
| **Medium** | Limited scope, requires conditions |
| **Low** | Informational, best practice |

---

## What You Look For

### Code Patterns (Red Flags)

| Pattern | Risk |
|---------|------|
| String concat in queries | SQL Injection |
| `eval()`, `exec()`, `Function()` | Code Injection |
| `dangerouslySetInnerHTML` | XSS |
| Hardcoded secrets | Credential exposure |
| `verify=False`, SSL disabled | MITM |
| Unsafe deserialization | RCE |

### Supply Chain (A03)

| Check | Risk |
|-------|------|
| Missing lock files | Integrity attacks |
| Unaudited dependencies | Malicious packages |
| Outdated packages | Known CVEs |
| No SBOM | Visibility gap |

### Configuration (A02)

| Check | Risk |
|-------|------|
| Debug mode enabled | Information leak |
| Missing security headers | Various attacks |
| CORS misconfiguration | Cross-origin attacks |
| Default credentials | Easy compromise |

---

## Anti-Patterns

| ❌ Don't | ✅ Do |
|----------|-------|
| Scan without understanding | Map attack surface first |
| Alert on every CVE | Prioritize by exploitability |
| Fix symptoms | Address root causes |
| Trust third-party blindly | Verify integrity, audit code |
| Security through obscurity | Real security controls |

---
