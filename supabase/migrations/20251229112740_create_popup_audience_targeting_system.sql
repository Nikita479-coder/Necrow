/*
  # Create Popup Banner Audience Targeting System

  1. Schema Changes
    - Add `target_audiences` (text[]) - Array of audience types user must belong to
    - Add `target_user_ids` (uuid[]) - Specific user IDs for manual targeting
    - Add `audience_logic` (text) - 'AND' or 'OR' for combining audience checks
    - Add indexes for performance

  2. Audience Types Supported
    - Activity: traders, non_traders, active_7d, inactive_30d
    - Deposits: never_deposited, has_deposited, zero_balance, has_balance
    - Referrals: referrers, referred_users, no_referrals
    - VIP/Status: vip_users, non_vip, kyc_verified, kyc_pending, kyc_not_started
    - Custom: selected_users (uses target_user_ids)

  3. New Functions
    - check_user_in_audience(user_id, audience_type) - Check single audience membership
    - check_user_matches_popup_targeting(user_id, popup_id) - Full targeting check
    - get_audience_user_count(audiences, logic) - Count potential reach
    - Updated get_unseen_popups() - Filters by audience targeting

  4. Security
    - Functions use SECURITY DEFINER for safe execution
    - Admin-only functions check is_admin status
*/

-- Add audience targeting columns to popup_banners
ALTER TABLE popup_banners
ADD COLUMN IF NOT EXISTS target_audiences text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS target_user_ids uuid[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS audience_logic text DEFAULT 'OR' CHECK (audience_logic IN ('AND', 'OR'));

-- Create index for audience searching
CREATE INDEX IF NOT EXISTS idx_popup_banners_audiences ON popup_banners USING GIN (target_audiences);
CREATE INDEX IF NOT EXISTS idx_popup_banners_user_ids ON popup_banners USING GIN (target_user_ids);

-- Function to check if a user belongs to a specific audience type
CREATE OR REPLACE FUNCTION check_user_in_audience(
  p_user_id uuid,
  p_audience_type text
)
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
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
        SELECT 1 FROM user_activity WHERE user_id = p_user_id AND last_seen_at >= v_7_days_ago
        UNION
        SELECT 1 FROM transactions WHERE user_id = p_user_id AND created_at >= v_7_days_ago
        UNION
        SELECT 1 FROM futures_positions WHERE user_id = p_user_id AND opened_at >= v_7_days_ago
      ) INTO v_result;

    WHEN 'inactive_30d' THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM user_activity WHERE user_id = p_user_id AND last_seen_at >= v_30_days_ago
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
        AND vip_level IS NOT NULL 
        AND vip_level > 0
      ) INTO v_result;

    WHEN 'non_vip' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = p_user_id 
        AND (vip_level IS NULL OR vip_level = 0)
      ) INTO v_result;

    WHEN 'kyc_verified' THEN
      SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = p_user_id 
        AND kyc_level IN ('basic', 'advanced')
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
        AND (kyc_level IS NULL OR kyc_level = 'none')
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

-- Function to check if user matches popup targeting criteria
CREATE OR REPLACE FUNCTION check_user_matches_popup_targeting(
  p_user_id uuid,
  p_popup_id uuid
)
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_popup record;
  v_audience text;
  v_matches_count int := 0;
  v_total_audiences int;
BEGIN
  SELECT target_audiences, target_user_ids, audience_logic
  INTO v_popup
  FROM popup_banners
  WHERE id = p_popup_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF (v_popup.target_audiences IS NULL OR array_length(v_popup.target_audiences, 1) IS NULL)
     AND (v_popup.target_user_ids IS NULL OR array_length(v_popup.target_user_ids, 1) IS NULL) THEN
    RETURN true;
  END IF;

  IF v_popup.target_user_ids IS NOT NULL AND array_length(v_popup.target_user_ids, 1) > 0 THEN
    IF p_user_id = ANY(v_popup.target_user_ids) THEN
      IF v_popup.audience_logic = 'OR' THEN
        RETURN true;
      ELSE
        v_matches_count := v_matches_count + 1;
      END IF;
    ELSIF v_popup.audience_logic = 'AND' THEN
      IF 'selected_users' = ANY(v_popup.target_audiences) THEN
        RETURN false;
      END IF;
    END IF;
  END IF;

  IF v_popup.target_audiences IS NOT NULL AND array_length(v_popup.target_audiences, 1) > 0 THEN
    v_total_audiences := array_length(v_popup.target_audiences, 1);
    
    FOREACH v_audience IN ARRAY v_popup.target_audiences
    LOOP
      IF v_audience = 'selected_users' THEN
        CONTINUE;
      END IF;

      IF check_user_in_audience(p_user_id, v_audience) THEN
        IF v_popup.audience_logic = 'OR' THEN
          RETURN true;
        ELSE
          v_matches_count := v_matches_count + 1;
        END IF;
      ELSIF v_popup.audience_logic = 'AND' THEN
        RETURN false;
      END IF;
    END LOOP;

    IF v_popup.audience_logic = 'AND' THEN
      IF 'selected_users' = ANY(v_popup.target_audiences) THEN
        IF NOT (p_user_id = ANY(COALESCE(v_popup.target_user_ids, '{}'))) THEN
          RETURN false;
        END IF;
      END IF;
      RETURN true;
    END IF;
  END IF;

  IF v_popup.audience_logic = 'OR' THEN
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

