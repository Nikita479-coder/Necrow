/*
  # Privacy Policy Document
  
  Comprehensive privacy policy covering data collection, processing, and user rights.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Privacy Policy',
  '# Privacy Policy

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Introduction

This Privacy Policy explains how Shark Trades ("we", "us", "our", "the Exchange") collects, uses, shares, and protects your personal information when you use our cryptocurrency exchange platform and related services.

By accessing or using our Services, you consent to the collection and use of your information in accordance with this Privacy Policy. If you do not agree with this policy, please do not use our Services.

---

## 2. Information We Collect

### 2.1 Information You Provide

We collect information you provide directly, including:

- **Account Information:** Full legal name, date of birth, email address, phone number, residential address, nationality
- **Identity Verification:** Government-issued ID (passport, national ID, driver''s license), proof of address documents, selfie photographs, biometric data
- **Financial Information:** Bank account details, cryptocurrency wallet addresses, transaction history, source of funds documentation
- **Communication Data:** Support tickets, emails, chat messages, feedback, and survey responses
- **Preferences:** Language settings, notification preferences, trading preferences

### 2.2 Information Collected Automatically

When you use our platform, we automatically collect:

- **Device Information:** Device type, operating system, browser type and version, unique device identifiers, IP address
- **Usage Data:** Pages visited, features used, time spent on platform, click patterns, search queries
- **Location Data:** Approximate location based on IP address, timezone settings
- **Trading Data:** Orders placed, trades executed, positions held, transaction amounts and timestamps

### 2.3 Information from Third Parties

We may receive information from:

- **Identity Verification Providers:** KYC/AML verification results, watchlist screening results
- **Blockchain Analytics Providers:** Wallet risk scores, transaction analysis
- **Payment Processors:** Transaction confirmations, payment status
- **Marketing Partners:** Referral information (with your consent)

---

## 3. How We Use Your Information

We use your personal information for:

### 3.1 Service Provision
- Creating and managing your account
- Processing transactions and trades
- Providing customer support
- Sending service-related notifications

### 3.2 Legal Compliance
- Verifying your identity (KYC)
- Preventing money laundering and fraud (AML/CTF)
- Complying with sanctions and regulatory requirements
- Responding to legal requests and court orders

### 3.3 Security and Fraud Prevention
- Detecting and preventing unauthorized access
- Monitoring for suspicious activity
- Protecting against fraud and abuse
- Maintaining platform security

### 3.4 Platform Improvement
- Analyzing usage patterns to improve services
- Developing new features and products
- Conducting research and analytics
- Testing and troubleshooting

### 3.5 Marketing (with consent)
- Sending promotional communications
- Personalizing your experience
- Displaying relevant content and offers

---

## 4. Legal Basis for Processing

We process your data based on:

- **Contract Performance:** Processing necessary to provide our services to you
- **Legal Obligation:** Processing required by law (KYC/AML compliance)
- **Legitimate Interests:** Processing for fraud prevention, security, and service improvement
- **Consent:** Marketing communications and non-essential cookies

---

## 5. Information Sharing

We may share your information with:

### 5.1 Service Providers
- Cloud hosting providers
- KYC/AML verification services
- Blockchain analytics providers
- Customer support tools
- Payment processors

### 5.2 Legal and Regulatory Authorities
- Law enforcement agencies (when legally required)
- Financial regulators
- Tax authorities
- Courts and tribunals

### 5.3 Corporate Transactions
- In connection with mergers, acquisitions, or asset sales
- With your consent or at your direction

**We never sell your personal data to third parties.**

---

## 6. International Data Transfers

Your data may be transferred to and processed in countries outside your residence. We ensure appropriate safeguards are in place, including:

- Standard contractual clauses
- Adequacy decisions
- Binding corporate rules
- Your explicit consent where required

---

## 7. Data Retention

We retain your data for:

- **Active Accounts:** Duration of account plus 7 years after closure
- **Transaction Records:** Minimum 7 years (regulatory requirement)
- **KYC Documents:** Duration of account plus 7 years
- **Marketing Data:** Until consent withdrawn
- **Log Data:** 2 years from collection

---

## 8. Your Rights

Depending on your location, you may have the right to:

- **Access:** Request a copy of your personal data
- **Rectification:** Correct inaccurate or incomplete data
- **Erasure:** Request deletion of your data (subject to legal obligations)
- **Restriction:** Limit how we use your data
- **Portability:** Receive your data in a structured format
- **Objection:** Object to certain processing activities
- **Withdraw Consent:** Withdraw consent for marketing communications

To exercise these rights, contact us through our support portal. We will respond within 30 days.

---

## 9. Data Security

We implement industry-standard security measures including:

- Encryption of data in transit and at rest (AES-256)
- Multi-factor authentication
- Regular security audits and penetration testing
- Access controls and employee training
- Incident response procedures

However, no system is completely secure. We cannot guarantee absolute security of your data.

---

## 10. Children''s Privacy

Our Services are not intended for individuals under 18 years of age. We do not knowingly collect personal information from children. If you believe we have collected data from a child, please contact us immediately.

---

## 11. Cookies and Tracking

We use cookies and similar technologies as described in our Cookie Policy. You can manage cookie preferences through your browser settings.

---

## 12. Third-Party Links

Our platform may contain links to third-party websites. We are not responsible for the privacy practices of these external sites. Please review their privacy policies before providing any information.

---

## 13. Changes to This Policy

We may update this Privacy Policy periodically. We will notify you of material changes by:

- Posting a notice on our platform
- Sending an email notification
- Requiring acceptance of updated terms

Continued use after changes constitutes acceptance of the revised policy.

---

## 14. Data Protection Officer

For privacy-related inquiries, contact our Data Protection Officer through:

- **Support Portal:** Available in your account dashboard
- **Response Time:** Within 30 days of receipt

---

## 15. Regulatory Information

### For EU/EEA Users (GDPR)
You have rights under the General Data Protection Regulation including access, rectification, erasure, and the right to lodge a complaint with a supervisory authority.

### For California Users (CCPA)
You have the right to know what personal information is collected, request deletion, and opt-out of the sale of personal information (note: we do not sell your data).

### For Other Jurisdictions
Additional rights may apply based on your local data protection laws.

---

**BY USING OUR SERVICES, YOU ACKNOWLEDGE THAT YOU HAVE READ AND UNDERSTOOD THIS PRIVACY POLICY.**',
  'privacy_policy',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();