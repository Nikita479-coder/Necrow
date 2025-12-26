/*
  # Fix trader_trades and copy_relationships schema issues

  1. Changes
    - Add `updated_at` column to `trader_trades` table
    - Add foreign key from `copy_relationships.follower_id` to `user_profiles.id`
    
  2. Security
    - No RLS changes needed
*/

-- Add updated_at column to trader_trades if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trader_trades' AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE trader_trades ADD COLUMN updated_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Add foreign key from copy_relationships to user_profiles if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'copy_relationships_follower_id_fkey'
    AND table_name = 'copy_relationships'
  ) THEN
    ALTER TABLE copy_relationships
    ADD CONSTRAINT copy_relationships_follower_id_fkey
    FOREIGN KEY (follower_id) REFERENCES user_profiles(id) ON DELETE CASCADE;
  END IF;
END $$;
