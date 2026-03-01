/*
  # API Terms and Acceptable Use Policy
  
  Terms for API usage and acceptable platform use.
*/

-- API Terms of Use
INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'API Terms of Use',
  '# API Terms of Use

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Introduction

These API Terms of Use govern your access to and use of the Shark Trades Application Programming Interface (API). By using the API, you agree to these terms.

---

## 2. API Access

### 2.1 Eligibility
- Verified account required
- Acceptance of these terms
- Compliance with rate limits

### 2.2 API Keys
- Generate keys in account settings
- Keep keys secure and confidential
- Do not share keys with third parties
- Rotate keys regularly

### 2.3 Key Security
You are responsible for:
- Secure storage of API keys
- All activity under your keys
- Immediate notification if compromised
- Disabling compromised keys

---

## 3. Rate Limits

### 3.1 Standard Limits

| Endpoint Type | Requests/Second | Requests/Minute |
|--------------|-----------------|-----------------|
| Public | 10 | 600 |
| Private | 5 | 300 |
| Order Placement | 10 | 600 |
| Order Cancellation | 20 | 1200 |

### 3.2 VIP Limits
Higher limits available for VIP users.

### 3.3 Exceeding Limits
- Requests rejected with 429 error
- Temporary IP blocking possible
- Persistent abuse may result in ban

---

## 4. Permitted Use

### 4.1 Allowed Activities
- Personal trading automation
- Portfolio management
- Market data analysis
- Integration with approved tools

### 4.2 Commercial Use
Commercial use requires:
- Written approval
- Commercial API agreement
- Separate fee structure

---

## 5. Prohibited Use

### 5.1 Strictly Prohibited
- Interfering with platform stability
- Attempting unauthorized access
- Reverse engineering the API
- Scraping or data harvesting
- Creating competing products
- Redistributing market data
- Market manipulation
- Excessive request flooding

### 5.2 Security Testing
No penetration testing or security scanning without written authorization.

---

## 6. Data Usage

### 6.1 Market Data
- Real-time data for personal use
- No redistribution without license
- Historical data subject to limits

### 6.2 Personal Data
- Access only your own data
- Comply with privacy regulations
- No collection of other users'' data

---

## 7. Availability

### 7.1 No SLA Guarantee
- API provided "as-is"
- No uptime guarantees
- Maintenance may cause downtime

### 7.2 Changes
We may:
- Modify API functionality
- Deprecate endpoints
- Change rate limits
- Update authentication

Notice provided when possible.

---

## 8. Liability

### 8.1 Disclaimer
We are not liable for:
- Trading losses from API use
- System downtime or delays
- Execution errors
- Data accuracy

### 8.2 Your Responsibility
You are responsible for:
- Proper API implementation
- Error handling
- Risk management
- Backup systems

---

## 9. Termination

### 9.1 By User
Revoke API keys anytime in account settings.

### 9.2 By Platform
We may revoke access for:
- Terms violations
- Security concerns
- Abuse detection
- Account issues

---

## 10. Support

### 10.1 Documentation
API documentation available at developer portal.

### 10.2 Support Channels
- Developer documentation
- Support ticket system
- Community forums

---

**BY USING THE API, YOU AGREE TO THESE TERMS OF USE.**',
  'api_terms',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();

-- Acceptable Use Policy
INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Acceptable Use Policy',
  '# Acceptable Use Policy

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Purpose

This Acceptable Use Policy outlines the rules and guidelines for using Shark Trades. All users must comply with this policy.

---

## 2. Permitted Use

### 2.1 General Use
You may use the platform for:
- Legitimate cryptocurrency trading
- Managing your portfolio
- Participating in platform programs
- Accessing educational content

### 2.2 Account Use
- One account per person
- Personal use only (unless authorized)
- Accurate registration information
- Keeping credentials secure

---

## 3. Prohibited Activities

### 3.1 Illegal Activities
- Money laundering
- Terrorist financing
- Tax evasion
- Sanctions violations
- Drug trafficking proceeds
- Fraud or scams
- Any criminal activity

### 3.2 Financial Crimes
- Market manipulation
- Wash trading
- Spoofing or layering
- Pump and dump schemes
- Front-running
- Insider trading

### 3.3 Platform Abuse
- Creating multiple accounts
- Using VPN to bypass restrictions
- Exploiting bugs or vulnerabilities
- Automated abuse (unauthorized bots)
- Denial of service attacks
- Unauthorized data collection

### 3.4 Content Violations
- Harassment or threats
- Hate speech or discrimination
- Impersonation
- Spreading misinformation
- Spam or phishing
- Malware distribution

### 3.5 Intellectual Property
- Copyright infringement
- Trademark violations
- Unauthorized use of platform content
- Reverse engineering

---

## 4. Account Requirements

### 4.1 Registration
- Provide accurate information
- Verify your identity
- Keep information updated
- Maintain valid contact details

### 4.2 Security
- Use strong passwords
- Enable two-factor authentication
- Keep credentials confidential
- Report suspicious activity

### 4.3 Responsible Trading
- Trade within your means
- Understand risks involved
- Use risk management tools
- Comply with trading rules

---

## 5. Communication Guidelines

### 5.1 Support Interactions
- Be respectful and professional
- Provide accurate information
- Follow support procedures
- No abusive language

### 5.2 Community Participation
- Respect other users
- No spam or advertising
- Constructive discussions
- Report violations

---

## 6. Reporting Violations

### 6.1 How to Report
- Contact support portal
- Provide detailed information
- Include evidence if available

### 6.2 Confidentiality
Reports are treated confidentially to the extent possible.

---

## 7. Enforcement

### 7.1 Investigation
We may investigate suspected violations by:
- Reviewing account activity
- Analyzing transaction patterns
- Requesting additional information

### 7.2 Actions
Violations may result in:

**Warning:**
- First-time minor violations
- Written notice issued

**Restriction:**
- Limited functionality
- Reduced limits
- Feature suspension

**Suspension:**
- Temporary account freeze
- Pending investigation
- Asset withdrawal may be restricted

**Termination:**
- Permanent account closure
- Asset forfeiture (if required by law)
- Reporting to authorities

### 7.3 Appeals
You may appeal enforcement actions through the support portal within 30 days.

---

## 8. Cooperation with Authorities

We cooperate with law enforcement and regulatory agencies as required by law, which may include:
- Providing account information
- Freezing assets
- Reporting suspicious activity

---

## 9. Policy Updates

We may update this policy at any time. Continued use constitutes acceptance.

---

## 10. Contact

For questions about this policy, contact support.

---

**BY USING OUR PLATFORM, YOU AGREE TO COMPLY WITH THIS ACCEPTABLE USE POLICY.**',
  'acceptable_use',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();