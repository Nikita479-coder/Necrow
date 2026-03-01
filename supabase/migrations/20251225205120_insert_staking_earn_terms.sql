/*
  # Staking and Earn Terms
  
  Terms for staking and yield products.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Staking and Earn Terms',
  '# Staking and Earn Product Terms

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Introduction

These terms govern your participation in staking and earn products offered by Shark Trades. By using these services, you agree to be bound by these terms.

---

## 2. Important Notices

**PLEASE UNDERSTAND:**

- Staking products are NOT bank accounts
- Returns are NOT guaranteed
- APY rates are variable and may change
- Your assets may be at risk
- Past performance does not guarantee future results
- You may lose some or all of your staked assets

---

## 3. Product Types

### 3.1 Flexible Products
- No lock-up period
- Withdraw at any time
- Variable APY rates
- Generally lower returns

### 3.2 Fixed-Term Products
- Locked for specified duration (7, 14, 30, 60, 90 days)
- Higher APY rates
- Early withdrawal forfeits rewards
- Principal returned at term end

### 3.3 New User Exclusive Products
- Limited-time offers for new users
- Higher promotional APY rates
- Eligibility expires 72 hours after registration
- One-time participation only

---

## 4. APY and Rewards

### 4.1 APY Definition
Annual Percentage Yield (APY) represents the estimated annualized return, including compound interest effects.

### 4.2 APY Disclaimer
- Displayed APY is indicative only
- Actual returns may vary
- APY may change without notice
- Historical APY does not guarantee future rates

### 4.3 Reward Calculation
- Rewards accrue daily
- Calculated based on staked amount and APY
- Compound frequency varies by product
- Rewards credited according to product terms

### 4.4 Reward Distribution
- Flexible products: Daily distribution
- Fixed products: At term completion
- Distribution in same currency as staked

---

## 5. Staking Process

### 5.1 Subscription
To stake assets:
1. Select a staking product
2. Enter amount to stake
3. Review terms and APY
4. Confirm subscription
5. Assets moved to staking wallet

### 5.2 Minimum/Maximum Amounts
- Minimum staking amount per product
- Maximum capacity per product
- Displayed during subscription

### 5.3 Wallet Requirements
- Sufficient balance in main wallet
- Available balance (not in open orders)
- Transfer from main wallet to staking

---

## 6. Redemption

### 6.1 Flexible Products
- Request redemption anytime
- Processing within 24 hours
- Accrued rewards included
- No penalties

### 6.2 Fixed-Term Products

**At Maturity:**
- Principal + rewards automatically returned
- No action required
- Credited to main wallet

**Early Redemption:**
- Principal returned
- ALL accrued rewards forfeited
- No partial redemption
- Processing within 24 hours

### 6.3 Processing Time
- Standard: Within 24 hours
- May be longer during high demand
- Blockchain confirmation times apply

---

## 7. Risks

### 7.1 Market Risk
- Value of staked assets may decrease
- Cryptocurrency prices are volatile
- Rewards may not offset price decline

### 7.2 Protocol Risk
For proof-of-stake assets:
- Smart contract vulnerabilities
- Protocol failures or exploits
- Slashing penalties possible
- Validator downtime

### 7.3 Liquidity Risk
- Fixed-term products are illiquid
- Market conditions may affect redemption
- Large redemptions may be delayed

### 7.4 Counterparty Risk
- Assets held by third-party protocols
- Protocol insolvency risk
- Custodian risk

---

## 8. Asset Usage

### 8.1 How Assets Are Used
Staked assets may be:
- Delegated to blockchain validators
- Used in DeFi lending protocols
- Provided as liquidity
- Held in custody

### 8.2 No Ownership Transfer
You retain ownership of staked assets subject to:
- Platform terms and conditions
- Protocol-specific risks
- Redemption terms

---

## 9. Fees

### 9.1 Staking Fees
- No subscription fees
- No standard redemption fees
- Service fee included in displayed APY

### 9.2 Hidden Fees
- No hidden fees
- All costs reflected in APY
- Transparent fee structure

---

## 10. Capacity and Availability

### 10.1 Product Capacity
- Limited capacity per product
- First-come, first-served
- Subscription closes when full

### 10.2 Product Availability
We may:
- Add new products
- Discontinue products
- Modify product parameters
- Limit access to certain products

---

## 11. Tax Implications

### 11.1 Tax Responsibility
You are solely responsible for:
- Understanding tax obligations
- Reporting staking rewards
- Paying applicable taxes

### 11.2 Tax Reporting
We do not provide:
- Tax advice
- Tax forms or statements
- Tax withholding services

---

## 12. Restrictions

### 12.1 Prohibited Users
Staking is not available to:
- Residents of restricted jurisdictions
- Unverified accounts
- Suspended or banned accounts

### 12.2 Usage Restrictions
You may not:
- Use staking for illegal purposes
- Attempt to manipulate rewards
- Exploit system vulnerabilities

---

## 13. Service Modifications

### 13.1 Changes
We may modify staking services including:
- APY rates
- Available products
- Terms and conditions
- Capacity limits

### 13.2 Notice
- Material changes: 7 days notice
- APY changes: May be immediate
- Product discontinuation: 14 days notice

---

## 14. Termination

### 14.1 By User
You may:
- Redeem flexible products anytime
- Exit fixed products early (forfeit rewards)
- Close account (redeem all stakes first)

### 14.2 By Platform
We may terminate access for:
- Terms violations
- Suspicious activity
- Regulatory requirements
- Account closure

---

## 15. Limitation of Liability

We are not liable for:
- Losses from market movements
- Protocol or smart contract failures
- Third-party actions
- Force majeure events

---

## 16. Contact

For staking-related inquiries, contact support through the platform.

---

**BY PARTICIPATING IN STAKING OR EARN PRODUCTS, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO THESE TERMS.**',
  'staking_terms',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();