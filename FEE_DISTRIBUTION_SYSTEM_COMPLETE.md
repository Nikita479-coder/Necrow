# Complete Fee Distribution System

## Overview
All three commission and rebate systems now work together seamlessly on EVERY fee collected.

## The 3 Systems Working Together

### 1. Fee Rebate (VIP Discount)
**What it does:** Reduces effective trading costs for users based on VIP level
**Recipient:** The trader themselves
**Destination:** Trader's SPOT wallet
**Rates:** 5% - 20% based on VIP level (Beginner to Diamond)
**Trigger:** Automatic via database trigger on fee_collections table

### 2. Referral Earnings (Legacy - Now Part of Affiliate)
**Status:** Merged into the affiliate system
**Note:** The old `distribute_trading_fees` function has been replaced by the comprehensive 5-tier affiliate system

### 3. Affiliate Commission (5-Tier Multi-Level)
**What it does:** Distributes commissions across up to 5 levels of the referral chain
**Recipients:** All affiliates in the upline (up to 5 tiers)
**Destination:** Each affiliate's MAIN wallet
**Rates:** Based on VIP level and tier position
- **Tier 1** (Direct referrer): 10%-70% of fee (based on VIP level) × 100%
- **Tier 2**: 10%-70% of fee × 20%
- **Tier 3**: 10%-70% of fee × 10%
- **Tier 4**: 10%-70% of fee × 5%
- **Tier 5**: 10%-70% of fee × 2%

## Integration Points

### All Fee Collection Points Now Include Affiliate Payouts:

#### 1. Position Opening (place_market_order)
- **Fees Collected:** Trading fee + Spread cost
- **Fee Rebate:** ✅ Applied to trader's spot wallet
- **Affiliate Payout:** ✅ Distributed across 5-tier chain

#### 2. Position Closing (close_position_market)
- **Fees Collected:** Trading fee
- **Fee Rebate:** ✅ Applied to trader's spot wallet
- **Affiliate Payout:** ✅ Distributed across 5-tier chain

#### 3. Overnight/Funding Fees (apply_funding_payment)
- **Fees Collected:** Funding rate payment (every 8 hours)
- **Fee Rebate:** ✅ Applied to trader's spot wallet
- **Affiliate Payout:** ✅ Distributed across 5-tier chain

#### 4. Liquidation (liquidate_position)
- **Fees Collected:** Liquidation fee (0.5% of notional)
- **Fee Rebate:** ✅ Applied to trader's spot wallet
- **Affiliate Payout:** ✅ Distributed across 5-tier chain

#### 5. Spot Swaps (execute_swap)
- **Fees Collected:** Swap fee (0.1%)
- **Fee Rebate:** ✅ Applied to trader's spot wallet
- **Affiliate Payout:** ✅ Distributed across 5-tier chain

## How It Works - Complete Flow

When a user pays ANY fee:

```
1. Fee Deducted from User
   └─> User's futures/spot wallet balance reduced

2. Fee Recorded
   └─> INSERT into fee_collections table

3. Fee Rebate Trigger Fires (Automatic)
   └─> trigger_apply_fee_rebate()
   └─> Calculates rebate based on user's VIP level
   └─> Credits rebate to user's SPOT wallet
   └─> Records transaction

4. Affiliate Commission Distribution (Called by function)
   └─> distribute_multi_tier_commissions()
   └─> Looks up 5-tier affiliate chain
   └─> Calculates commission for each tier based on their VIP level
   └─> Credits commission to each affiliate's MAIN wallet
   └─> Updates referral_stats for tracking
   └─> Records in tier_commissions table
```

## Database Tables Used

### Fee Tracking
- `fee_collections` - All fees collected from users
- `transactions` - All wallet movements including rebates and commissions

### Affiliate System
- `affiliate_tiers` - The 5-tier chain for each user
- `tier_commissions` - Record of all affiliate payouts
- `affiliate_compensation_plans` - User's chosen plan (revshare/CPA/hybrid)

### Referral System (Integrated)
- `referral_stats` - Aggregate stats for each affiliate/referrer
- `user_vip_status` - Current VIP level, commission rate, rebate rate

### Wallets
- `wallets` with `wallet_type`:
  - `spot` - Receives fee rebates
  - `main` - Receives affiliate commissions
  - `futures` - Used for futures trading
  - `futures_margin` - Cross-margin futures wallet

## Example Scenario

**User Bob (VIP 2 - 20% commission rate):**
- Opens BTC position worth $10,000
- Trading fee: $5 (0.05%)
- Bob's VIP level: 1 (Beginner - 10% rebate)

**What Happens:**
1. Bob pays $5 fee
2. Bob receives $0.50 rebate to his SPOT wallet (10% of $5)
3. If Bob was referred by Alice (VIP 2 - 20% commission):
   - **Tier 1 (Alice)**: Gets $1.00 (20% of $5 × 100%)
   - **Tier 2 (Alice's referrer)**: Gets $0.20 (20% of $5 × 20%)
   - **Tier 3**: Gets $0.10 (20% of $5 × 10%)
   - **Tier 4**: Gets $0.05 (20% of $5 × 5%)
   - **Tier 5**: Gets $0.02 (20% of $5 × 2%)

**Total Distribution:**
- Bob's rebate: $0.50
- Affiliate commissions: $1.37
- Exchange keeps: $3.13

## VIP Level Commission Rates

| VIP Level | Commission Rate | Rebate Rate |
|-----------|----------------|-------------|
| 1 - Beginner | 10% | 5% |
| 2 - Intermediate | 20% | 10% |
| 3 - Advanced | 30% | 12% |
| 4 - VIP 1 | 40% | 15% |
| 5 - VIP 2 | 50% | 17% |
| 6 - Diamond | 70% | 20% |

## Safety Features

### Backup Commission Processing
Function `process_missed_affiliate_commissions()` available to retroactively process any fees that may have been missed:
```sql
SELECT * FROM process_missed_affiliate_commissions(NOW() - INTERVAL '24 hours');
```

### Trigger-Based Safety Net
Optional trigger `trigger_affiliate_on_fee` can be enabled to automatically catch any fee collections that didn't trigger affiliate payouts (currently disabled as functions handle it directly).

## Monitoring

### Check Affiliate Earnings
```sql
SELECT * FROM get_affiliate_stats(user_id);
```

### Check User's Referral Stats
```sql
SELECT * FROM referral_stats WHERE user_id = ?;
```

### View Recent Commissions
```sql
SELECT * FROM tier_commissions
WHERE affiliate_id = ?
ORDER BY created_at DESC
LIMIT 20;
```

### Check Fee Rebates
```sql
SELECT * FROM transactions
WHERE user_id = ?
  AND transaction_type = 'fee_rebate'
ORDER BY created_at DESC;
```

## Implementation Status

✅ All fee collection points integrated
✅ Affiliate commission distribution working
✅ Fee rebate system working
✅ VIP level calculation working
✅ 5-tier chain building working
✅ Multiple compensation plans supported
✅ Wallet separation preventing conflicts
✅ Build successful

## Next Steps

The system is fully operational. Consider:
1. Setting up scheduled jobs for `apply_funding_payment` (every 8 hours)
2. Setting up scheduled jobs for VIP level recalculation (daily)
3. Monitoring affiliate payouts for accuracy
4. Testing edge cases with real users
