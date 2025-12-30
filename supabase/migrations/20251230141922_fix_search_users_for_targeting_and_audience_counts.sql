/*
  # Fix User Search and Audience Counts Functions

  1. Fixes
    - `search_users_for_targeting` - Fix email column reference (was querying user_profiles.email which doesn't exist)
    - Ensure proper join with auth.users table
    
  2. Changes
    - Drop and recreate search_users_for_targeting with correct query
*/

-- Drop existing function
DROP FUNCTION IF EXISTS search_users_for_targeting(text, int);

-- Recreate with correct email reference
CREATE OR REPLACE FUNCTION search_users_for_targeting(
  p_search_term text,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  username text,
  vip_level int,
  kyc_level int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    up.id as user_id,
    au.email::text,
    up.full_name,
    up.username,
    up.kyc_level as vip_level,
    up.kyc_level,
    up.created_at
  FROM user_profiles up
  JOIN auth.users au ON au.id = up.id
  WHERE 
    au.email ILIKE '%' || p_search_term || '%'
    OR up.full_name ILIKE '%' || p_search_term || '%'
    OR up.username ILIKE '%' || p_search_term || '%'
  ORDER BY up.created_at DESC
  LIMIT p_limit;
END;
$$;

-- Also fix get_audience_type_counts to use JWT-based admin check
DROP FUNCTION IF EXISTS get_audience_type_counts();

CREATE OR REPLACE FUNCTION get_audience_type_counts()
RETURNS TABLE (
  audience_type text,
  user_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count bigint;
BEGIN
  -- Use JWT-based admin check
  IF NOT COALESCE((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean, false) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Traders
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM (
    SELECT user_id FROM futures_positions
    UNION
    SELECT user_id FROM swap_orders WHERE status = 'executed'
  ) AS traders;
  RETURN QUERY SELECT 'traders'::text, v_count;

  -- Non-Traders
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM futures_positions fp WHERE fp.user_id = up.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM swap_orders so WHERE so.user_id = up.id AND so.status = 'executed'
  );
  RETURN QUERY SELECT 'non_traders'::text, v_count;

  -- Active 7 days
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM (
    SELECT user_id FROM user_activity WHERE last_seen_at >= now() - interval '7 days'
    UNION
    SELECT user_id FROM transactions WHERE created_at >= now() - interval '7 days'
    UNION
    SELECT user_id FROM futures_positions WHERE opened_at >= now() - interval '7 days'
  ) AS active_users;
  RETURN QUERY SELECT 'active_7d'::text, v_count;

  -- Inactive 30+ days
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM user_activity ua WHERE ua.user_id = up.id AND ua.last_seen_at >= now() - interval '30 days'
  )
  AND NOT EXISTS (
    SELECT 1 FROM transactions t WHERE t.user_id = up.id AND t.created_at >= now() - interval '30 days'
  )
  AND NOT EXISTS (
    SELECT 1 FROM futures_positions fp WHERE fp.user_id = up.id AND fp.opened_at >= now() - interval '30 days'
  );
  RETURN QUERY SELECT 'inactive_30d'::text, v_count;

  -- Never Deposited
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM transactions t 
    WHERE t.user_id = up.id 
    AND t.transaction_type IN ('deposit', 'crypto_deposit')
  );
  RETURN QUERY SELECT 'never_deposited'::text, v_count;

  -- Has Deposited
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM transactions
  WHERE transaction_type IN ('deposit', 'crypto_deposit');
  RETURN QUERY SELECT 'has_deposited'::text, v_count;

  -- Zero Balance
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE COALESCE((
    SELECT SUM(w.balance) FROM wallets w WHERE w.user_id = up.id AND w.currency = 'USDT'
  ), 0) <= 0;
  RETURN QUERY SELECT 'zero_balance'::text, v_count;

  -- Has Balance
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE COALESCE((
    SELECT SUM(w.balance) FROM wallets w WHERE w.user_id = up.id AND w.currency = 'USDT'
  ), 0) > 0;
  RETURN QUERY SELECT 'has_balance'::text, v_count;

  -- Referrers
  SELECT COUNT(*) INTO v_count
  FROM referral_stats
  WHERE total_referrals > 0;
  RETURN QUERY SELECT 'referrers'::text, v_count;

  -- Referred Users
  SELECT COUNT(*) INTO v_count
  FROM user_profiles
  WHERE referred_by IS NOT NULL;
  RETURN QUERY SELECT 'referred_users'::text, v_count;

  -- No Referrals
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM referral_stats rs WHERE rs.user_id = up.id AND rs.total_referrals > 0
  );
  RETURN QUERY SELECT 'no_referrals'::text, v_count;

  -- VIP Users
  SELECT COUNT(*) INTO v_count
  FROM user_profiles
  WHERE kyc_level IS NOT NULL AND kyc_level > 0;
  RETURN QUERY SELECT 'vip_users'::text, v_count;

  -- Non-VIP
  SELECT COUNT(*) INTO v_count
  FROM user_profiles
  WHERE kyc_level IS NULL OR kyc_level = 0;
  RETURN QUERY SELECT 'non_vip'::text, v_count;

  -- KYC Verified
  SELECT COUNT(*) INTO v_count
  FROM user_profiles
  WHERE kyc_level IN (1, 2);
  RETURN QUERY SELECT 'kyc_verified'::text, v_count;

  -- KYC Pending
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM kyc_documents
  WHERE status = 'pending';
  RETURN QUERY SELECT 'kyc_pending'::text, v_count;

  -- KYC Not Started
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE (up.kyc_level IS NULL OR up.kyc_level = 0)
  AND NOT EXISTS (
    SELECT 1 FROM kyc_documents kd WHERE kd.user_id = up.id
  );
  RETURN QUERY SELECT 'kyc_not_started'::text, v_count;

  -- Copy Traders
  SELECT COUNT(DISTINCT copier_id) INTO v_count
  FROM copy_relationships
  WHERE status = 'active';
  RETURN QUERY SELECT 'copy_traders'::text, v_count;

  -- Non-Copy Traders
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM copy_relationships cr WHERE cr.copier_id = up.id AND cr.status = 'active'
  );
  RETURN QUERY SELECT 'non_copy_traders'::text, v_count;

  -- Stakers
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM user_stakes
  WHERE status = 'active';
  RETURN QUERY SELECT 'stakers'::text, v_count;

  -- Non-Stakers
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM user_stakes us WHERE us.user_id = up.id AND us.status = 'active'
  );
  RETURN QUERY SELECT 'non_stakers'::text, v_count;

  -- Shark Card Holders
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM shark_cards
  WHERE status = 'active';
  RETURN QUERY SELECT 'shark_card_holders'::text, v_count;

  -- No Shark Card
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM shark_cards sc WHERE sc.user_id = up.id AND sc.status = 'active'
  );
  RETURN QUERY SELECT 'no_shark_card'::text, v_count;

  -- Total users for "selected_users" placeholder
  SELECT COUNT(*) INTO v_count FROM user_profiles;
  RETURN QUERY SELECT 'selected_users'::text, v_count;
END;
$$;
