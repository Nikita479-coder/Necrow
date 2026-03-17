/*
  # Add Audience Type Counts Function

  1. New Function
    - `get_audience_type_counts()` - Returns user count for each audience type
    - Useful for admin UI to show how many users are in each segment
    
  2. Security
    - Admin-only access via SECURITY DEFINER
*/

-- Function to get user count for each audience type
CREATE OR REPLACE FUNCTION get_audience_type_counts()
RETURNS TABLE (
  audience_type text,
  user_count bigint
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_audience record;
  v_count bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
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
  WHERE vip_level IS NOT NULL AND vip_level > 0;
  RETURN QUERY SELECT 'vip_users'::text, v_count;

  -- Non-VIP
  SELECT COUNT(*) INTO v_count
  FROM user_profiles
  WHERE vip_level IS NULL OR vip_level = 0;
  RETURN QUERY SELECT 'non_vip'::text, v_count;

  -- KYC Verified
  SELECT COUNT(*) INTO v_count
  FROM user_profiles
  WHERE kyc_level IN ('basic', 'advanced');
  RETURN QUERY SELECT 'kyc_verified'::text, v_count;

  -- KYC Pending
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM kyc_documents
  WHERE status = 'pending';
  RETURN QUERY SELECT 'kyc_pending'::text, v_count;

  -- KYC Not Started
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE (up.kyc_level IS NULL OR up.kyc_level = 'none')
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
