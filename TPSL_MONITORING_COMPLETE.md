# TP/SL Monitoring System with Notifications - Implementation Complete

## Overview
A comprehensive Take Profit and Stop Loss monitoring system has been implemented with two complementary approaches and full notification support:

1. **Real-time monitoring for online users** - Client-side service that checks every second
2. **Scheduled monitoring for offline users** - Edge function that can be triggered periodically
3. **Instant notifications** - Users receive notifications when positions close

## Components Implemented

### 1. Real-Time Client-Side Monitor
**File:** `src/services/tpslMonitorService.ts`

**Features:**
- Checks TP/SL conditions every 1 second (1000ms)
- Automatically starts when user opens the Futures Trading page
- Monitors all open positions with TP or SL set
- Instantly closes positions when conditions are met
- **Sends notifications to users when TP/SL triggers**
- Logs all TP/SL triggers to console

**How it works:**
- Fetches user's open positions with TP/SL
- Gets current market prices
- Compares current price against TP/SL levels
- Executes position closure immediately when triggered
- Creates notification with position details and P&L

### 2. Edge Function for Offline Monitoring
**File:** `supabase/functions/monitor-tpsl/index.ts`

**Features:**
- Checks ALL users' positions (not just online users)
- Can be triggered via HTTP POST request
- Returns detailed execution report
- **Sends notifications to users when TP/SL triggers**
- Handles errors gracefully
- Includes 50ms delay between position checks to avoid overwhelming DB

**Endpoint:**
```
POST https://your-project.supabase.co/functions/v1/monitor-tpsl
```

**Response format:**
```json
{
  "success": true,
  "checked": 5,
  "triggered": 2,
  "positions": [
    "BTCUSDT long - Take Profit",
    "ETHUSDT short - Stop Loss"
  ],
  "timestamp": "2025-12-02T17:30:00.000Z"
}
```

### 3. Notification System

**Notification Types:**
- `position_tp_hit` - Take Profit was triggered
- `position_sl_hit` - Stop Loss was triggered
- `position_closed` - Position manually closed by user

**Notification Content:**
Each notification includes:
- Title: "Take Profit Triggered", "Stop Loss Triggered", or "Position Closed"
- Message: Details about the position (pair, side, close price, P&L)
- Data: Complete position information for further actions

**Example Notification:**
```
Title: Take Profit Triggered
Message: Your BTCUSDT LONG position was closed at 91790.90. P&L: +178.10 USDT
```

### 4. Integration Points

**FuturesTrading.tsx:**
- Starts TP/SL monitor when page loads
- Stops monitor when user leaves page

**FuturesPositionsPanel.tsx:**
- Also starts TP/SL monitor (redundant but safe)
- Ensures monitoring continues as long as positions panel is visible
- Sends notification when user manually closes position

## TP/SL Logic

### Long Position:
- **Take Profit:** Triggered when `current_price >= take_profit`
- **Stop Loss:** Triggered when `current_price <= stop_loss`

### Short Position:
- **Take Profit:** Triggered when `current_price <= take_profit`
- **Stop Loss:** Triggered when `current_price >= stop_loss`

## Setup for Production

### Scheduling the Edge Function (Recommended)

You can set up automatic TP/SL monitoring for offline users using:

1. **Supabase Cron Jobs** (if available in your plan)
2. **External Cron Service** (like cron-job.org or EasyCron)
3. **GitHub Actions** (free for public repos)

**Example cron schedule:**
```
*/1 * * * * # Every 1 minute
*/5 * * * * # Every 5 minutes (recommended for cost savings)
```

**Example curl command:**
```bash
curl -X POST \
  https://your-project.supabase.co/functions/v1/monitor-tpsl \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

## Benefits

### Real-Time Monitoring (Online Users):
- **Instant execution** - 1 second check interval
- **No server costs** - Runs in browser
- **Accurate timing** - Executes at exact price levels

### Edge Function (Offline Users):
- **24/7 coverage** - Works when user is offline
- **Centralized** - One function handles all users
- **Reliable** - Server-side execution
- **Scalable** - Can monitor thousands of positions

## Performance Considerations

### Client-Side Monitor:
- Minimal battery/CPU impact (1 API call per second)
- Only active on Futures Trading page
- Automatically stops when user navigates away

### Edge Function:
- Batched processing with delays
- Only queries positions with TP/SL set
- Efficient database queries with proper indexes

## Testing

To test the system:

1. **Open a position with TP/SL:**
   - Go to Futures Trading
   - Open a long position on BTCUSDT
   - Set Take Profit above current price
   - Set Stop Loss below current price

2. **Test online monitoring:**
   - Wait for price to reach TP or SL
   - Position should close automatically within 1-2 seconds
   - Check console logs for "TP/SL Triggered" message
   - **Check notifications panel for new notification**

3. **Test offline monitoring:**
   - Trigger the edge function manually:
     ```bash
     curl -X POST https://your-project.supabase.co/functions/v1/monitor-tpsl \
       -H "Authorization: Bearer YOUR_ANON_KEY"
     ```
   - Check response for triggered positions
   - **Check notifications panel for new notification**

4. **Test manual close notification:**
   - Open any position
   - Click the "Close" button
   - **Check notifications panel for position closed notification**

## Monitoring and Logs

### Client-Side Logs:
- "TP/SL Monitor started" - When monitoring begins
- "TP/SL Triggered: [details]" - When position closes
- "TP/SL Monitor stopped" - When monitoring ends

### Edge Function Logs:
- View in Supabase Dashboard > Edge Functions > monitor-tpsl > Logs
- Shows all triggered positions and any errors

### Notifications:
- View in app notifications panel (bell icon in navbar)
- Real-time updates when positions close
- Includes P&L information

## Future Enhancements

Potential improvements:
1. ~~Add user notifications when TP/SL triggers~~ ✅ **COMPLETED**
2. Implement partial TP/SL (close portion of position)
3. Add trailing stop loss feature
4. Create TP/SL history/analytics dashboard
5. Add configurable check intervals per user
6. Add push notifications for mobile devices

## Summary

The TP/SL monitoring system is now fully functional and provides:
- **Real-time execution for online users** (1 second checks)
- **Background execution for offline users** (via edge function)
- **Instant notifications** when positions close (TP, SL, or manual)
- Reliable position closure at target prices
- Comprehensive error handling and logging
- Production-ready architecture

Users will experience instant TP/SL execution when they're actively trading, receive notifications for all position closures, and their positions remain protected even when they're offline through the scheduled edge function.
