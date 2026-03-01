/*
  # Fix VIP Tier Name Function
  
  Update the get_vip_tier_name() function to fetch tier names from the vip_levels table
  instead of using hardcoded values, so it displays Beginner, Intermediate, Advanced, etc.
*/

CREATE OR REPLACE FUNCTION get_vip_tier_name(vip_level integer)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_tier_name text;
BEGIN
  -- Fetch the tier name from vip_levels table
  SELECT level_name INTO v_tier_name
  FROM vip_levels
  WHERE level_number = vip_level;
  
  -- If not found, return 'Unknown'
  IF v_tier_name IS NULL THEN
    RETURN 'Unknown';
  END IF;
  
  RETURN v_tier_name;
END;
$$;
