/*
  # Fix Audience Counts - Use Correct Activity Table

  1. Fixes
    - Replace `user_activity` with `user_activity_log` (correct table name)
    - Replace `last_seen_at` with `created_at` (correct column name)
*/

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

  -- Active 7 days (use user_activity_log and created_at)
  SELECT COUNT(DISTINCT user_id) INTO v_count
  FROM (
    SELECT user_id FROM user_activity_log WHERE created_at >= now() - interval '7 days'
    UNION
    SELECT user_id FROM transactions WHERE created_at >= now() - interval '7 days'
    UNION
    SELECT user_id FROM futures_positions WHERE opened_at >= now() - interval '7 days'
  ) AS active_users;
  RETURN QUERY SELECT 'active_7d'::text, v_count;

  -- Inactive 30+ days (use user_activity_log and created_at)
  SELECT COUNT(*) INTO v_count
  FROM user_profiles up
  WHERE NOT EXISTS (
    SELECT 1 FROM user_activity_log ua WHERE ua.user_id = up.id AND ua.created_at >= now() - interval '30 days'
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

  -- VIP Users (using kyc_level as VIP indicator)
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

-- Also fix the check_user_in_audience function that has the same issue
DROP FUNCTION IF EXISTS check_user_in_audience(uuid, text);

CREATE OR REPLACE FUNCTION check_user_in_audience(p_user_id uuid, p_audience_type text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result boolean := false;
  v_total_balance numeric;
  v_7_days_ago timestamptz := now() - interval '7 days';
  v_30_days_ago timestamptz := now() - interval '30 days';
BEGIN
  CASE p_audience_type
    -- Activity-based audiences
    WHEN 'traders' THEN
      SELECT EXISTS (
        SELECT 1 FROM futures_positions WHERE user_id = p_user_id
        UNION
        SELECT 1 FROM swap_orders WHERE user_id = p_user_id AND status = 'executed'
      ) INTO v_result;

    WHEN 'non_traders' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM futures_positions WHERE user_id = p_user_id
        UNION
        SELECT 1 FROM swap_orders WHERE user_id = p_user_id AND status = 'executed'
      ) INTO v_result;

    WHEN 'active_7d' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_activity_log WHERE user_id = p_user_id AND created_at >= v_7_days_ago
        UNION
        SELECT 1 FROM transactions WHERE user_id = p_user_id AND created_at >= v_7_days_ago
        UNION
        SELECT 1 FROM futures_positions WHERE user_id = p_user_id AND opened_at >= v_7_days_ago
      ) INTO v_result;

    WHEN 'inactive_30d' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM user_activity_log WHERE user_id = p_user_id AND created_at >= v_30_days_ago
      ) AND NOT EXISTS (
        SELECT 1 FROM transactions WHERE user_id = p_user_id AND created_at >= v_30_days_ago
      ) AND NOT EXISTS (
        SELECT 1 FROM futures_positions WHERE user_id = p_user_id AND opened_at >= v_30_days_ago
      ) INTO v_result;

    -- Deposit-based audiences
    WHEN 'never_deposited' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM transactions 
        WHERE user_id = p_user_id 
        AND transaction_type IN ('deposit', 'crypto_deposit')
      ) INTO v_result;

    WHEN 'has_deposited' THEN
      SELECT EXISTS (
        SELECT 1 FROM transactions 
        WHERE user_id = p_user_id 
        AND transaction_type IN ('deposit', 'crypto_deposit')
      ) INTO v_result;

    WHEN 'zero_balance' THEN
      SELECT COALESCE(SUM(balance), 0) INTO v_total_balance
      FROM wallets WHERE user_id = p_user_id AND currency = 'USDT';
      v_result := v_total_balance <= 0;

    WHEN 'has_balance' THEN
      SELECT COALESCE(SUM(balance), 0) INTO v_total_balance
      FROM wallets WHERE user_id = p_user_id AND currency = 'USDT';
      v_result := v_total_balance > 0;

    -- Referral-based audiences
    WHEN 'referrers' THEN
      SELECT EXISTS (
        SELECT 1 FROM referral_stats 
        WHERE user_id = p_user_id 
        AND total_referrals > 0
      ) INTO v_result;

    WHEN 'referred_users' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = p_user_id 
        AND referred_by IS NOT NULL
      ) INTO v_result;

    WHEN 'no_referrals' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM referral_stats 
        WHERE user_id = p_user_id 
        AND total_referrals > 0
      ) OR NOT EXISTS (
        SELECT 1 FROM referral_stats WHERE user_id = p_user_id
      ) INTO v_result;

    -- VIP/Status-based audiences
    WHEN 'vip_users' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = p_user_id 
        AND kyc_level IS NOT NULL 
        AND kyc_level > 0
      ) INTO v_result;

    WHEN 'non_vip' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = p_user_id 
        AND (kyc_level IS NULL OR kyc_level = 0)
      ) INTO v_result;

    WHEN 'kyc_verified' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = p_user_id 
        AND kyc_level IN (1, 2)
      ) INTO v_result;

    WHEN 'kyc_pending' THEN
      SELECT EXISTS (
        SELECT 1 FROM kyc_documents 
        WHERE user_id = p_user_id 
        AND status = 'pending'
      ) INTO v_result;

    WHEN 'kyc_not_started' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM kyc_documents WHERE user_id = p_user_id
      ) AND EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = p_user_id 
        AND (kyc_level IS NULL OR kyc_level = 0)
      ) INTO v_result;

    -- Copy trading audiences
    WHEN 'copy_traders' THEN
      SELECT EXISTS (
        SELECT 1 FROM copy_relationships 
        WHERE copier_id = p_user_id 
        AND status = 'active'
      ) INTO v_result;

    WHEN 'non_copy_traders' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM copy_relationships 
        WHERE copier_id = p_user_id 
        AND status = 'active'
      ) INTO v_result;

    -- Staking audiences
    WHEN 'stakers' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_stakes 
        WHERE user_id = p_user_id 
        AND status = 'active'
      ) INTO v_result;

    WHEN 'non_stakers' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM user_stakes 
        WHERE user_id = p_user_id 
        AND status = 'active'
      ) INTO v_result;

    -- Shark Card audiences
    WHEN 'shark_card_holders' THEN
      SELECT EXISTS (
        SELECT 1 FROM shark_cards 
        WHERE user_id = p_user_id 
        AND status = 'active'
      ) INTO v_result;

    WHEN 'no_shark_card' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM shark_cards 
        WHERE user_id = p_user_id 
        AND status = 'active'
      ) INTO v_result;

    ELSE
      v_result := false;
  END CASE;

  RETURN v_result;
END;
$$;
