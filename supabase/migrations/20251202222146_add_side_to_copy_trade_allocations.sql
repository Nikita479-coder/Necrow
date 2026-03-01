/*
  # Add Side Column to Copy Trade Allocations
  
  ## Changes
  - Add `side` column to copy_trade_allocations to track long/short
  - Update existing records to populate side from trader_trades
  
  ## Security
  - No RLS changes needed
*/

-- Add side column
ALTER TABLE copy_trade_allocations
ADD COLUMN IF NOT EXISTS side text;

-- Update existing records to populate side from trader_trades
UPDATE copy_trade_allocations cta
SET side = tt.side
FROM trader_trades tt
WHERE cta.trader_trade_id = tt.id
AND cta.side IS NULL;
