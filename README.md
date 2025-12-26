# Shark Trades - Crypto Trading Platform

A modern cryptocurrency trading platform with futures trading, copy trading, and more.

## Features

### Trading Features
- **Futures Trading** - Leverage trading with advanced charting
- **Spot Markets** - Real-time market data and trading
- **Token Swap** - Direct token exchange functionality

### Copy Trading System
- **Browse Traders** - Discover and analyze top performing traders
- **Mock Trading** - Practice copy trading with virtual funds (zero risk)
- **Active Copy Trading** - Copy real traders with actual funds
- **Executed Trades Only** - Live positions are hidden for trader privacy

### Account Features
- **User Authentication** - Secure login and signup with Supabase
- **Wallet Management** - Deposit and withdraw funds
- **KYC Verification** - Identity verification system
- **Profile Management** - Track your trading history and performance
- **Referral Program** - Earn rewards by referring new users

## Copy Trading Implementation

The copy trading system has been designed with the following key features:

### Pages Created
1. **CopyTrading.tsx** - Main discovery page to browse and select traders
2. **MockTrading.tsx** - Practice dashboard with virtual funds
3. **ActiveCopyTrading.tsx** - Real copy trading dashboard

### Key Constraints
- **Executed Trades Only**: Users can ONLY view completed/closed trades
- **No Live Positions**: Ongoing trades are hidden to protect trader strategies
- **Privacy First**: Prevents front-running and maintains strategy confidentiality

### How It Works
1. Browse traders on the Copy Trading page
2. Click "Mock" to practice with virtual funds
3. Click "Copy" to start copying with real funds
4. Monitor performance in "My Copies" dashboard
5. View executed trade history (live trades hidden)

## Tech Stack

- **Frontend**: React + TypeScript + Vite
- **Styling**: Tailwind CSS
- **Charts**: Lightweight Charts
- **Icons**: Lucide React
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth

## Future Implementation

See `COPY_TRADING_IMPLEMENTATION.txt` for detailed database schema, API endpoints, and implementation roadmap.

### Database Tables (To Be Created)
- `traders` - Trader profiles and statistics
- `executed_trades` - All closed trades
- `user_copied_traders` - User's active copy relationships
- `user_copied_trades` - User's copied trade history

### Features Coming Soon
- Real-time trade execution
- Portfolio analytics
- Advanced filtering
- Trade notifications
- Performance charts

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Security Notes

- Never expose live trader positions
- Validate all copy amounts against user balance
- Implement rate limiting on copy actions
- Audit trail for all copy trading actions
- Maximum investment limits per trader

## Disclaimers

⚠️ **Risk Warning**: Copy trading involves significant risk. Past performance is not indicative of future results. You could lose all of your invested capital. Always do your own research before copying traders.
