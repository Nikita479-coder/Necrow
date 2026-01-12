# Referral System - Complete Implementation

## Overview
The referral system is fully functional and tracks commissions, rebates, volumes, and VIP levels automatically on every trade.

## How It Works

### 1. User Signs Up with Referral Code
- New user enters referral code during signup
- `referred_by` field is set in `user_profiles` table
- Referral relationship is established

### 2. Referred User Makes Their First Trade
When a referred user opens a position (futures) or executes a swap:
- `distribute_trading_fees()` is called automatically
- System checks if user has a referrer
- If this is their first trade:
  - `referral_stats` entry is created for referrer (if doesn't exist)
  - `total_referrals` count is incremented
  - Referrer gets their first commission

### 3. Commission Distribution
For every trade a referred user makes:
- **Referrer Earns Commission:**
  - Commission = (Trading Fee × VIP Commission Rate)
  - Rates: 10% (VIP 1) up to 70% (VIP 6)
  - Added to referrer's USDT spot wallet instantly
  - Tracked in `referral_commissions` table
  - Added to `total_earnings` and `this_month_earnings`

### 4. Rebate Distribution (First 30 Days)
For new users within 30 days of signup:
- **Referee Gets Rebate:**
  - Rebate = (Trading Fee × VIP Rebate Rate)
  - Rates: 5% (VIP 1) up to 15% (VIP 6)
  - Added to their USDT spot wallet instantly
  - Tracked in `referral_rebates` table
  - Expires after 30 days from signup

### 5. VIP Level Calculation
VIP levels are based on 30-day referral trading volume:
- **VIP 1:** $0 - $10,000 → 10% commission, 5% rebate
- **VIP 2:** $10,001 - $100,000 → 20% commission, 6% rebate
- **VIP 3:** $100,001 - $500,000 → 30% commission, 7% rebate
- **VIP 4:** $500,001 - $2,500,000 → 40% commission, 8% rebate
- **VIP 5:** $2,500,001 - $25,000,000 → 50% commission, 10% rebate
- **VIP 6:** $25,000,001+ → 70% commission, 15% rebate

VIP level auto-updates on every trade based on volume.

## Database Tables

### `referral_stats`
Tracks each referrer's statistics:
- `user_id` - The referrer
- `vip_level` - Current VIP level (1-6)
- `total_referrals` - Count of unique users referred
- `total_earnings` - Lifetime commission earnings
- `this_month_earnings` - Current month earnings
- `total_volume_30d` - Last 30 days trading volume of referrals
- `total_volume_all_time` - All-time trading volume

### `referral_commissions`
Individual commission records:
- `referrer_id` - Who earned the commission
- `referee_id` - Who made the trade
- `transaction_id` - Related transaction
- `trade_amount` - Notional value of trade
- `fee_amount` - Trading fee charged
- `commission_rate` - Rate applied (10-70%)
- `commission_amount` - Amount earned
- `vip_level` - VIP level at time of commission

### `referral_rebates`
Individual rebate records:
- `user_id` - Who received the rebate
- `transaction_id` - Related transaction
- `original_fee` - Original trading fee
- `rebate_rate` - Rate applied (5-15%)
- `rebate_amount` - Amount refunded
- `expires_at` - When rebate eligibility expires

## Key Functions

### `distribute_trading_fees(user_id, transaction_id, trade_amount, fee_amount)`
**Called automatically on every trade**
- Checks if user has a referrer
- Calculates commission based on VIP level
- Updates referrer's stats (earnings, volume, VIP level)
- Adds commission to referrer's USDT spot wallet
- If referee is within 30 days: calculates and adds rebate
- Creates wallet if it doesn't exist
- Increments total_referrals on first trade

### `calculate_vip_level(volume_30d)`
- Takes 30-day volume as input
- Returns VIP level (1-6)
- Used to determine commission/rebate rates

### `get_commission_rate(vip_level)`
- Returns commission rate for VIP level
- Range: 10% to 70%

### `get_rebate_rate(vip_level)`
- Returns rebate rate for VIP level
- Range: 5% to 15%

### `reset_monthly_earnings()`
- Resets all `this_month_earnings` to 0
- Should be called on 1st of each month
- Handled by edge function

### `update_30day_volumes()`
- Recalculates 30-day volumes from actual trades
- Updates VIP levels accordingly
- Should be called daily
- Handled by edge function

### `get_referred_users(referrer_id)`
- Returns list of users referred by someone
- Shows masked emails (abc•••@domain.com)
- Shows total trades and volume per referral
- Used in frontend to display referral list

## Trading Integration

The referral system is integrated with all trading operations:

### Futures Trading
- `place_market_order()` → calls `distribute_trading_fees()`
- `close_position_market()` → calls `distribute_trading_fees()`
- Trading fee is distributed to referrer
- Volume is added to 30-day tracking

### Swap Trading
- `execute_instant_swap()` → calls `distribute_trading_fees()`
- Swap fees are distributed to referrer
- Volume is added to 30-day tracking

## Maintenance

### Automated via Edge Function
The `update-referral-stats` edge function runs daily (should be scheduled):
- Updates 30-day volumes for all users
- Recalculates VIP levels
- On 1st of month: resets monthly earnings

### Manual Testing
You can manually trigger maintenance:
```sql
-- Update 30-day volumes
SELECT update_30day_volumes();

-- Reset monthly earnings (do this on 1st of month)
SELECT reset_monthly_earnings();
```

## Frontend Display

### Referral Page (`/referral`)
Shows:
- User's referral code and shareable link
- Current VIP level and progress
- Total earnings, active referrals, monthly earnings
- Commission and rebate rates
- List of referred users with masked emails
- 30-day volume progress bar
- VIP level comparison table

### Data Flow
1. Page loads → calls `referral_stats` for user's stats
2. Calls `get_referred_users()` for list of referrals
3. Shows real-time data from database
4. All $0.00 if no referrals yet

## Testing the System

### Step 1: Create Test Users
```sql
-- User A will be the referrer
-- User B will be the referee (signs up with User A's code)
```

### Step 2: Sign Up User B with User A's Code
- User B enters User A's referral code during signup
- `user_profiles.referred_by` is set to User A's ID

### Step 3: User B Makes a Trade
```sql
-- Simulate User B opening a futures position
SELECT place_market_order(
  'user_b_id',
  'BTC/USDT',
  'long',
  0.1,
  10,
  'cross'
);
```

### Step 4: Verify Results
```sql
-- Check User A's referral stats
SELECT * FROM referral_stats WHERE user_id = 'user_a_id';

-- Check commission records
SELECT * FROM referral_commissions WHERE referrer_id = 'user_a_id';

-- Check User A's wallet (should have commission)
SELECT * FROM wallets
WHERE user_id = 'user_a_id'
  AND currency = 'USDT'
  AND wallet_type = 'spot';

-- Check User B's rebate (if within 30 days)
SELECT * FROM referral_rebates WHERE user_id = 'user_b_id';
```

## Security

### Row Level Security (RLS)
- Users can only view their own commission records
- Users can only view their own rebate records
- All queries are secured with proper policies

### Wallet Safety
- Wallets are auto-created if they don't exist
- All balance updates are atomic transactions
- Cannot go negative

## Important Notes

1. **Commissions are instant** - No claiming required, added to wallet immediately
2. **VIP levels auto-update** - Recalculated on every trade based on volume
3. **30-day rolling window** - Volume is based on trades in last 30 days
4. **Monthly earnings reset** - Call edge function on 1st of each month
5. **Rebates expire** - Only for first 30 days after signup
6. **Spot wallet used** - All commissions/rebates go to USDT spot wallet
7. **Total referrals count first trade** - Not just signup, prevents fake referrals

## Troubleshooting

### User not getting commission?
1. Check if referee has `referred_by` set
2. Verify trade actually went through
3. Check `referral_commissions` table for record
4. Verify wallet exists and has correct balance

### VIP level not updating?
1. Run `SELECT update_30day_volumes();`
2. Check `total_volume_30d` in `referral_stats`
3. Verify volume thresholds

### Monthly earnings not showing?
1. Check `this_month_earnings` column exists
2. Verify edge function is running monthly
3. Check for recent commission records

## Next Steps (Optional Enhancements)

1. **Email Notifications** - Notify users of new referrals and commissions
2. **Referral Leaderboard** - Show top earners
3. **Custom Commission Rates** - Allow admin to set custom rates per user
4. **Referral Campaigns** - Time-limited bonus rates
5. **Multi-tier Referrals** - Commission on referrals' referrals
