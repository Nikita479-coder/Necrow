/*
  # Referral, Affiliate, and VIP Program Terms
  
  Terms for promotional programs.
*/

-- Referral Program Terms
INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Referral Program Terms',
  '# Referral Program Terms and Conditions

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Program Overview

The Shark Trades Referral Program rewards users for introducing new traders to the platform. Earn commission on your referrals'' trading fees for life.

---

## 2. Eligibility

### 2.1 Referrer Requirements
- Verified Shark Trades account (KYC Level 1+)
- Account in good standing
- Accept these Referral Terms

### 2.2 Referee Requirements
- New user who has never registered
- Must use valid referral link/code
- Complete registration and verification

---

## 3. Referral Commission

### 3.1 Commission Rate
- **Standard Rate:** 20% of referee trading fees
- **Duration:** Lifetime of referee account

### 3.2 Eligible Fees
Commission earned on:
- Futures trading fees
- Swap trading fees
- Other applicable trading fees

### 3.3 Non-Eligible
Commission NOT earned on:
- Withdrawal fees
- Deposit fees
- Third-party fees

---

## 4. Commission Payment

### 4.1 Calculation
- Calculated in real-time
- Based on referee''s net trading fees
- Credited to referrer''s main wallet

### 4.2 Payment Timing
- Instant credit upon referee trade completion
- No minimum payout threshold
- Withdrawable immediately

---

## 5. Referral Link/Code

### 5.1 Obtaining Your Link
- Find in Profile > Referral section
- Unique link per user
- QR code available

### 5.2 Link Usage
- Share via social media, email, messaging
- Include in content (blogs, videos)
- Direct sharing allowed

---

## 6. Prohibited Activities

### 6.1 Strictly Prohibited
- Self-referral (referring your own accounts)
- Fake accounts to claim referral bonuses
- Misleading or false advertising
- Spam or unsolicited messaging
- Purchasing referrals
- Using bots or automated systems

### 6.2 Consequences
Violations result in:
- Commission forfeiture
- Account suspension
- Program termination
- Possible legal action

---

## 7. Referee Benefits

### 7.1 Welcome Benefits
Referred users receive:
- Standard new user promotions
- Trading fee discounts (if applicable)
- Access to all platform features

---

## 8. Program Modifications

We may modify the program including:
- Commission rates
- Eligibility requirements
- Terms and conditions

Notice will be provided for material changes.

---

## 9. Tax Responsibility

You are responsible for reporting and paying taxes on referral earnings.

---

**BY PARTICIPATING IN THE REFERRAL PROGRAM, YOU AGREE TO THESE TERMS.**',
  'referral_terms',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();

-- Affiliate Program Terms
INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Affiliate Program Terms',
  '# Affiliate Program Terms and Conditions

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Program Overview

The Shark Trades Affiliate Program is a professional partnership opportunity offering multi-tier commissions, advanced analytics, and dedicated support for serious marketers.

---

## 2. Eligibility

### 2.1 Requirements
- Active Shark Trades account
- KYC Level 2 verification
- Demonstrated marketing capability
- Acceptance of these terms

### 2.2 Application
- Apply through Affiliate section
- Review process: 5-7 business days
- Approval not guaranteed

---

## 3. Compensation Plans

### 3.1 Revenue Share (RevShare)

**Multi-Tier Commission Structure:**

| Tier | Relationship | Commission Rate |
|------|--------------|-----------------|
| Tier 1 | Direct referrals | Up to 40% |
| Tier 2 | Referrals of Tier 1 | Up to 10% |
| Tier 3 | Referrals of Tier 2 | Up to 5% |
| Tier 4 | Referrals of Tier 3 | Up to 3% |
| Tier 5 | Referrals of Tier 4 | Up to 2% |

*Rates depend on VIP level*

### 3.2 CPA (Cost Per Acquisition)

Fixed payment for qualified referrals:
- $50 - $200 per qualified user
- Requirements: Deposit + Trading volume
- One-time payment per user

### 3.3 Hybrid Plan

Combination of RevShare and CPA:
- Lower RevShare rate (40% of standard)
- Plus CPA bonus per qualified user
- Best of both models

---

## 4. Commission Rates by VIP Level

| VIP Level | Tier 1 Rate |
|-----------|-------------|
| Standard | 10% |
| VIP 1 | 20% |
| VIP 2 | 30% |
| VIP 3 | 40% |
| VIP 4 | 50% |
| VIP 5+ | 70% |

---

## 5. CPA Qualification

A referral qualifies for CPA when they:
- Complete KYC verification
- Make first deposit (minimum $50)
- Achieve trading volume (minimum $1,000)
- Active within 30 days of registration

---

## 6. Payment

### 6.1 Payment Schedule
- RevShare: Real-time credit
- CPA: Upon qualification
- Minimum payout: $50

### 6.2 Payment Methods
- Credit to Shark Trades wallet
- Withdrawable via standard methods

---

## 7. Marketing Guidelines

### 7.1 Permitted Activities
- Content marketing (blogs, videos, podcasts)
- Social media promotion
- Email marketing (with consent)
- Paid advertising (compliant)
- Educational content

### 7.2 Required Disclosures
You must disclose:
- Affiliate relationship
- Potential compensation
- Risk warnings for trading

