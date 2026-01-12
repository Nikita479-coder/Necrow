# Real-Time TP/SL Monitoring System

## Overview

The Take Profit (TP) and Stop Loss (SL) monitoring system provides near real-time execution of trader-defined exit conditions. The system uses a multi-layered approach combining WebSocket price feeds, client-side monitoring, and database-backed position management.

## Key Features

### 1. Real-Time Price Updates
- **WebSocket Integration**: Connects to Bybit's WebSocket API for live price streaming
- **Update Frequency**: Prices update in real-time (sub-second latency)
- **Coverage**: Monitors 40+ cryptocurrency pairs simultaneously

### 2. Near Real-Time TP/SL Monitoring
- **Check Frequency**: Monitors positions every 500ms
- **Price Source**: Uses WebSocket prices (not database prices) for instant detection
- **Smart Debouncing**: Prevents duplicate triggers with 2-second cooldown per position
- **Processing Lock**: Ensures positions aren't processed multiple times simultaneously

### 3. Visual Feedback
- **Live PnL Updates**: Position P&L refreshes every second with real-time prices
- **Distance Indicators**: Shows percentage distance to TP/SL levels
- **Proximity Alerts**: Yellow pulsing animation when within 0.5% of trigger price
- **Active Monitoring Badge**: Green pulsing indicator when TP/SL monitoring is active
- **Real-time Price Dot**: Small green dot next to prices fed by WebSocket

## Architecture

### Frontend Components

#### 1. Price Store (`src/store/priceStore.ts`)
- Manages WebSocket connection to Bybit
- Maintains real-time price map for all trading pairs
- Publishes price updates to subscribers
- Auto-reconnects on connection loss

#### 2. TP/SL Monitor Service (`src/services/tpslMonitorService.ts`)
- Checks positions every 500ms for TP/SL triggers
- Uses real-time prices from price store
- Executes position closure via Supabase RPC
- Sends notifications on trigger events
- Prevents duplicate processing with locks and debouncing

#### 3. Price Update Service (`src/services/priceUpdateService.ts`)
- Calls backend edge function to update database prices
- Runs every 5 seconds as a fallback mechanism
- Ensures database prices stay relatively current

#### 4. Price Sync Service (`src/services/priceSyncService.ts`)
- Syncs WebSocket prices to database every 2 seconds
- Keeps database mark_price table updated
- Used for historical queries and reporting

### Backend Components

#### 1. Monitor TP/SL Edge Function (`supabase/functions/monitor-tpsl/index.ts`)
- Backend fallback monitoring system
- Checks all positions with TP/SL set
- Uses database prices for checking
- Can be called manually or on schedule
- Executes position closures and sends notifications

#### 2. Close Position RPC (`close_position`)
- Database function that handles position closure
- Calculates final P&L including fees
- Updates wallet balances
- Records transaction history
- Returns closure details

## How It Works

### TP/SL Execution Flow

1. **User Sets TP/SL**
   - Trader opens position and sets TP/SL levels via modal
   - Values stored in `futures_positions` table
   - Monitor service detects position has TP/SL set

2. **Real-Time Monitoring**
   - Every 500ms, monitor service queries open positions with TP/SL
   - For each position, gets current price from WebSocket price store
   - Compares current price against TP/SL thresholds

3. **Trigger Detection**
   - **Long Position TP**: Current Price >= Take Profit Price
   - **Long Position SL**: Current Price <= Stop Loss Price
   - **Short Position TP**: Current Price <= Take Profit Price
   - **Short Position SL**: Current Price >= Stop Loss Price

4. **Position Closure**
   - Adds position to processing lock to prevent duplicates
   - Calls `close_position` RPC with current market price
   - Position marked as closed in database
   - P&L calculated and settled to wallet
   - Transaction recorded in history

5. **User Notification**
   - Notification created via `send_notification` RPC
   - Shows trigger type (TP or SL)
   - Displays closure price and realized P&L
   - Includes position details

### Real-Time PnL Calculation

The positions panel calculates unrealized P&L in real-time:

```typescript
// For LONG positions
PnL = (Current_Price - Entry_Price) × Quantity

// For SHORT positions
PnL = (Entry_Price - Current_Price) × Quantity

// ROE (Return on Equity)
ROE = (PnL / Margin_Allocated) × 100
```

