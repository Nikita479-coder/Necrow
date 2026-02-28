/*
  # Add is_mock column to copy_relationships

  1. Changes
    - Add is_mock boolean column to copy_relationships table
    - Default to false for existing relationships
    - Update status column if it doesn't exist
    
  2. Notes
    - This allows tracking whether a copy relationship is mock or real
    - Mock relationships don't require actual wallet balance
*/

-- Add is_mock column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_relationships' AND column_name = 'is_mock'
  ) THEN
    ALTER TABLE copy_relationships ADD COLUMN is_mock boolean DEFAULT false NOT NULL;
  END IF;
END $$;

-- Add status column if it doesn't exist (from newer migration)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_relationships' AND column_name = 'status'
  ) THEN
    ALTER TABLE copy_relationships ADD COLUMN status text DEFAULT 'active' NOT NULL 
    CHECK (status IN ('active', 'stopped', 'paused'));
  END IF;
END $$;

-- Add ended_at column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_relationships' AND column_name = 'ended_at'
  ) THEN
    ALTER TABLE copy_relationships ADD COLUMN ended_at timestamptz;
  END IF;
END $$;