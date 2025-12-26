/*
  # Update Copy Trading to Percentage-Based Allocation

  1. Changes to copy_relationships Table
    - Rename `copy_amount` to `allocation_percentage` (stores 1-100)
    - Convert existing fixed amounts to percentages (default to 20%)
    - Add description field for clarity

  2. Logic Changes
    - When admin opens trade, calculate follower allocation as: (follower_copy_wallet_balance * allocation_percentage / 100)
    - When admin closes trade, distribute PNL proportionally to follower's allocation
    - Update all related functions to use percentage-based calculations

  3. Notes
    - This makes copy trading work like futures trading with percentage-based position sizing
    - Followers' actual allocation depends on their copy wallet balance at trade open time
    - Example: If follower has 500 USDT and sets 20%, only 100 USDT enters the trade
*/

-- Update copy_relationships table structure
DO $$
BEGIN
  -- First, update all existing rows to use 20% as default
  UPDATE copy_relationships 
  SET copy_amount = 20 
  WHERE copy_amount IS NOT NULL;

  -- Rename copy_amount to allocation_percentage if it exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'copy_relationships' AND column_name = 'copy_amount'
  ) THEN
    ALTER TABLE copy_relationships 
    RENAME COLUMN copy_amount TO allocation_percentage;
  END IF;

  -- Update the column type and constraints
  ALTER TABLE copy_relationships 
  ALTER COLUMN allocation_percentage TYPE INTEGER USING allocation_percentage::INTEGER;

  -- Add check constraint to ensure percentage is between 1 and 100
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'copy_relationships_allocation_percentage_check'
  ) THEN
    ALTER TABLE copy_relationships 
    ADD CONSTRAINT copy_relationships_allocation_percentage_check 
    CHECK (allocation_percentage >= 1 AND allocation_percentage <= 100);
  END IF;
END $$;

-- Add comment for clarity
COMMENT ON COLUMN copy_relationships.allocation_percentage IS 'Percentage of copy wallet balance to allocate per trade (1-100)';
