/*
  # Fix Revoke Trusted IP Authorization

  ## Description
  Fixes the revoke_trusted_ip function to properly handle authorization.
  The issue was that auth.uid() might not match the user_id stored in the table
  due to how the JWT is processed.

  ## Changes
  1. Drop and recreate the revoke_trusted_ip function
  2. Use a more robust ownership check
*/

-- Drop existing function
DROP FUNCTION IF EXISTS revoke_trusted_ip(uuid);

-- Recreate with fixed authorization
CREATE OR REPLACE FUNCTION revoke_trusted_ip(
  p_trusted_ip_id uuid
)
RETURNS boolean AS $$
DECLARE
  v_user_id uuid;
  v_current_user_id uuid;
BEGIN
  -- Get the current user from auth
  v_current_user_id := auth.uid();
  
  IF v_current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get the user_id to verify ownership
  SELECT user_id INTO v_user_id
  FROM trusted_ips
  WHERE id = p_trusted_ip_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trusted IP not found';
  END IF;

  -- Verify the caller owns this trusted IP
  IF v_user_id IS DISTINCT FROM v_current_user_id THEN
    RAISE EXCEPTION 'Not authorized to revoke this trusted IP';
  END IF;

  -- Mark as not trusted instead of deleting (for audit trail)
  UPDATE trusted_ips
  SET is_trusted = false,
      updated_at = now()
  WHERE id = p_trusted_ip_id
    AND user_id = v_current_user_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION revoke_trusted_ip(uuid) TO authenticated;
