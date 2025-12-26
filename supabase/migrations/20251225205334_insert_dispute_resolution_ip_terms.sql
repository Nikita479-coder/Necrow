/*
  # Dispute Resolution and Intellectual Property Terms
  
  Terms for dispute resolution and IP rights.
*/

-- Dispute Resolution and Arbitration
INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Dispute Resolution and Arbitration',
  '# Dispute Resolution and Arbitration Agreement

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Agreement to Arbitrate

**PLEASE READ THIS SECTION CAREFULLY. IT AFFECTS YOUR LEGAL RIGHTS, INCLUDING YOUR RIGHT TO FILE A LAWSUIT IN COURT.**

By using Shark Trades, you agree that any dispute between you and us will be resolved through binding arbitration rather than in court, except as specified below.

---

## 2. Pre-Arbitration Dispute Resolution

### 2.1 Internal Resolution
Before initiating arbitration, you must:

1. **Submit Complaint:** Contact support with detailed description
2. **Wait for Response:** We will respond within 14 business days
3. **Escalation:** If unresolved, request escalation to management
4. **Final Response:** Management response within 14 additional days

### 2.2 Required Information
Your complaint must include:
- Account details
- Transaction/trade information
- Description of dispute
- Requested resolution
- Supporting documentation

### 2.3 Good Faith Negotiation
Both parties agree to attempt good faith resolution for at least 30 days before arbitration.

---

## 3. Binding Arbitration

### 3.1 Agreement
If internal resolution fails, disputes shall be resolved through binding arbitration administered by a recognized arbitration institution.

### 3.2 Arbitration Rules
- Conducted under institutional arbitration rules
- Single arbitrator for claims under $100,000
- Three arbitrators for larger claims
- Arbitration conducted in English

### 3.3 Location
- Arbitration conducted remotely when possible
- In-person hearings at mutually agreed location
- Arbitrator may conduct hearings by video conference

### 3.4 Arbitrator Authority
The arbitrator has authority to:
- Rule on jurisdictional issues
- Award monetary damages
- Order specific performance
- Award injunctive relief

The arbitrator may NOT:
- Award punitive damages beyond statutory limits
- Consolidate claims without consent
- Proceed as class action

---

## 4. Class Action Waiver

**YOU AND SHARK TRADES AGREE:**

- Disputes will be resolved individually
- Neither party may participate in class actions
- No class, collective, or representative proceedings
- No consolidation without mutual consent

This waiver applies to all claims, including those brought before arbitration agreement.

---

## 5. Exceptions to Arbitration

### 5.1 Small Claims
Either party may bring qualifying claims in small claims court.

### 5.2 Injunctive Relief
Either party may seek emergency injunctive relief in court to prevent irreparable harm while arbitration proceeds.

### 5.3 Intellectual Property
Claims relating to intellectual property infringement may be brought in court.

---

## 6. Costs and Fees

### 6.1 Filing Fees
- Each party pays own initial filing fees
- For claims under $10,000, we may pay your filing fees
- Fee allocation determined by arbitrator

### 6.2 Arbitrator Fees
- Split equally unless arbitrator determines otherwise
- For claims under $10,000, we may pay arbitrator fees

### 6.3 Attorney Fees
- Each party pays own attorney fees
- Arbitrator may award fees to prevailing party if law permits

---

## 7. Governing Law

### 7.1 Applicable Law
These terms and disputes shall be governed by applicable international commercial law principles.

### 7.2 Conflict of Laws
Choice of law rules shall not apply to defeat this agreement.

---

## 8. Time Limitations

### 8.1 Filing Deadline
Claims must be filed within:
- **Trading Disputes:** 30 days of transaction
- **Account Issues:** 90 days of occurrence
- **All Other Claims:** 1 year of occurrence

### 8.2 Waiver
Failure to file within deadline constitutes waiver of claim.

---

## 9. Confidentiality

### 9.1 Arbitration Proceedings
Arbitration proceedings and awards are confidential.

### 9.2 Exceptions
Disclosure permitted:
- To legal/financial advisors
- As required by law
- To enforce arbitration award

---

## 10. Enforcement

### 10.1 Final and Binding
Arbitration awards are final and binding.

### 10.2 Court Confirmation
Awards may be confirmed in any court of competent jurisdiction.

### 10.3 Limitation on Appeals
Appeals limited to grounds under applicable arbitration law.

---

## 11. Survival

This arbitration agreement survives:
- Account closure
- Termination of services
- Amendment of other terms

---

## 12. Severability

If any part of this arbitration agreement is unenforceable:
- That part is severed
- Remaining provisions remain in effect
- Class action waiver is non-severable

