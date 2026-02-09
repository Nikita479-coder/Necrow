/*
  # Create Recruitment Boost Helper Functions

  Creates the core functions that calculate the rolling 30-day recruitment boost for exclusive affiliates.

  ## New Functions

  ### `get_affiliate_ftd_count_30d(p_affiliate_id uuid)` returns integer
    - Counts Level-1 referrals who made a qualifying first deposit ($100+) within the last 30 days
    - A qualifying FTD requires: referred_by matches, ftd_amount >= 100, ftd_at within 30 days

  ### `get_boost_multiplier_for_ftd_count(p_count integer)` returns numeric
    - Pure mapping: 0-4 -> 1.0, 5-10 -> 1.20, 11-20 -> 1.35, 21-50 -> 1.50, 51+ -> 2.0

  ### `get_boost_tier_label(p_count integer)` returns text
    - Returns a human-readable label for the boost tier

  ### `get_exclusive_affiliate_boost(p_affiliate_id uuid)` returns jsonb
    - Main entry point: checks eligibility, overrides, calculates live boost
    - Updates cached columns on exclusive_affiliate_network_stats as a side effect
    - Returns: ftd_count, multiplier, tier_label, boost_percentage, next_tier_threshold, ftds_to_next_tier, eligible

  ## Boost Tiers
    | FTD Count | Multiplier | Boost   |
    |-----------|-----------|---------|
    | 0-4       | 1.00      | None    |
    | 5-10      | 1.20      | +20%    |
    | 11-20     | 1.35      | +35%    |
    | 21-50     | 1.50      | +50%    |
    | 51+       | 2.00      | +100%   |
*/

-- 1. Count Level-1 FTDs in the last 30 days
CREATE OR REPLACE FUNCTION get_affiliate_ftd_count_30d(p_affiliate_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*)::integer INTO v_count
  FROM user_profiles
  WHERE referred_by = p_affiliate_id
    AND ftd_amount IS NOT NULL
    AND ftd_amount >= 100
    AND ftd_at IS NOT NULL
    AND ftd_at >= (now() - interval '30 days');

  RETURN COALESCE(v_count, 0);
END;
$$;

-- 2. Map FTD count to boost multiplier
CREATE OR REPLACE FUNCTION get_boost_multiplier_for_ftd_count(p_count integer)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_count >= 51 THEN RETURN 2.00;
  ELSIF p_count >= 21 THEN RETURN 1.50;
  ELSIF p_count >= 11 THEN RETURN 1.35;
  ELSIF p_count >= 5 THEN RETURN 1.20;
  ELSE RETURN 1.00;
  END IF;
END;
$$;

-- 3. Map FTD count to human-readable tier label
CREATE OR REPLACE FUNCTION get_boost_tier_label(p_count integer)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_count >= 51 THEN RETURN '51+ FTDs +100%';
  ELSIF p_count >= 21 THEN RETURN '21-50 FTDs +50%';
  ELSIF p_count >= 11 THEN RETURN '11-20 FTDs +35%';
  ELSIF p_count >= 5 THEN RETURN '5-10 FTDs +20%';
  ELSE RETURN 'No boost';
  END IF;
END;
$$;

-- 4. Main boost getter: checks eligibility, overrides, returns full boost info
CREATE OR REPLACE FUNCTION get_exclusive_affiliate_boost(p_affiliate_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_affiliate exclusive_affiliates;
  v_ftd_count integer;
  v_multiplier numeric;
  v_tier_label text;
  v_boost_pct numeric;
  v_next_threshold integer;
  v_ftds_to_next integer;
BEGIN
  SELECT * INTO v_affiliate
  FROM exclusive_affiliates
  WHERE user_id = p_affiliate_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'ftd_count', 0,
      'multiplier', 1.0,
      'tier_label', 'Not enrolled',
      'boost_percentage', 0,
      'next_tier_threshold', 0,
      'ftds_to_next_tier', 0,
      'eligible', false
    );
  END IF;

  v_ftd_count := get_affiliate_ftd_count_30d(p_affiliate_id);

  IF COALESCE(v_affiliate.is_boost_eligible, true) = false THEN
    INSERT INTO exclusive_affiliate_network_stats (affiliate_id, ftd_count_30d, current_boost_tier, current_boost_multiplier, boost_updated_at)
    VALUES (p_affiliate_id, v_ftd_count, 'Boost disabled', 1.0, now())
    ON CONFLICT (affiliate_id) DO UPDATE SET
      ftd_count_30d = v_ftd_count,
      current_boost_tier = 'Boost disabled',
      current_boost_multiplier = 1.0,
      boost_updated_at = now();

    RETURN jsonb_build_object(
      'ftd_count', v_ftd_count,
      'multiplier', 1.0,
      'tier_label', 'Boost disabled',
      'boost_percentage', 0,
      'next_tier_threshold', 0,
      'ftds_to_next_tier', 0,
      'eligible', false
    );
  END IF;

  IF v_affiliate.boost_override_multiplier IS NOT NULL THEN
    v_multiplier := v_affiliate.boost_override_multiplier;
    v_tier_label := 'Custom override x' || TRIM(TO_CHAR(v_multiplier, 'FM999999999.00'));
    v_boost_pct := ROUND((v_multiplier - 1.0) * 100);
  ELSE
    v_multiplier := get_boost_multiplier_for_ftd_count(v_ftd_count);
    v_tier_label := get_boost_tier_label(v_ftd_count);
    v_boost_pct := ROUND((v_multiplier - 1.0) * 100);
  END IF;

  IF v_ftd_count >= 51 THEN
    v_next_threshold := 0;
    v_ftds_to_next := 0;
  ELSIF v_ftd_count >= 21 THEN
    v_next_threshold := 51;
    v_ftds_to_next := 51 - v_ftd_count;
  ELSIF v_ftd_count >= 11 THEN
    v_next_threshold := 21;
    v_ftds_to_next := 21 - v_ftd_count;
  ELSIF v_ftd_count >= 5 THEN
    v_next_threshold := 11;
    v_ftds_to_next := 11 - v_ftd_count;
  ELSE
    v_next_threshold := 5;
    v_ftds_to_next := 5 - v_ftd_count;
  END IF;

  INSERT INTO exclusive_affiliate_network_stats (affiliate_id, ftd_count_30d, current_boost_tier, current_boost_multiplier, boost_updated_at)
  VALUES (p_affiliate_id, v_ftd_count, v_tier_label, v_multiplier, now())
  ON CONFLICT (affiliate_id) DO UPDATE SET
    ftd_count_30d = v_ftd_count,
    current_boost_tier = v_tier_label,
    current_boost_multiplier = v_multiplier,
    boost_updated_at = now();

  RETURN jsonb_build_object(
    'ftd_count', v_ftd_count,
    'multiplier', v_multiplier,
    'tier_label', v_tier_label,
    'boost_percentage', v_boost_pct,
    'next_tier_threshold', v_next_threshold,
    'ftds_to_next_tier', v_ftds_to_next,
    'eligible', true
  );
END;
$$;
