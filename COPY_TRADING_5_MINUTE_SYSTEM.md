# Copy Trading System - 5-Minute Manual Trade Acceptance

## Overview
The copy trading system has been redesigned to give users **5 minutes** to manually accept or decline each trade signal from traders they follow. This ensures users have full control over which trades they participate in while maintaining quick response times.

## How It Works

### 1. Admin Opens a Manual Trade
- Admin navigates to Admin Dashboard → Manage Traders
- Selects a trader and clicks "Manual Trade"
- Fills in trade details (pair, leverage, entry price, etc.)
- Enables "Auto-send Telegram notifications" (enabled by default)
- Clicks "Open Trade" to create the signal

### 2. Trade Signal Created
When a manual trade is opened:
- A position is immediately created in the trader's account
- A pending trade record is created with a **5-minute expiration**
- All active followers of that trader receive notifications via:
  - In-app notification badge
  - Telegram message (if Telegram is linked)
  - Real-time UI updates

### 3. Followers Receive Notification
Each follower receives:
- Push notification on Telegram with audio alert
- In-app notification in the "Pending Trades" section
- Real-time countdown timer showing time remaining
- Trade details: pair, leverage, entry price, position size

**Important:** The trade direction (long/short) is hidden until acceptance to protect the trader's strategy.

### 4. User Response Window (5 Minutes)
Users have exactly **5 minutes** to respond with one of three actions:

#### Accept Trade
- User clicks "Accept Trade"
- Reviews risk disclosure and trade summary
- Checks "I acknowledge the risks" checkbox
- Confirms acceptance
- System immediately:
  - Calculates allocation based on user's copy wallet balance
  - Deducts margin from user's copy wallet
  - Creates position allocation tracking record
  - Adds trade to user's active positions
  - Sends confirmation notification

#### Decline Trade
- User clicks "Decline"
- Optionally provides a reason
- Confirms decline
- No funds are deducted
- No record appears in trading history
- Trade signal is dismissed from pending list

#### Expires (No Action)
- After 5 minutes, pending trade automatically expires
- No funds are deducted
- No position is created
- Trade is removed from pending list
- Notification is marked as expired

### 5. Trade Execution and Tracking
For users who **accepted** the trade:
- Position appears in "Active Positions" on the Active Copy Trading page
- Real-time PnL updates based on market price movements
- When trader closes the position, all followers' positions close automatically
- PnL is calculated based on each user's allocated amount
- Profits/losses are credited/debited to copy wallet
- Closed positions appear in trading history

For users who **declined or ignored** the trade:
- No position is created
- No balance changes occur
- No entry in trading history
- Trade signal simply disappears after expiration

## Urgency Levels

The countdown timer uses color-coded urgency levels:

- **🟢 Safe (3-5 minutes remaining):** Green - plenty of time to review
- **🟡 Warning (1-3 minutes remaining):** Yellow - should make a decision soon
- **🔴 Critical (< 1 minute remaining):** Red - urgent action required

## Percentage-Based Fast Trades (Unchanged)

The "Quick % Trade" system operates separately and is **NOT affected** by this redesign:

- Admin clicks "Quick % Trade" and enters a target percentage (e.g., +1.2% or -0.5%)
- System instantly executes and closes a trade
- All active followers' balances are updated immediately
- No notification or user acceptance required
- No countdown timer or pending period
- Used for quick balance adjustments without exposing strategy details

## Technical Details

### Database Schema
- **pending_copy_trades:** Stores pending trades with 5-minute expiration
- **copy_trade_allocations:** Tracks accepted trades and positions
- **notifications:** Stores in-app notification records
- **telegram_notifications_log:** Tracks Telegram message delivery

### Edge Functions
- **create_pending_trade_only:** Creates pending trade with 5-minute window
- **respond_to_copy_trade:** Handles user accept/decline responses
- **expire-pending-trades:** Auto-expires trades past 5-minute mark
- **telegram-notify-trade:** Sends Telegram notifications to followers

### Frontend Components
- **PendingTradeCard:** Displays trade with countdown timer and action buttons
- **TradeResponseModal:** Risk disclosure and confirmation flow
- **CopyTrading:** Main page with pending trades section
- **ActiveCopyTrading:** Shows active positions and allows responses

### Real-time Updates
- WebSocket subscriptions for instant UI updates
- Countdown timers update every second
- Automatic expiration checks every 30 seconds
- Real-time notification delivery status

## Benefits of This System

1. **User Control:** Users decide which trades to participate in
2. **Risk Management:** Clear risk disclosure before acceptance
3. **No Surprise Trades:** Users are never auto-copied into positions
4. **Strategy Protection:** Trade direction hidden until acceptance
5. **Quick Response:** 5-minute window ensures timely decisions
6. **Transparent Tracking:** Clear history of accepted, declined, and expired trades
7. **Flexible Options:** Percentage trades still available for instant execution

## Admin Monitoring

Admins can view real-time statistics for each pending trade:
- Total followers notified
- Number of acceptances
- Number of declines
- Number of expirations
- Telegram delivery status (sent, failed, blocked)

## User Experience Flow

```
Admin Opens Trade
       ↓
Notifications Sent (Telegram + In-app)
       ↓
User Sees Pending Trade (5-minute timer starts)
       ↓
    ┌──────┴──────┬─────────────┐
    ↓             ↓             ↓
  Accept       Decline       Expires
    ↓             ↓             ↓
Position      Nothing      Nothing
Created       Happens      Happens
    ↓
Trade Appears in Active Positions
    ↓
Trader Closes Position
    ↓
User's Position Closes Automatically
    ↓
PnL Settled to Copy Wallet
```

## Migration Notes

- Existing percentage-based trades continue to work as before
- All pending trades now expire in 5 minutes (updated from 10 minutes)
- Expired trades are automatically cleaned up every 30 seconds
- Historical data remains intact
- No user action required for migration

## Future Enhancements

Potential improvements for future releases:
- Configurable expiration time per trader (3, 5, or 10 minutes)
- Default action settings (auto-accept or auto-decline per trader)
- Trade signal preview without acceptance
- Advanced filtering for pending trades
- Analytics on user response patterns
