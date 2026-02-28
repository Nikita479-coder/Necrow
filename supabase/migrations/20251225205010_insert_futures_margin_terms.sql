/*
  # Futures and Margin Trading Terms
  
  Specific terms for leveraged trading.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Futures and Margin Trading Terms',
  '# Futures and Margin Trading Terms

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Introduction

These terms govern your use of futures and margin trading services on Shark Trades. By engaging in leveraged trading, you accept these terms in addition to our general Terms of Service.

---

## 2. Risk Acknowledgment

**YOU ACKNOWLEDGE AND AGREE THAT:**

- Futures trading involves substantial risk of loss
- Leverage can magnify both gains and losses
- You may lose more than your initial margin deposit
- Past performance does not guarantee future results
- You are solely responsible for your trading decisions
- You have sufficient knowledge and experience to trade futures
- You can afford to lose the funds you commit to trading

---

## 3. Eligibility

To access futures trading, you must:

- Be at least 18 years of age
- Complete identity verification (KYC Level 2 or higher)
- Pass the futures trading eligibility assessment
- Not be a resident of restricted jurisdictions
- Accept these Futures Trading Terms

---

## 4. Account Types

### 4.1 Futures Margin Wallet
- Separate wallet for futures trading
- Transfer funds from main wallet to futures wallet
- Isolated from other wallet balances

### 4.2 Margin Modes

**Cross Margin:**
- All available balance used as margin
- Positions share margin pool
- Lower liquidation risk per position
- Higher account-wide risk

**Isolated Margin:**
- Specific margin allocated per position
- Loss limited to position margin
- Requires manual margin management
- Higher per-position liquidation risk

---

## 5. Leverage

### 5.1 Available Leverage
- Maximum leverage varies by trading pair
- Range: 1x to 125x
- Higher leverage = higher risk

### 5.2 Leverage Tiers
Position size affects maximum leverage:

| Position Size | Max Leverage |
|--------------|--------------|
| $0 - $50,000 | Up to 125x |
| $50,000 - $250,000 | Up to 100x |
| $250,000 - $1,000,000 | Up to 50x |
| $1,000,000+ | Up to 20x |

### 5.3 Leverage Adjustment
- Leverage can only be changed before opening positions
- Existing positions maintain original leverage
- VIP levels may unlock higher leverage limits

---

## 6. Margin Requirements

### 6.1 Initial Margin
- Required to open a position
- Formula: Position Size / Leverage
- Must be available in futures wallet

### 6.2 Maintenance Margin
- Minimum margin to keep position open
- Typically 0.5% - 2% of position value
- Varies by trading pair and leverage

### 6.3 Margin Ratio
- Margin Ratio = (Maintenance Margin / Account Equity) x 100%
- Liquidation warning at 80%
- Liquidation at 100%

---

## 7. Liquidation

### 7.1 Liquidation Process

When margin ratio reaches 100%:

1. **Immediate Notification:** Alert sent to user
2. **Position Closure:** Positions closed at market price
3. **Fee Deduction:** Liquidation fee applied
4. **Balance Settlement:** Remaining balance returned (if any)

### 7.2 Liquidation Price
Calculated based on:
- Entry price
- Leverage used
- Position size
- Maintenance margin rate
- Accumulated funding fees

### 7.3 Liquidation Fee
- Fee: 0.5% of position value
- Contributes to insurance fund
- Deducted from remaining margin

### 7.4 Partial Liquidation
- Positions may be partially liquidated
- Reduces position to lower risk level
- Remaining position maintained if margin sufficient

---

## 8. Insurance Fund

### 8.1 Purpose
- Covers losses when liquidations occur below bankruptcy price
- Prevents socialized losses
- Funded by liquidation surpluses

### 8.2 Depletion
If insurance fund is depleted:
- Auto-Deleveraging (ADL) may occur
- Profitable positions may be reduced
- Socialized losses may apply

---

## 9. Auto-Deleveraging (ADL)

### 9.1 Trigger Conditions
ADL activates when:
- Insurance fund cannot cover liquidation losses
- Extreme market volatility occurs
- System determines intervention necessary

### 9.2 ADL Ranking
Positions ranked by:
- Profit percentage
- Effective leverage
- Higher ranking = higher ADL priority

### 9.3 ADL Process
- Profitable positions automatically reduced
- Executed at bankruptcy price of liquidated position
- Affected users notified immediately

### 9.4 ADL Indicator
- Your ADL ranking displayed in trading interface
- Monitor to assess deleveraging risk

---

## 10. Funding Rates

### 10.1 Purpose
Align perpetual contract prices with spot prices.

### 10.2 Components
- Premium Index: Measures contract vs spot price
- Interest Rate: Base financing rate

### 10.3 Settlement
- Every 8 hours (00:00, 08:00, 16:00 UTC)
- Only positions open at settlement affected
- Positive rate: Longs pay Shorts
- Negative rate: Shorts pay Longs

### 10.4 Extreme Funding
- During high volatility, rates may be extreme
- Consider funding cost for long-term positions
- Historical rates available for review

---

## 11. Order Types

### 11.1 Available Orders
- Market Orders
- Limit Orders
- Stop Market Orders
- Stop Limit Orders
- Take Profit Orders
- Trailing Stop Orders

### 11.2 Reduce-Only Orders
- Can only reduce existing positions
- Cannot increase or open new positions
- Useful for risk management

### 11.3 Post-Only Orders
- Only execute as maker orders
- Reject if would execute immediately
- Ensures maker fee rate

---

## 12. Position Management

### 12.1 Position Limits
- Maximum positions per trading pair
- Maximum total notional exposure
- Limits vary by verification level

### 12.2 Position Modes

**One-Way Mode:**
- Single position per trading pair
- New orders adjust existing position
- Simpler position management

**Hedge Mode:**
- Separate long and short positions
- Can hold both simultaneously
- More complex management

### 12.3 Position Closure
- Market close: Immediate at market price
- Limit close: At specified price
- Stop loss/Take profit: Conditional closure

---

## 13. Risk Management Tools

### 13.1 Stop Loss (SL)
- Automatically close position at loss limit
- Triggered when mark price reaches SL price
- May experience slippage

### 13.2 Take Profit (TP)
- Automatically close position at profit target
- Triggered when mark price reaches TP price
- Secures gains automatically

### 13.3 Trailing Stop
- Dynamic stop loss that follows price
- Activates at specified distance from peak
- Locks in profits while allowing upside

---

## 14. Platform Maintenance

### 14.1 Scheduled Maintenance
- Announced in advance
- Positions remain open
- Orders cannot be placed during maintenance

### 14.2 Emergency Maintenance
- May occur without notice
- For critical system updates
- Users should not rely solely on platform for risk management

---

## 15. Disclaimers

### 15.1 No Guarantee
We do not guarantee:
- Order execution at specific prices
- System availability at all times
- Profit from trading activities

### 15.2 Limitation of Liability
We are not liable for:
- Trading losses
- Liquidations due to market movements
- System downtime or delays
- Third-party actions

---

## 16. Amendments

We may amend these terms with notice. Continued use after amendments constitutes acceptance.

---

**BY ENGAGING IN FUTURES TRADING, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO THESE TERMS.**',
  'futures_terms',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();