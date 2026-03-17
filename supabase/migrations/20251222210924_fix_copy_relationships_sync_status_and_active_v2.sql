/*
  # Fix Copy Relationships Status and is_active Synchronization

  1. Changes
    - Sync all copy_relationships where is_active and status don't match
    - If is_active = false, set status = 'stopped'
    - If status = 'active', set is_active = true
    - Add a trigger to keep these fields synchronized going forward

  2. Notes
    - This fixes the issue where relationships show as "already copying" but don't appear in Active tab
    - Ensures consistency between is_active boolean and status field
*/

-- First, fix existing data: if is_active is false, status should be 'stopped'
UPDATE copy_relationships
SET status = 'stopped', ended_at = updated_at
WHERE is_active = false AND status != 'stopped';

-- If status is 'active', is_active should be true
UPDATE copy_relationships
SET is_active = true
WHERE status = 'active' AND is_active = false;

-- Create a trigger function to keep these fields in sync
CREATE OR REPLACE FUNCTION sync_copy_relationship_status()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- If is_active is being set to false, update status to 'stopped'
  IF NEW.is_active = false AND OLD.is_active = true THEN
    NEW.status := 'stopped';
    NEW.ended_at := NOW();
  END IF;
  
  -- If status is being set to 'stopped', set is_active to false
  IF NEW.status = 'stopped' AND OLD.status != 'stopped' THEN
    NEW.is_active := false;
    NEW.ended_at := NOW();
  END IF;
  
  -- If status is being set to 'active', set is_active to true
  IF NEW.status = 'active' AND OLD.status != 'active' THEN
    NEW.is_active := true;
  END IF;
  
  -- If is_active is being set to true, set status to 'active'
  IF NEW.is_active = true AND OLD.is_active = false THEN
    NEW.status := 'active';
    NEW.ended_at := NULL;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop the trigger if it exists and recreate it
DROP TRIGGER IF EXISTS sync_copy_relationship_status_trigger ON copy_relationships;

CREATE TRIGGER sync_copy_relationship_status_trigger
  BEFORE UPDATE ON copy_relationships
  FOR EACH ROW
  EXECUTE FUNCTION sync_copy_relationship_status();
