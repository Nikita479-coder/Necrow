/*
  # Fix Pending Copy Trades to Reference Traders Table

  ## Overview
  Changes the foreign key constraint on pending_copy_trades.trader_id
  to reference the traders table instead of user_profiles. This allows
  admin-managed traders (which are synced to traders table) to create
  pending copy trades.

  ## Changes
  - Drops existing foreign key constraint to user_profiles
  - Adds new foreign key constraint to traders table
  - Maintains data integrity while allowing managed traders

  ## Security
  - Maintains referential integrity
  - No impact on RLS policies
  - Allows both real users (who are also in traders) and managed traders
*/

-- Drop the old foreign key constraint
ALTER TABLE pending_copy_trades
DROP CONSTRAINT IF EXISTS pending_copy_trades_trader_id_fkey;

-- Add new foreign key constraint to traders table
ALTER TABLE pending_copy_trades
ADD CONSTRAINT pending_copy_trades_trader_id_fkey
FOREIGN KEY (trader_id) REFERENCES traders(id) ON DELETE CASCADE;