This calculation happens:
- Every 1 second via position refresh
- Using real-time WebSocket prices
- With visual color coding (green for profit, red for loss)

## Visual Indicators

### Position Table Indicators

1. **Mark Price**
   - Shows current market price
   - Small green dot when using WebSocket price
   - Updates in real-time

2. **PnL Column**
   - Green for positive, red for negative
   - Updates every second with real-time prices
   - Shows both USD amount and ROE percentage

3. **TP/SL Column**
   - Shows trigger price if set
   - Displays estimated P&L at trigger
   - Shows distance to trigger (%)
   - **Pulsing yellow** when within 0.5% of trigger

4. **Monitor Status Badge**
   - Appears in panel header when monitoring active
   - Pulsing green dot with "TP/SL Monitor Active" text
   - Only shows when user has positions with TP/SL set

## Performance Characteristics

### Latency Breakdown

- **Price Updates**: < 100ms (WebSocket)
- **Monitor Check Cycle**: 500ms
- **Position Fetch**: ~50-100ms (database query)
- **Close Execution**: ~200-300ms (RPC call)
- **Total Trigger Time**: ~750ms - 1s from price hit to closure

### System Load

- **WebSocket**: Minimal, push-based updates
- **Monitor Service**: Runs only when user logged in and has positions
- **Database Queries**: Filtered by user_id and status, indexed columns
- **RPC Calls**: Only on trigger events, not continuous

## Configuration

### Adjustable Parameters

In `tpslMonitorService.ts`:
```typescript
checkInterval: number = 500;  // How often to check (ms)
```

In `FuturesPositionsPanel.tsx`:
```typescript
refreshInterval = 1000;  // Position refresh rate (ms)
```

### Proximity Alert Threshold
In the TP/SL display logic:
```typescript
Math.abs(distance) < 0.5  // 0.5% threshold for yellow alert
```

## Database Schema

### futures_positions Table
```sql
position_id UUID PRIMARY KEY
user_id UUID NOT NULL
pair TEXT NOT NULL
side TEXT NOT NULL (long/short)
entry_price NUMERIC NOT NULL
mark_price NUMERIC NOT NULL
quantity NUMERIC NOT NULL
leverage INTEGER NOT NULL
margin_allocated NUMERIC NOT NULL
unrealized_pnl NUMERIC NOT NULL
liquidation_price NUMERIC NOT NULL
take_profit NUMERIC NULL        -- TP trigger price
stop_loss NUMERIC NULL           -- SL trigger price
status TEXT NOT NULL             -- open/closed
overnight_fees_accrued NUMERIC
opened_at TIMESTAMPTZ NOT NULL
closed_at TIMESTAMPTZ NULL
```

### market_prices Table
```sql
pair TEXT PRIMARY KEY
price NUMERIC NOT NULL
mark_price NUMERIC NOT NULL
volume NUMERIC NOT NULL
updated_at TIMESTAMPTZ NOT NULL
```

## Error Handling

### Connection Issues
- WebSocket auto-reconnects after 3 seconds
- Falls back to database prices if WebSocket unavailable
- Continues monitoring with available data

### Processing Errors
- Failed closures logged to console
- Position removed from processing lock to allow retry
- User notified of errors via toast messages

### Duplicate Prevention
- Processing lock prevents concurrent closure attempts
- 2-second debounce per position
- Database-level uniqueness constraints on position_id

## Testing Recommendations

1. **Set Wide TP/SL**
   - Test with triggers far from current price
   - Verify monitoring starts and badge shows

2. **Set Close TP/SL**
   - Set trigger within 1% of current price
   - Watch for yellow pulsing proximity alert
   - Observe rapid execution when price hits

3. **Multiple Positions**
   - Open multiple positions with different TP/SL levels
   - Verify all are monitored simultaneously
   - Check each triggers independently

4. **Edge Cases**
   - Test with rapidly moving prices
   - Verify no duplicate closures
   - Check P&L calculations are accurate

## Future Enhancements

Potential improvements:
- Add trailing stop loss functionality
- Support partial position closures at TP/SL
- Add mobile push notifications for triggers
- Implement advanced order types (OCO, bracket orders)
- Add TP/SL level adjustment from positions table
- Support multiple TP/SL levels per position