-- Function to count users in given audiences (for admin preview)
CREATE OR REPLACE FUNCTION get_audience_user_count(
  p_audiences text[],
  p_user_ids uuid[] DEFAULT '{}',
  p_logic text DEFAULT 'OR'
)
RETURNS bigint
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_count bigint := 0;
  v_user record;
  v_audience text;
  v_matches boolean;
  v_match_count int;
  v_total_audiences int;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  IF (p_audiences IS NULL OR array_length(p_audiences, 1) IS NULL)
     AND (p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL) THEN
    SELECT COUNT(*) INTO v_count FROM user_profiles;
    RETURN v_count;
  END IF;

  v_total_audiences := COALESCE(array_length(p_audiences, 1), 0);

  FOR v_user IN SELECT id FROM user_profiles
  LOOP
    v_matches := false;
    v_match_count := 0;

    IF p_user_ids IS NOT NULL AND array_length(p_user_ids, 1) > 0 THEN
      IF v_user.id = ANY(p_user_ids) THEN
        IF p_logic = 'OR' THEN
          v_matches := true;
        ELSE
          v_match_count := v_match_count + 1;
        END IF;
      ELSIF p_logic = 'AND' AND 'selected_users' = ANY(p_audiences) THEN
        CONTINUE;
      END IF;
    END IF;

    IF NOT v_matches AND p_audiences IS NOT NULL AND array_length(p_audiences, 1) > 0 THEN
      FOREACH v_audience IN ARRAY p_audiences
      LOOP
        IF v_audience = 'selected_users' THEN
          CONTINUE;
        END IF;

        IF check_user_in_audience(v_user.id, v_audience) THEN
          IF p_logic = 'OR' THEN
            v_matches := true;
            EXIT;
          ELSE
            v_match_count := v_match_count + 1;
          END IF;
        ELSIF p_logic = 'AND' THEN
          v_matches := false;
          EXIT;
        END IF;
      END LOOP;

      IF p_logic = 'AND' AND NOT v_matches THEN
        DECLARE
          v_expected int := 0;
        BEGIN
          FOREACH v_audience IN ARRAY p_audiences
          LOOP
            IF v_audience != 'selected_users' THEN
              v_expected := v_expected + 1;
            END IF;
          END LOOP;
          
          IF v_match_count >= v_expected THEN
            v_matches := true;
          END IF;
        END;
      END IF;
    END IF;

    IF v_matches THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

-- Drop existing function first to change return type
DROP FUNCTION IF EXISTS get_popup_statistics();

