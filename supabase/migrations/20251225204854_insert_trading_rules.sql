/*
  # Trading Rules and Regulations
  
  Comprehensive trading rules for the platform.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Trading Rules and Regulations',
  '# Trading Rules and Regulations

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. General Trading Rules

### 1.1 Trading Hours
- Cryptocurrency markets operate 24/7/365
- Scheduled maintenance may temporarily interrupt trading
- Emergency maintenance may occur without prior notice

### 1.2 Order Types

**Market Orders:**
- Execute immediately at best available price
- May experience slippage in volatile markets
- Partial fills may occur for large orders

**Limit Orders:**
- Execute only at specified price or better
- May not fill if price is not reached
- Good-til-canceled unless otherwise specified

**Stop Orders:**
- Triggered when market reaches stop price
- Convert to market orders upon trigger
- Not guaranteed to execute at stop price

**Take Profit / Stop Loss:**
- Conditional orders attached to positions
- Execute when trigger conditions are met
- Subject to slippage and market conditions

### 1.3 Order Size Limits
- Minimum order sizes vary by trading pair
- Maximum position sizes apply per user and per pair
- VIP users may have higher limits

---

## 2. Order Execution

### 2.1 Execution Priority
Orders are matched based on:
1. Price (best price first)
2. Time (earliest order first at same price)

### 2.2 Slippage
- Market orders may execute at different prices than displayed
- Large orders may fill across multiple price levels
- High volatility increases slippage risk

### 2.3 Partial Fills
- Orders may partially fill if insufficient liquidity
- Remaining quantity stays in order book (limit orders)
- Market orders continue filling at available prices

### 2.4 Order Cancellation
- Open orders can be cancelled before execution
- Partially filled orders can cancel remaining quantity
- Executed trades cannot be cancelled

---

## 3. Futures Trading Rules

### 3.1 Contract Specifications

**Perpetual Contracts:**
- No expiration date
- Settlement in USDT
- Subject to funding rate payments

### 3.2 Leverage
- Maximum leverage varies by trading pair (up to 125x)
- Leverage can be adjusted before opening positions
- Higher leverage increases liquidation risk

### 3.3 Margin Requirements

**Initial Margin:**
- Required to open a position
- Calculated as: Position Size / Leverage

**Maintenance Margin:**
- Minimum equity to maintain position
- Falling below triggers liquidation warning
- Further decline results in liquidation

### 3.4 Position Limits
- Maximum position size per trading pair
- Maximum total exposure across all positions
- Limits may vary by verification level

---

## 4. Liquidation Rules

### 4.1 Liquidation Process
When account equity falls below maintenance margin:

1. **Warning:** Alert sent to user
2. **Reduction:** Position may be partially closed
3. **Liquidation:** Full position closure if margin insufficient

### 4.2 Liquidation Price
- Calculated based on entry price, leverage, and margin
- Displayed on position information
- May vary due to funding fees and unrealized PnL

### 4.3 Insurance Fund
- Covers losses from liquidations below bankruptcy price
- Funded by liquidation surpluses
- May be depleted in extreme market conditions

### 4.4 Auto-Deleveraging (ADL)
When insurance fund is insufficient:
- Profitable positions may be automatically reduced
- ADL ranking based on profit and leverage
- Affected users notified of position reduction

---

## 5. Funding Rate

### 5.1 Purpose
Funding rates keep perpetual contract prices aligned with spot prices.

### 5.2 Calculation
- Based on premium index and interest rate
- Positive rate: Longs pay shorts
- Negative rate: Shorts pay longs

### 5.3 Payment Schedule
- Charged/paid every 8 hours (00:00, 08:00, 16:00 UTC)
- Only open positions at settlement time affected
- Rate displayed in trading interface

### 5.4 Historical Rates
- Historical funding rates viewable in platform
- Rates can be extreme during high volatility
- Consider funding when holding positions long-term

---

## 6. Swap/Spot Trading Rules

### 6.1 Instant Swap
- Immediate execution at displayed rate
- Rate includes spread and fees
- Minimum and maximum amounts apply

### 6.2 Limit Swap
- Execute when target rate is reached
- Orders expire after specified duration
- Partial fills may occur

### 6.3 Price Updates
- Prices update in real-time
- Execution price may differ slightly from quoted price
- Large orders may impact execution price

---

## 7. Prohibited Trading Activities

### 7.1 Market Manipulation
The following activities are strictly prohibited:

- **Wash Trading:** Trading with yourself to create false volume
- **Spoofing:** Placing orders with intent to cancel before execution
- **Layering:** Multiple orders at different prices to mislead
- **Pump and Dump:** Coordinated buying to inflate prices
- **Front-Running:** Trading ahead of known large orders

### 7.2 System Abuse
- Exploiting platform bugs or vulnerabilities
- Using bots without authorization
- Attempting to manipulate prices through technical means
- Circumventing trading limits or restrictions

### 7.3 Consequences
Violations may result in:
- Trade reversal or adjustment
- Account suspension or termination
- Asset freezing
- Reporting to authorities
- Legal action

---

## 8. Error Trades

### 8.1 Definition
Error trades may occur due to:
- Technical malfunctions
- Clearly erroneous pricing
- Fat finger errors (extreme deviations from market price)

### 8.2 Handling
We reserve the right to:
- Cancel or adjust clearly erroneous trades
- Reverse trades resulting from system errors
- Adjust prices to fair market value

### 8.3 Notification
Affected users will be notified of any trade adjustments.

---

## 9. Trading Pair Management

### 9.1 New Listings
- New trading pairs announced in advance
- Initial trading may have adjusted parameters
- Liquidity may be limited initially

### 9.2 Delistings
- Advance notice provided (minimum 7 days)
- Open orders cancelled at delisting
- Users should close positions before deadline

### 9.3 Trading Halts
Trading may be halted due to:
- Extreme volatility
- Technical issues
- Regulatory requirements
- Security concerns

---

## 10. Price Sources and Indices

### 10.1 Mark Price
- Used for liquidation calculations
- Based on weighted index from multiple exchanges
- Reduces manipulation impact

### 10.2 Index Price
- Aggregated from major spot exchanges
- Weighted by volume and liquidity
- Updated in real-time

### 10.3 Last Price
- Most recent trade execution price
- May deviate from mark/index price
- Used for PnL display

---

## 11. Amendments

We reserve the right to:
- Modify trading rules with notice
- Adjust parameters during extreme conditions
- Implement emergency measures for market integrity

---

**BY TRADING ON OUR PLATFORM, YOU AGREE TO ABIDE BY THESE TRADING RULES AND REGULATIONS.**',
  'trading_rules',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();