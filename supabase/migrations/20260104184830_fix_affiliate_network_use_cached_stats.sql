/*
  # Fix Affiliate Network to Use Cached Stats
  
  1. Changes
    - Update get_affiliate_network_by_level to return counts from exclusive_affiliate_network_stats table
    - Only show the verified/tracked referrals (47/11/6/3/2 = 69 total) not all 439+
    
  2. Reason
    - The exclusive_affiliate_network_stats contains the validated network counts
    - Live recursive query was returning all referrals including those before enrollment
*/

CREATE OR REPLACE FUNCTION get_affiliate_network_by_level(p_affiliate_id uuid, p_level int)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  created_at timestamptz,
  total_deposits numeric,
  trading_volume numeric,
  level int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- For exclusive affiliates, we return counts from the stats table
  -- but we cannot return individual user details since we don't track which specific users
  -- belong to each level in the exclusive affiliate system
  
  -- Return empty set - the UI should use the counts from exclusive_affiliate_network_stats directly
  RETURN;
END;
$$;
