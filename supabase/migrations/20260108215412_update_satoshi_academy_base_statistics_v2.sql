/*
  # Update Satoshi Academy Base Statistics

  1. Changes
    - Sets accurate base statistics for Satoshi Academy trader
    - These values serve as the starting point for all metrics
    - Actual trades will add on top of these base values

  2. Statistics Being Set
    - Total Trades: 1,918
    - Current Win Streak: 12
    - Max Win Streak: 18
    - Profitable Days: 22 / 32
    - Best Trade: +847,293.42 USDT
    - Worst Trade: -124,521.18 USDT
    - Avg Hold Time: 4 hours
    - Avg Leverage: 15.5x
    - Sharpe Ratio: 3.63
    - Max Drawdown (30d): 9.21%
    - Volatility Score: 0.0/100
    - Consistency Score: 94.5/100
    - Monthly Return: +1.04%
    - Total Volume: 847.85M USDT
    - Favorite Pairs: BTCUSDT, ETHUSDT

  3. Purpose
    - Provides realistic baseline statistics for the flagship trader
    - Ensures consistent display across the platform
    - Base values allow real trades to accumulate on top
*/

-- Update Satoshi Academy with specific base statistics
UPDATE traders
SET 
  -- Trade counts and streaks
  total_trades = 1918,
  win_streak = 12,
  loss_streak = 0,
  max_win_streak = 18,
  
  -- Trading days
  profitable_days = 22,
  trading_days = 32,
  
  -- Best/Worst trades
  best_trade_pnl = 847293.42,
  worst_trade_pnl = -124521.18,
  
  -- Trading style metrics
  avg_hold_time_hours = 4,
  avg_leverage = 15.5,
  
  -- Risk metrics
  sharpe_ratio = 3.63,
  mdd_30d = 9.21,
  volatility_score = 0.0,
  consistency_score = 94.5,
  
  -- Returns
  monthly_return = 1.04,
  
  -- Volume
  total_volume = 847850000,
  
  -- Favorite pairs
  favorite_pairs = ARRAY['BTCUSDT', 'ETHUSDT'],
  
  -- Win rate (calculated from profitable_days/trading_days ratio ~ 68.75%)
  win_rate = 68.75,
  
  -- Timestamp
  updated_at = NOW()
WHERE name = 'Satoshi Academy';

-- Also update the base metrics columns for proper accumulation
UPDATE traders
SET 
  base_total_trades = 1918,
  base_winning_trades = 1318,  -- ~68.75% of 1918
  base_volume = 847850000
WHERE name = 'Satoshi Academy';
