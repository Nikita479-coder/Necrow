/*
  # Update User Rewards Table for Claim Tracking

  1. Changes
    - Add `task_id` column to track specific tasks
    - Add `reward_type` column to distinguish between fee_rebate and balance
    - Modify status to support 'available', 'claimed' states
    - Add description field for transaction history

  2. Security
    - Maintain existing RLS policies

  3. Notes
    - Allows tracking which tasks have been claimed to prevent duplicates
    - Supports both fee rebate and balance reward types
*/

-- Add new columns to user_rewards if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_rewards' AND column_name = 'task_id'
  ) THEN
    ALTER TABLE user_rewards ADD COLUMN task_id text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_rewards' AND column_name = 'reward_type'
  ) THEN
    ALTER TABLE user_rewards ADD COLUMN reward_type text;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_rewards' AND column_name = 'description'
  ) THEN
    ALTER TABLE user_rewards ADD COLUMN description text;
  END IF;
END $$;

-- Create index on task_id for faster duplicate checking
CREATE INDEX IF NOT EXISTS idx_user_rewards_task_id ON user_rewards(user_id, task_id);

-- Create unique constraint to prevent duplicate claims
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'unique_user_task_claim'
  ) THEN
    ALTER TABLE user_rewards ADD CONSTRAINT unique_user_task_claim UNIQUE(user_id, task_id);
  END IF;
END $$;
