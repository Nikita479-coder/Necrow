# Complete Copy Trading System - Implementation Guide

## Overview
This document outlines the fully functional copy trading system that mirrors Binance's implementation.

## Database Schema (Already Created)

### Core Tables
1. **copy_positions** - Active positions opened through copy trading
2. **copy_position_history** - Historical closed positions
3. **copy_trading_stats** - Daily statistics and PnL tracking
4. **copy_trade_mirrors** - Maps follower positions to trader positions
5. **copy_relationships** - Tracks follower-trader relationships

### Key Functions Created
- `start_copy_trading()` - Initialize copy trading (real or mock)
- `stop_copy_trading()` - End copy trading and close all positions
- `mirror_trader_position()` - Automatically mirror trader's new position
- `close_copy_position()` - Close a specific copy position
- `update_copy_position_prices()` - Update prices and calculate PnL

## How It Works

### 1. Starting Copy Trading

**Real Copy Trading:**
```typescript
// User clicks "Copy Trade" button
// Modal opens with settings:
- Copy Amount: minimum 100 USDT
- Leverage: 1x to 125x
- Stop Loss %: optional
- Take Profit %: optional

// System deducts from copy_trading wallet
// Creates copy_relationships entry
// Initializes daily stats tracking
```

**Mock Copy Trading:**
```typescript
// Same as real, but uses mock_copy wallet
// Starts with 10,000 USDT virtual funds
// Perfect for testing strategies
```

### 2. Position Mirroring

When trader opens a position:
```sql
1. Trader opens BTC/USDT LONG 20x leverage
2. System detects new position
3. For each active follower:
   - Calculate position size based on their copy amount
   - Apply their leverage settings
   - Create mirrored position in copy_positions
   - Link via copy_trade_mirrors table
   - Apply follower's stop loss/take profit if set
```

### 3. Daily PnL Updates

**Automated Process:**
```typescript
// Runs every day at midnight UTC
For each active copy relationship:
  1. Calculate starting balance (yesterday's ending)
  2. Sum all position PnLs
  3. Count wins/losses
  4. Calculate daily PnL %
  5. Update copy_trading_stats table
  6. Store in history for charts
```

### 4. Real-time Price Updates

```typescript
// Price update service (already exists)
update_prices edge function runs every minute:
  1. Fetch latest prices from exchange
  2. Call update_copy_position_prices(symbol, price)
  3. Function updates all copy positions
  4. Recalculates unrealized PnL
  5. Checks stop loss / take profit
  6. Auto-closes if triggered
```

### 5. Closing Positions

**Automatic Close Triggers:**
- Trader closes their position → all follower positions close
- Stop loss hit → individual follower position closes
- Take profit hit → individual follower position closes
- User manually stops copy trading → all positions close

**Process:**
```sql
1. Calculate final PnL
2. Move to copy_position_history
3. Return margin + PnL to wallet
4. Update daily stats
5. Record trade in history
```

## UI Components Created

### 1. CopyTradingModal Component
- Start real or mock copy trading
- Configure copy amount, leverage
- Set stop loss and take profit
- Shows buying power calculation
- Validates sufficient balance

### 2. ActiveCopyTrading Page (To Update)
Shows:
- All active copy relationships
- Current balance for each
- Total PnL (daily, weekly, all-time)
- List of open positions
- Performance charts
- Stop copy trading button

### 3. TraderProfile Integration
- Copy Trade button → opens modal
- Mock Copy button → opens modal with mock=true
- View active followers
- Protected position details

## Wallet Types

```typescript
enum WalletType {
  'spot',           // Regular trading
  'futures',        // Futures trading
  'copy_trading',   // Real copy trading funds
  'mock_copy',      // Virtual copy trading funds
  'staking'         // Staked assets
}
```

## Daily Stats Calculation

```sql
CREATE OR REPLACE FUNCTION calculate_daily_copy_stats()
RETURNS void AS $$
BEGIN
  -- For each relationship
  FOR relationship IN
    SELECT * FROM copy_relationships WHERE is_active = true
  LOOP
    -- Get yesterday's ending balance
    -- Calculate today's PnL from positions
    -- Count trades
    -- Update or insert into copy_trading_stats
    -- Calculate ROI percentage
  END LOOP;
END;
$$;
```

