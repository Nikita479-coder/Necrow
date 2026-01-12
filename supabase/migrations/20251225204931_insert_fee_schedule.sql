/*
  # Fee Schedule Document
  
  Comprehensive fee schedule for all platform services.
*/

INSERT INTO terms_and_conditions (version, title, content, document_type, is_active, effective_date)
VALUES (
  '1.0.0',
  'Fee Schedule',
  '# Fee Schedule

**Last Updated:** December 25, 2024  
**Version:** 1.0.0

---

## 1. Futures Trading Fees

### 1.1 Standard Trading Fees

| VIP Level | Maker Fee | Taker Fee |
|-----------|-----------|-----------|
| Standard | 0.020% | 0.050% |
| VIP 1 | 0.018% | 0.045% |
| VIP 2 | 0.016% | 0.040% |
| VIP 3 | 0.014% | 0.035% |
| VIP 4 | 0.012% | 0.030% |
| VIP 5 | 0.010% | 0.025% |
| Diamond | 0.008% | 0.020% |

### 1.2 Fee Calculation
- Fees are calculated on notional value (Position Size x Entry Price)
- Maker: Order adds liquidity to order book
- Taker: Order removes liquidity from order book

### 1.3 Fee Rebates
VIP members receive fee rebates:
- VIP 1: 5% rebate
- VIP 2: 6% rebate
- VIP 3: 7% rebate
- VIP 4: 8% rebate
- VIP 5: 10% rebate
- Diamond: 15% rebate

---

## 2. Swap/Spot Fees

### 2.1 Instant Swap Fees

| Transaction Size | Fee Rate |
|-----------------|----------|
| Under $1,000 | 0.50% |
| $1,000 - $10,000 | 0.40% |
| $10,000 - $50,000 | 0.30% |
| Over $50,000 | 0.20% |

### 2.2 Limit Swap Fees
- Standard fee: 0.25%
- VIP discounts apply

---

## 3. Funding Fees (Futures)

### 3.1 Funding Rate
- Charged/paid every 8 hours
- Rate varies based on market conditions
- Displayed in trading interface

### 3.2 Settlement Times
- 00:00 UTC
- 08:00 UTC
- 16:00 UTC

### 3.3 Calculation
- Funding Payment = Position Value x Funding Rate
- Positive rate: Long pays Short
- Negative rate: Short pays Long

---

## 4. Deposit Fees

### 4.1 Cryptocurrency Deposits
**FREE** - No deposit fees for cryptocurrency deposits

### 4.2 Minimum Deposits
- Minimum deposit: $10 USD equivalent
- Below minimum may not be credited

---

## 5. Withdrawal Fees

### 5.1 Cryptocurrency Withdrawal Fees

| Currency | Network | Fee |
|----------|---------|-----|
| BTC | Bitcoin | 0.0005 BTC |
| ETH | Ethereum | 0.005 ETH |
| USDT | TRC20 | 1 USDT |
| USDT | ERC20 | 15 USDT |
| USDT | BSC | 0.5 USDT |
| USDC | ERC20 | 15 USDC |
| BNB | BSC | 0.001 BNB |
| SOL | Solana | 0.01 SOL |
| XRP | Ripple | 0.25 XRP |
| ADA | Cardano | 1 ADA |
| DOGE | Dogecoin | 5 DOGE |
| LTC | Litecoin | 0.001 LTC |
| MATIC | Polygon | 0.1 MATIC |
| AVAX | Avalanche | 0.01 AVAX |

*Fees may vary based on network congestion*

### 5.2 Minimum Withdrawals
- Varies by currency
- Displayed during withdrawal process

---

## 6. Staking/Earn Fees

### 6.1 Staking Fees
- No fees for staking deposits
- No fees for standard withdrawals

### 6.2 Early Withdrawal Penalties
- Flexible products: No penalty
- Fixed-term products: Forfeit accrued rewards

### 6.3 Service Fee
- Included in displayed APY
- No additional hidden fees

---

## 7. Copy Trading Fees

### 7.1 Copier Fees
- No fee to copy traders
- Standard trading fees apply to copied trades

### 7.2 Lead Trader Fees
- Performance fee: Up to 20% of copier profits
- Set by individual traders
- Displayed on trader profile

---

## 8. Referral/Affiliate Commissions

### 8.1 Referral Program
- Commission: 20% of referee trading fees
- Duration: Lifetime

### 8.2 Affiliate Program (Multi-Tier)

| Tier | Commission Rate |
|------|-----------------|
| Tier 1 (Direct) | Up to 40% |
| Tier 2 | Up to 10% |
| Tier 3 | Up to 5% |
| Tier 4 | Up to 3% |
| Tier 5 | Up to 2% |

*Rates depend on VIP level and compensation plan*

---

## 9. VIP Program Requirements

### 9.1 Volume Requirements (30-Day)

| VIP Level | Trading Volume |
|-----------|---------------|
| Standard | $0 - $49,999 |
| VIP 1 | $50,000+ |
| VIP 2 | $250,000+ |
| VIP 3 | $1,000,000+ |
| VIP 4 | $5,000,000+ |
| VIP 5 | $25,000,000+ |
| Diamond | $100,000,000+ |

### 9.2 VIP Benefits Summary
- Reduced trading fees
- Fee rebates
- Higher withdrawal limits
- Priority support
- Exclusive events access

---

## 10. Other Fees

### 10.1 Inactivity Fee
- No inactivity fees currently charged

### 10.2 Account Maintenance
- No account maintenance fees

### 10.3 Currency Conversion
- Conversion at market rate
- Spread included in rate

---

## 11. Fee Changes

We reserve the right to modify fees with notice:
- Fee increases: 7 days notice
- Fee decreases: Effective immediately
- Emergency changes: May be immediate

---

## 12. Fee Disputes

For fee-related inquiries or disputes:
- Contact support within 30 days of transaction
- Provide transaction details and documentation
- Resolution within 14 business days

---

**ALL FEES ARE SUBJECT TO CHANGE. PLEASE CHECK THE PLATFORM FOR CURRENT RATES BEFORE TRADING.**',
  'fee_schedule',
  true,
  now()
) ON CONFLICT (version, document_type) DO UPDATE SET
  content = EXCLUDED.content,
  title = EXCLUDED.title,
  is_active = EXCLUDED.is_active,
  updated_at = now();