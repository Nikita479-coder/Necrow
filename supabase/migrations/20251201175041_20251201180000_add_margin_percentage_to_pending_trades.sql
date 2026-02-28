/*
  # Add Margin Percentage Field to Pending Copy Trades

  ## Overview
  Updates the pending_copy_trades table to store the percentage of balance used,
  enabling percentage-based position mirroring where followers use the same
  percentage of their balance as the trader.

  ## Changes
  1. Add `margin_percentage` field to `pending_copy_trades` table
     - Stores the % of balance used (e.g., 10.00 for 10%)
     - Required field with check constraint for valid percentage range
  
  2. This enables:
     - Proportional position sizing across different account sizes
     - Strategy privacy protection (hide absolute amounts)
     - Easier understanding for followers ("use 10% like the trader")

  ## Example
  - Trader uses 10% of $100,000 = $10,000 margin
  - Follower A uses 10% of $5,000 = $500 margin
  - Follower B uses 10% of $20,000 = $2,000 margin
  - All maintain same risk exposure proportionally
*/

-- Add margin_percentage column to pending_copy_trades
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pending_copy_trades' AND column_name = 'margin_percentage'
  ) THEN
    ALTER TABLE pending_copy_trades 
    ADD COLUMN margin_percentage numeric NOT NULL DEFAULT 0 
    CHECK (margin_percentage >= 0.01 AND margin_percentage <= 100);
  END IF;
END $$;

-- Add comment explaining the field
COMMENT ON COLUMN pending_copy_trades.margin_percentage IS 
'Percentage of balance used for this trade (e.g., 10.00 for 10%). Followers mirror this percentage using their own balance.';
