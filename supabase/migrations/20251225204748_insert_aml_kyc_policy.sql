/*
  # AML/KYC Policy Document
  
  Anti-Money Laundering and Know Your Customer policy.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'AML/KYC Policy',
  '# Anti-Money Laundering (AML) and Know Your Customer (KYC) Policy

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Policy Statement

Shark Trades is committed to the highest standards of Anti-Money Laundering (AML) and Counter-Terrorist Financing (CTF) compliance. This policy outlines our procedures for preventing the use of our platform for money laundering, terrorist financing, and other financial crimes.

---

## 2. Regulatory Framework

Our AML/KYC program is designed to comply with:

- Financial Action Task Force (FATF) recommendations
- Applicable national and international AML/CTF laws
- Sanctions regulations (OFAC, EU, UN)
- Industry best practices and standards

---

## 3. Customer Due Diligence (CDD)

### 3.1 Standard Due Diligence

All users must complete identity verification including:

**Personal Information:**
- Full legal name
- Date of birth
- Nationality
- Residential address
- Email address
- Phone number

**Identity Documents:**
- Government-issued photo ID (passport, national ID, or driver''s license)
- Proof of address (utility bill, bank statement dated within 3 months)
- Selfie photograph for facial verification

### 3.2 Verification Levels

**Level 1 - Basic:**
- Email and phone verification
- Limited functionality
- Lower transaction limits

**Level 2 - Standard:**
- Government ID verification
- Proof of address
- Full trading access
- Standard transaction limits

**Level 3 - Enhanced:**
- Source of funds documentation
- Enhanced verification
- Higher transaction limits
- Access to all features

### 3.3 Enhanced Due Diligence (EDD)

EDD is required for:

- High-value accounts (deposits exceeding $50,000)
- Users from high-risk jurisdictions
- Politically Exposed Persons (PEPs)
- Complex ownership structures
- Unusual transaction patterns
- Users flagged by screening systems

EDD measures include:

- Source of funds verification
- Source of wealth documentation
- Enhanced ongoing monitoring
- Senior management approval
- Additional documentation requests

---

## 4. Politically Exposed Persons (PEPs)

### 4.1 Definition
PEPs include:

- Heads of state or government
- Senior politicians and government officials
- Senior judicial or military officials
- Senior executives of state-owned corporations
- Important political party officials
- Family members and close associates of the above

### 4.2 PEP Procedures
- All users are screened against PEP databases
- PEPs require EDD and senior management approval
- Enhanced ongoing monitoring is applied
- Additional source of wealth verification is required

---

## 5. Sanctions Screening

### 5.1 Screening Requirements
All users and transactions are screened against:

- OFAC Specially Designated Nationals (SDN) List
- EU Consolidated Sanctions List
- UN Security Council Sanctions Lists
- National sanctions lists
- Other relevant watchlists

### 5.2 Prohibited Users
We do not provide services to:

- Sanctioned individuals or entities
- Residents of comprehensively sanctioned countries
- Users associated with sanctioned parties
- Users attempting to evade sanctions

---

## 6. Transaction Monitoring

### 6.1 Automated Monitoring
We employ automated systems to detect:

- Large or unusual transactions
- Rapid movement of funds
- Patterns indicative of structuring
- Transactions to/from high-risk addresses
- Unusual trading activity

### 6.2 Red Flags
Indicators that may trigger review include:

- Transactions inconsistent with user profile
- Multiple accounts linked to same identity
- Reluctance to provide required information
- Unusual transaction patterns or timing
- Connections to high-risk wallets
- Attempts to avoid reporting thresholds

### 6.3 Blockchain Analytics
We utilize blockchain analytics tools to:

- Assess wallet risk scores
- Trace transaction origins and destinations
- Identify connections to illicit activities
- Monitor for mixer/tumbler usage
- Detect darknet marketplace connections

---

## 7. Suspicious Activity Reporting

### 7.1 Internal Reporting
Staff must report suspicious activity to the Compliance team for review.

### 7.2 External Reporting
Where required by law, we file:

- Suspicious Activity Reports (SARs)
- Currency Transaction Reports (CTRs)
- Other required regulatory reports

### 7.3 Tipping Off Prohibition
We are prohibited from informing users that reports have been filed or that they are under investigation.

---

## 8. Record Keeping

We maintain records of:

- Customer identification and verification documents
- Transaction records and trading history
- Due diligence assessments
- Suspicious activity reports
- Internal communications regarding compliance

**Retention Period:** Minimum 7 years after account closure or last transaction.

---

## 9. Transaction Limits

### 9.1 Unverified Users
- Limited or no withdrawal capability
- Deposit limits may apply
- Trading functionality may be restricted

### 9.2 Verified Users (Standard)
- Daily withdrawal limits apply
- Based on verification level
- May be increased upon request with additional verification

### 9.3 Enhanced Limits
- Available for fully verified users
- Requires additional documentation
- Subject to approval

---

## 10. Account Restrictions

We may restrict, suspend, or close accounts for:

- Failure to complete verification within required timeframe
- Provision of false or misleading information
- Failed identity verification
- Sanctions matches or watchlist hits
- Suspicious activity detection
- Refusal to provide requested information
- Violation of our Terms of Service

---

## 11. User Cooperation

Users must:

- Provide accurate and complete information
- Update information when changes occur
- Respond promptly to verification requests
- Cooperate with compliance inquiries
- Not use the platform for illegal purposes

---

## 12. Training and Awareness

Our staff receive regular training on:

- AML/CTF requirements and procedures
- Red flag identification
- Suspicious activity reporting
- Sanctions compliance
- Customer due diligence procedures

---

## 13. Compliance Governance

### 13.1 Compliance Officer
A designated Compliance Officer oversees our AML/KYC program.

### 13.2 Independent Review
Our AML/KYC program is subject to periodic independent review and audit.

### 13.3 Policy Updates
This policy is reviewed and updated regularly to reflect:

- Regulatory changes
- Industry developments
- Risk assessment findings
- Audit recommendations

---

## 14. Contact Information

For questions about our AML/KYC procedures, contact our Compliance team through the support portal.

---

**BY USING OUR SERVICES, YOU AGREE TO COMPLY WITH ALL AML/KYC REQUIREMENTS AND ACKNOWLEDGE THAT FAILURE TO DO SO MAY RESULT IN ACCOUNT RESTRICTIONS OR CLOSURE.**',
  'aml_kyc_policy',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();