-- Updated get_popup_statistics with targeting info
CREATE OR REPLACE FUNCTION get_popup_statistics()
RETURNS TABLE (
  popup_id uuid,
  title text,
  description text,
  image_url text,
  is_active boolean,
  created_at timestamptz,
  total_views bigint,
  unique_viewers bigint,
  view_percentage numeric,
  target_audiences text[],
  target_user_ids uuid[],
  audience_logic text,
  potential_reach bigint
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_users bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM user_profiles;

  RETURN QUERY
  SELECT
    pb.id,
    pb.title,
    pb.description,
    pb.image_url,
    pb.is_active,
    pb.created_at,
    COUNT(pbv.id) as total_views,
    COUNT(DISTINCT pbv.user_id) as unique_viewers,
    CASE
      WHEN v_total_users > 0 THEN
        ROUND((COUNT(DISTINCT pbv.user_id)::numeric / v_total_users::numeric) * 100, 2)
      ELSE 0
    END as view_percentage,
    pb.target_audiences,
    pb.target_user_ids,
    pb.audience_logic,
    get_audience_user_count(pb.target_audiences, pb.target_user_ids, pb.audience_logic) as potential_reach
  FROM popup_banners pb
  LEFT JOIN popup_banner_views pbv ON pb.id = pbv.popup_id
  GROUP BY pb.id, pb.title, pb.description, pb.image_url, pb.is_active, pb.created_at, pb.target_audiences, pb.target_user_ids, pb.audience_logic
  ORDER BY pb.created_at DESC;
END;
$$;

-- Update get_unseen_popups to filter by audience targeting
CREATE OR REPLACE FUNCTION get_unseen_popups()
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  image_url text,
  created_at timestamptz
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pb.id,
    pb.title,
    pb.description,
    pb.image_url,
    pb.created_at
  FROM popup_banners pb
  WHERE pb.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM popup_banner_views pbv
    WHERE pbv.popup_id = pb.id
    AND pbv.user_id = auth.uid()
  )
  AND check_user_matches_popup_targeting(auth.uid(), pb.id)
  ORDER BY pb.created_at DESC;
END;
$$;

-- Function to get available audience types with descriptions
CREATE OR REPLACE FUNCTION get_audience_types()
RETURNS TABLE (
  category text,
  audience_type text,
  label text,
  description text
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
AS $$
  SELECT * FROM (VALUES
    ('Activity', 'traders', 'Traders', 'Users who have opened futures positions or executed swaps'),
    ('Activity', 'non_traders', 'Non-Traders', 'Registered users who have never traded'),
    ('Activity', 'active_7d', 'Active (7 days)', 'Users active in the last 7 days'),
    ('Activity', 'inactive_30d', 'Inactive (30+ days)', 'Users inactive for 30+ days'),
    
    ('Deposits', 'never_deposited', 'Never Deposited', 'Users who have never made any deposit'),
    ('Deposits', 'has_deposited', 'Has Deposited', 'Users who have deposited at least once'),
    ('Deposits', 'zero_balance', 'Zero Balance', 'Users with current total balance of $0'),
    ('Deposits', 'has_balance', 'Has Balance', 'Users with current balance greater than $0'),
    
    ('Referrals', 'referrers', 'Referrers', 'Users who have referred at least one person'),
    ('Referrals', 'referred_users', 'Referred Users', 'Users who signed up via referral'),
    ('Referrals', 'no_referrals', 'No Referrals', 'Users who have not referred anyone yet'),
    
    ('VIP & Status', 'vip_users', 'VIP Users', 'Users with any VIP level'),
    ('VIP & Status', 'non_vip', 'Non-VIP', 'Users without VIP status'),
    ('VIP & Status', 'kyc_verified', 'KYC Verified', 'Users with verified KYC'),
    ('VIP & Status', 'kyc_pending', 'KYC Pending', 'Users with pending KYC verification'),
    ('VIP & Status', 'kyc_not_started', 'KYC Not Started', 'Users who have not started KYC'),
    
    ('Copy Trading', 'copy_traders', 'Copy Traders', 'Users actively copy trading'),
    ('Copy Trading', 'non_copy_traders', 'Non-Copy Traders', 'Users not currently copy trading'),
    
    ('Staking', 'stakers', 'Stakers', 'Users with active stakes'),
    ('Staking', 'non_stakers', 'Non-Stakers', 'Users without active stakes'),
    
    ('Shark Card', 'shark_card_holders', 'Shark Card Holders', 'Users with active shark cards'),
    ('Shark Card', 'no_shark_card', 'No Shark Card', 'Users without active shark cards'),
    
    ('Custom', 'selected_users', 'Selected Users', 'Manually selected specific users')
  ) AS t(category, audience_type, label, description);
$$;

-- Function to search users for selection (admin only)
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
  kyc_level text,
  created_at timestamptz
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    up.id as user_id,
    up.email,
    up.full_name,
    up.username,
    up.vip_level,
    up.kyc_level,
    up.created_at
  FROM user_profiles up
  WHERE 
    up.email ILIKE '%' || p_search_term || '%'
    OR up.full_name ILIKE '%' || p_search_term || '%'
    OR up.username ILIKE '%' || p_search_term || '%'
  ORDER BY up.created_at DESC
  LIMIT p_limit;
END;
$$;