### 7.3 Prohibited Activities
- False or misleading claims
- Guaranteed profit promises
- Spam or unsolicited contact
- Trademark misuse
- Negative SEO against competitors
- Fraudulent referrals

---

## 8. Brand Usage

### 8.1 Approved Materials
- Use official logos and assets
- Available in affiliate dashboard
- Follow brand guidelines

### 8.2 Restrictions
- No modification of logos
- No misleading representations
- No unauthorized partnerships claims

---

## 9. Network Management

### 9.1 Sub-Affiliates
- Recruit and manage sub-affiliates
- Earn from their referrals (multi-tier)
- Responsible for their compliance

### 9.2 Analytics
Access to:
- Real-time tracking dashboard
- Conversion analytics
- Commission reports
- Network performance

---

## 10. Termination

### 10.1 By Affiliate
- 30 days written notice
- Pending commissions paid
- Active referrals continue earning

### 10.2 By Platform
Immediate termination for:
- Terms violations
- Fraudulent activity
- Brand damage
- Regulatory requirements

---

## 11. Confidentiality

Affiliate information (rates, strategies) is confidential and may not be disclosed.

---

## 12. Amendments

We may modify program terms with 14 days notice for material changes.

---

**BY PARTICIPATING IN THE AFFILIATE PROGRAM, YOU AGREE TO THESE TERMS AND REPRESENT COMPLIANCE WITH ALL APPLICABLE LAWS.**',
  'affiliate_terms',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();

-- VIP Program Terms
INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'VIP Program Terms',
  '# VIP Program Terms and Conditions

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Program Overview

The Shark Trades VIP Program rewards active traders with exclusive benefits, reduced fees, and premium services based on trading volume.

---

## 2. VIP Levels

### 2.1 Tier Structure

| Level | 30-Day Volume | Tier Name |
|-------|--------------|-----------|
| 0 | $0 - $49,999 | Standard |
| 1 | $50,000+ | Bronze |
| 2 | $250,000+ | Silver |
| 3 | $1,000,000+ | Gold |
| 4 | $5,000,000+ | Platinum |
| 5 | $25,000,000+ | Elite |
| 6 | $100,000,000+ | Diamond |

---

## 3. Benefits by Level

### 3.1 Trading Fee Discounts

| Level | Maker Fee | Taker Fee |
|-------|-----------|-----------|
| Standard | 0.020% | 0.050% |
| Bronze | 0.018% | 0.045% |
| Silver | 0.016% | 0.040% |
| Gold | 0.014% | 0.035% |
| Platinum | 0.012% | 0.030% |
| Elite | 0.010% | 0.025% |
| Diamond | 0.008% | 0.020% |

### 3.2 Fee Rebates

| Level | Rebate % |
|-------|----------|
| Bronze | 5% |
| Silver | 6% |
| Gold | 7% |
| Platinum | 8% |
| Elite | 10% |
| Diamond | 15% |

### 3.3 Additional Benefits

**Bronze+:**
- Priority customer support
- Extended API limits

**Silver+:**
- Higher withdrawal limits
- Dedicated account manager

**Gold+:**
- Exclusive market insights
- Early access to features

**Platinum+:**
- Weekly Shark Card refills
- VIP events access

**Elite+:**
- Custom fee negotiations
- Direct executive access

**Diamond:**
- Bespoke services
- Premium everything

---

## 4. Volume Calculation

### 4.1 Qualifying Volume
- Futures trading volume
- Spot/Swap trading volume
- Calculated on notional value

### 4.2 Calculation Period
- Rolling 30-day window
- Updated in real-time
- Displayed in account dashboard

### 4.3 Non-Qualifying
- Staking/Earn products
- Deposits/Withdrawals
- Copy trading fees

---

## 5. Tier Upgrades

### 5.1 Automatic Upgrade
- Instant upon reaching threshold
- Benefits apply immediately
- Notification sent

### 5.2 Manual Review
Diamond level may require:
- Account review
- Enhanced verification
- Approval process

---

## 6. Tier Maintenance

### 6.1 Evaluation Period
- Monthly evaluation
- Based on 30-day volume
- Downgrade if below threshold

### 6.2 Grace Period
- 7 days to recover volume
- Maintain current tier
- After grace: Downgrade

### 6.3 Downgrade Process
- Benefits adjusted immediately
- Fees updated to new tier
- Notification provided

---

## 7. Shark Card Benefits (VIP 4+)

### 7.1 Weekly Refills

| Level | Weekly Refill |
|-------|---------------|
| Platinum | $50 |
| Elite | $100 |
| Diamond | $250 |

### 7.2 Refill Conditions
- Active Shark Card required
- Auto-credited weekly
- Non-withdrawable credit

---

## 8. Program Modifications

We reserve the right to:
- Modify tier requirements
- Adjust benefits
- Change fee structures
- Discontinue program

Notice provided for material changes.

---

## 9. Eligibility

### 9.1 Requirements
- Verified account (KYC Level 2+)
- Account in good standing
- No terms violations

### 9.2 Exclusions
VIP benefits may not apply to:
- Promotional accounts
- Restricted jurisdictions
- Suspended accounts

---

## 10. Disclaimer

VIP status and benefits are:
- Subject to change
- Not guaranteed
- Based on trading activity
- At platform discretion

---

**BY PARTICIPATING IN THE VIP PROGRAM, YOU AGREE TO THESE TERMS AND CONDITIONS.**',
  'vip_terms',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();