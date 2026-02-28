/*
  # Update trader_trades to accept both buy/sell and long/short
  
  1. Changes
    - Update constraint to accept both old (buy/sell) and new (long/short) values
    - Sync existing admin positions
  
  2. Purpose
    - Backward compatibility with existing data
    - Allow admin-managed trader positions to sync
*/

-- Drop old constraint
ALTER TABLE trader_trades DROP CONSTRAINT IF EXISTS trader_trades_side_check;

-- Add new constraint that accepts all four values
ALTER TABLE trader_trades 
ADD CONSTRAINT trader_trades_side_check 
CHECK (side IN ('buy', 'sell', 'long', 'short'));

-- Now sync existing open admin positions to trader_trades
INSERT INTO trader_trades (
  trader_id, symbol, side, entry_price, quantity, leverage,
  pnl, pnl_percent, status, opened_at
)
SELECT 
  trader_id, 
  pair as symbol, 
  side, 
  entry_price, 
  quantity, 
  leverage,
  COALESCE(realized_pnl, 0) as pnl,
  COALESCE(pnl_percentage, 0) as pnl_percent,
  status, 
  opened_at
FROM admin_trader_positions
WHERE status = 'open'
AND NOT EXISTS (
  SELECT 1 FROM trader_trades tt
  WHERE tt.trader_id = admin_trader_positions.trader_id
  AND tt.symbol = admin_trader_positions.pair
  AND tt.entry_price = admin_trader_positions.entry_price
  AND tt.status = 'open'
);
