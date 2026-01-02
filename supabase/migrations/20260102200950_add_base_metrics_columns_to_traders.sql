/*
  # Add Base Metrics Columns to Traders

  1. Changes
    - Add base_ columns to store starting values for key metrics
    - These base values remain constant
    - Actual trades add on top of these base values
    
  2. New Columns
    - base_total_trades: Starting trade count
    - base_win_rate: Starting win rate percentage
    - base_pnl: Starting cumulative PNL
    - base_volume: Starting trading volume
*/

-- Add base metric columns
ALTER TABLE traders
ADD COLUMN IF NOT EXISTS base_total_trades integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_winning_trades integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_pnl numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS base_volume numeric DEFAULT 0;

-- Set current values as base values for Satoshi Academy
UPDATE traders
SET 
  base_total_trades = total_trades,
  base_winning_trades = FLOOR(total_trades * (win_rate / 100)),
  base_pnl = 0,  -- Start fresh for PNL tracking from actual trades
  base_volume = total_volume
WHERE name = 'Satoshi Academy';
