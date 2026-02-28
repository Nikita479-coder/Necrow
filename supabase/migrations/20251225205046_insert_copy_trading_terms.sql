/*
  # Copy Trading Terms
  
  Terms and conditions for copy trading services.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Copy Trading Terms',
  '# Copy Trading Terms and Conditions

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Introduction

These terms govern the use of copy trading features on Shark Trades. Copy trading allows users ("Copiers") to automatically replicate the trades of other users ("Lead Traders").

---

## 2. Important Disclaimers

**PLEASE READ CAREFULLY:**

- **PAST PERFORMANCE IS NOT INDICATIVE OF FUTURE RESULTS**
- Copy trading involves significant risk of loss
- You may lose some or all of your invested capital
- You are solely responsible for your decision to copy any trader
- The Exchange does not recommend or endorse any Lead Trader
- Statistics and performance data are historical and not guaranteed
- Lead Traders are not financial advisors

---

## 3. Copier Terms

### 3.1 Eligibility
To use copy trading as a Copier:
- Complete KYC verification (Level 2)
- Have sufficient funds in your Copy Trading wallet
- Accept these Copy Trading Terms
- Understand the risks involved

### 3.2 Copy Allocation

**Allocation Percentage:**
- Set the percentage of your copy wallet to use
- Maximum allocation: 100% of copy wallet balance
- Minimum allocation varies by trader

**Position Sizing:**
- Trades are proportionally sized based on your allocation
- Your position size = Lead Trader position % x Your allocation

### 3.3 Copy Trading Wallet
- Dedicated wallet for copy trading
- Transfer funds from main wallet
- Separate from futures and spot wallets

### 3.4 Trade Execution

**Automatic Copying:**
- Trades execute automatically when Lead Trader trades
- 5-minute response window for manual approval (if enabled)
- May experience slight price differences

**Execution Timing:**
- Copied trades execute after Lead Trader
- Market conditions may differ
- Slippage may occur

### 3.5 Stopping Copy Trading
You may stop copying at any time:
- Existing positions remain open
- You must manually close positions
- No new trades will be copied

---

## 4. Lead Trader Terms

### 4.1 Eligibility
To become a Lead Trader:
- Complete KYC verification (Level 2)
- Minimum trading history required
- Pass Lead Trader assessment
- Accept Lead Trader Agreement

### 4.2 Responsibilities
Lead Traders must:
- Trade responsibly and ethically
- Not engage in manipulative practices
- Maintain reasonable risk management
- Update profile information accurately

### 4.3 Performance Fees
- Set performance fee (0% - 20%)
- Fee charged on copier profits only
- Calculated at position close
- Paid to Lead Trader wallet

### 4.4 Prohibited Conduct
Lead Traders must not:
- Engage in wash trading to inflate statistics
- Manipulate performance metrics
- Provide specific investment advice
- Guarantee profits or returns
- Trade against copiers'' interests

### 4.5 Removal
We may remove Lead Trader status for:
- Violation of these terms
- Excessive losses for copiers
- Manipulative trading behavior
- Account violations

---

## 5. Performance Statistics

### 5.1 Displayed Metrics
- Total return (%)
- Win rate (%)
- Maximum drawdown (%)
- Number of trades
- Copiers count
- Assets under management (AUM)

### 5.2 Calculation Methods
- Returns calculated on closed positions
- Includes fees and funding costs
- Historical periods: 7d, 30d, 90d, All-time

### 5.3 Limitations
Statistics may not reflect:
- Your actual results
- Different entry/exit prices
- Allocation differences
- Time of copying

---

## 6. Fees

### 6.1 Copier Fees
- No platform fee for copying
- Standard trading fees apply to executed trades
- Performance fee to Lead Trader (if applicable)

### 6.2 Performance Fee Calculation
- Fee applies only to net profits
- Calculated per position close
- Formula: Profit x Performance Fee Rate

### 6.3 Fee Example
- Your profit: $100
- Performance fee rate: 10%
- Performance fee: $10
- Your net profit: $90

---

## 7. Risk Management

### 7.1 Copy Settings
Available risk controls:
- Maximum allocation percentage
- Stop copying if loss exceeds threshold
- Maximum position size limits

### 7.2 Manual Intervention
You may:
- Close copied positions manually
- Modify stop loss/take profit
- Stop copying at any time

### 7.3 Liquidation
- Copied positions subject to liquidation rules
- Separate from Lead Trader liquidation
- Monitor your own margin levels

---

## 8. Limitations

### 8.1 Execution Differences
Results may differ due to:
- Price differences at execution
- Slippage and market impact
- Timing delays
- Different position sizes
- Available balance

### 8.2 No Guarantees
We do not guarantee:
- Successful trade execution
- Same results as Lead Trader
- Profit or return on investment
- Availability of copy trading

### 8.3 System Limitations
- Maximum copiers per Lead Trader
- Minimum/maximum copy amounts
- Supported trading pairs

---

## 9. Intellectual Property

### 9.1 Trading Strategies
- Lead Traders retain rights to their strategies
- Copying does not transfer strategy ownership
- You may not replicate strategies outside platform

---

## 10. Privacy

### 10.1 Information Shared
Copiers can see:
- Lead Trader username
- Performance statistics
- Current positions (aggregate)
- Risk metrics

Lead Traders can see:
- Number of copiers
- Total AUM
- Aggregate copy amounts

### 10.2 Information Protected
- Personal identity information
- Exact wallet balances
- Individual copier details

---

## 11. Dispute Resolution

### 11.1 Trade Disputes
- Report within 24 hours of trade execution
- Provide transaction details
- Resolution within 14 business days

### 11.2 Performance Disputes
- Performance data is final
- Based on actual executed trades
- No adjustment for hypothetical scenarios

---

## 12. Termination

### 12.1 By User
You may stop copy trading at any time through account settings.

### 12.2 By Platform
We may terminate copy trading access for:
- Terms violations
- Suspicious activity
- Account suspension
- Platform discretion

---

## 13. Amendments

We may amend these terms with 7 days notice. Continued use constitutes acceptance.

---

**BY USING COPY TRADING FEATURES, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO THESE TERMS AND ACCEPT ALL ASSOCIATED RISKS.**',
  'copy_trading_terms',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();