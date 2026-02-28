/*
  # Add Copy Trading Bonus Tracking Columns

  ## Overview
  Adds columns to track the on-top bonus for copy trading relationships.
  The bonus is 100 USDT added directly to the copy wallet when user allocates 500+ USDT.

  ## Changes to copy_relationships table
  - `bonus_amount` (numeric) - Amount of bonus added on top (default 0)
  - `bonus_claimed_at` (timestamptz) - When the bonus was claimed
  - `bonus_locked_until` (timestamptz) - 30 days after claim, when bonus vests

  ## Indexes
  - Index on bonus_locked_until for efficient queries on active bonuses
*/

-- Add bonus tracking columns to copy_relationships
ALTER TABLE copy_relationships
ADD COLUMN IF NOT EXISTS bonus_amount numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS bonus_claimed_at timestamptz,
ADD COLUMN IF NOT EXISTS bonus_locked_until timestamptz;

-- Add index for querying active bonus locks
CREATE INDEX IF NOT EXISTS idx_copy_relationships_bonus_locked_until
ON copy_relationships(bonus_locked_until)
WHERE bonus_locked_until IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN copy_relationships.bonus_amount IS 'Amount of bonus USDT added on top of user allocation';
COMMENT ON COLUMN copy_relationships.bonus_claimed_at IS 'Timestamp when the bonus was claimed';
COMMENT ON COLUMN copy_relationships.bonus_locked_until IS '30 days after claim - when bonus fully vests';