---

## 13. Opt-Out Right

### 13.1 Opt-Out Procedure
You may opt out of arbitration by:
- Sending written notice within 30 days of registration
- Including name, email, and account ID
- Stating clear intent to opt out

### 13.2 Effect of Opt-Out
If you opt out:
- Disputes resolved in court
- Class action waiver still applies
- Other terms remain in effect

---

**BY USING OUR SERVICES, YOU ACKNOWLEDGE THAT YOU HAVE READ AND AGREE TO THIS ARBITRATION AGREEMENT.**',
  'dispute_resolution',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();

-- Intellectual Property Notice
INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Intellectual Property Notice',
  '# Intellectual Property Notice

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Ownership

### 1.1 Platform Content
All content on Shark Trades is owned by us or our licensors, including:

- Platform software and code
- User interface and design
- Logos, trademarks, and branding
- Text, graphics, and images
- APIs and documentation
- Trading tools and features
- Educational content
- Market data presentations

### 1.2 Trademarks
The following are trademarks of Shark Trades:
- "Shark Trades" name and logo
- Platform interface elements
- Product names
- Marketing slogans

### 1.3 Third-Party Content
Some content may be licensed from third parties and subject to their terms.

---

## 2. License to Users

### 2.1 Limited License
We grant you a limited, non-exclusive, non-transferable license to:
- Access and use the platform for personal trading
- View content for personal use
- Use tools and features as intended

### 2.2 License Restrictions
You may NOT:
- Copy, modify, or distribute platform content
- Reverse engineer software
- Remove proprietary notices
- Use for commercial purposes (without authorization)
- Create derivative works
- Sublicense to others

---

## 3. User Content

### 3.1 Your Content
You retain ownership of content you submit (usernames, feedback, etc.).

### 3.2 License to Us
By submitting content, you grant us:
- Non-exclusive, royalty-free license
- Right to use, modify, display
- Right to sublicense to service providers
- Perpetual license for feedback and suggestions

### 3.3 Content Standards
Your content must not:
- Infringe others'' intellectual property
- Contain malware or harmful code
- Violate any laws
- Misrepresent affiliation

---

## 4. Copyright Policy

### 4.1 DMCA Compliance
We respect intellectual property rights and comply with applicable copyright laws.

### 4.2 Reporting Infringement
To report copyright infringement, provide:
- Description of copyrighted work
- Location of infringing material
- Your contact information
- Statement of good faith belief
- Statement of accuracy under penalty of perjury
- Physical or electronic signature

### 4.3 Counter-Notification
If you believe content was wrongly removed, you may submit counter-notification with:
- Identification of removed material
- Statement of good faith belief
- Consent to jurisdiction
- Physical or electronic signature

### 4.4 Repeat Infringers
We may terminate accounts of repeat infringers.

---

## 5. Data and Market Information

### 5.1 Market Data
Market data displayed on the platform:
- May be delayed or indicative
- Is for informational purposes
- May not be redistributed
- Subject to third-party terms

### 5.2 Data Accuracy
We do not guarantee accuracy of:
- Price data
- Trading statistics
- Performance metrics
- Historical data

---

## 6. API and Developer Content

### 6.1 API License
API access is subject to API Terms of Use.

### 6.2 Documentation
API documentation is provided for authorized use only.

### 6.3 Sample Code
Any sample code is provided "as-is" without warranty.

---

## 7. Open Source

### 7.1 Open Source Components
Some platform components may use open source software.

### 7.2 Open Source Licenses
Open source components are subject to their respective licenses.

### 7.3 Attribution
Open source attributions available upon request.

---

## 8. Feedback

### 8.1 Submission
By submitting feedback, suggestions, or ideas, you:
- Grant us full rights to use without compensation
- Waive moral rights where applicable
- Acknowledge we may already be developing similar ideas

### 8.2 No Obligation
We have no obligation to:
- Use your feedback
- Compensate you
- Keep feedback confidential

---

## 9. Third-Party Rights

### 9.1 Respect for Rights
You agree to respect third-party intellectual property rights.

### 9.2 Indemnification
You agree to indemnify us for claims arising from your infringement of others'' rights.

---

## 10. Enforcement

### 10.1 Monitoring
We may monitor for IP violations.

### 10.2 Actions
We may:
- Remove infringing content
- Suspend violating accounts
- Report to authorities
- Pursue legal action

---

## 11. Contact

For intellectual property matters:
- Submit through support portal
- Include detailed information
- Allow 10 business days for response

---

**ALL INTELLECTUAL PROPERTY RIGHTS NOT EXPRESSLY GRANTED ARE RESERVED.**',
  'intellectual_property',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();