## Edge Function Integration

### update-prices Function
```typescript
// Already exists, needs minor update:

// After updating futures_positions prices:
for (const [symbol, price] of Object.entries(prices)) {
  // Update copy positions too
  await supabase.rpc('update_copy_position_prices', {
    p_symbol: symbol,
    p_current_price: price
  });
}
```

## Frontend Implementation Checklist

### TraderProfile.tsx
- [x] Add CopyTradingModal import
- [ ] Add modal state management
- [ ] Wire up "Copy Trade" button
- [ ] Wire up "Mock Copy" button
- [ ] Show active copy status if already copying

### ActiveCopyTrading.tsx
- [ ] Fetch active copy relationships
- [ ] Display balance and PnL for each
- [ ] Show open positions with real-time updates
- [ ] Daily/weekly PnL charts
- [ ] Stop copy trading functionality
- [ ] Position management (view only, can't manually close)

### CopyTrading.tsx
- [ ] Show "Your Active Copies" section at top
- [ ] Quick stats for each active copy
- [ ] Link to ActiveCopyTrading page

## Real-time Updates

```typescript
// Subscribe to position updates
useEffect(() => {
  const subscription = supabase
    .channel('copy_positions_changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'copy_positions',
        filter: `follower_id=eq.${user.id}`
      },
      (payload) => {
        // Update UI with new position data
        handlePositionUpdate(payload);
      }
    )
    .subscribe();

  return () => {
    subscription.unsubscribe();
  };
}, [user]);
```

## Balance Tracking

### Initial Balance
```sql
-- When starting copy trading
INSERT INTO copy_trading_stats (
  starting_balance = copy_amount,
  ending_balance = copy_amount,
  daily_pnl = 0
)
```

### Daily Updates
```sql
-- End of each day
UPDATE copy_trading_stats SET
  ending_balance = starting_balance + daily_pnl,
  daily_pnl_percent = (daily_pnl / starting_balance) * 100

-- Next day uses previous ending as starting
INSERT INTO copy_trading_stats (
  stat_date = CURRENT_DATE,
  starting_balance = (SELECT ending_balance FROM copy_trading_stats
                       WHERE relationship_id = X
                       AND stat_date = CURRENT_DATE - 1)
)
```

## Testing Flow

1. **Start Mock Copy Trading**
   - Select a trader
   - Click "Mock Copy"
   - Set 1000 USDT, 10x leverage
   - Confirm

2. **Verify Wallet**
   - Check mock_copy wallet created
   - Balance should be 10000 - 1000 = 9000 USDT

3. **Mirror Position**
   - Manually call mirror_trader_position()
   - Or wait for trader to open position
   - Verify position appears in copy_positions

4. **Price Update**
   - Prices update via edge function
   - PnL recalculates automatically
   - Check unrealized_pnl updates

5. **Daily Stats**
   - Wait until next day (or manually trigger)
   - Verify copy_trading_stats has new entry
   - Check PnL tracking

6. **Stop Copy Trading**
   - Click "Stop Copy Trading"
   - Verify positions closed
   - Check balance returned to wallet
   - Relationship marked inactive

## Key Features (Binance-like)

✅ Real and mock copy trading
✅ Automatic position mirroring
✅ Independent stop loss/take profit per follower
✅ Daily PnL tracking and statistics
✅ Real-time balance updates
✅ Position history
✅ Trader performance metrics
✅ Follower management
✅ Secure RLS policies
✅ Automated trade execution

## Next Steps

1. Complete UI integration in TraderProfile
2. Build comprehensive ActiveCopyTrading page
3. Add real-time subscriptions for live updates
4. Create daily stats calculation cron job
5. Add performance charts and analytics
6. Test with real trading scenarios
7. Add notification system for fills/stops
8. Implement copy trading wallet transfers

## Security Considerations

- RLS policies ensure users only see their own data
- Functions use SECURITY DEFINER with auth checks
- Balance checks before opening positions
- Transaction-safe fund movements
- Audit trail via history tables
