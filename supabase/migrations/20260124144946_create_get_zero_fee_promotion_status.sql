/*
  # Get Zero Fee Promotion Status

  1. New Function
    - get_user_zero_fee_status - Returns user's zero fee promotion details
    - Shows if active, when it expires, and time remaining

  2. Purpose
    - Allow frontend to display promotion status to user
    - Show countdown timer for remaining zero fee period
*/

CREATE OR REPLACE FUNCTION get_user_zero_fee_status(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_expires_at timestamptz;
  v_kyc_verified_at timestamptz;
  v_is_active boolean;
  v_hours_remaining numeric;
  v_days_remaining numeric;
BEGIN
  -- Use provided user_id or current user
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'active', false,
      'error', 'Not authenticated'
    );
  END IF;

  -- Get promotion details
  SELECT zero_fee_expires_at, kyc_verified_at
  INTO v_expires_at, v_kyc_verified_at
  FROM user_profiles
  WHERE id = v_user_id;

  -- Check if promotion is active
  v_is_active := v_expires_at IS NOT NULL AND v_expires_at > now();

  IF v_is_active THEN
    v_hours_remaining := EXTRACT(EPOCH FROM (v_expires_at - now())) / 3600;
    v_days_remaining := v_hours_remaining / 24;

    RETURN jsonb_build_object(
      'active', true,
      'expires_at', v_expires_at,
      'kyc_verified_at', v_kyc_verified_at,
      'hours_remaining', round(v_hours_remaining::numeric, 1),
      'days_remaining', round(v_days_remaining::numeric, 2),
      'promo_name', 'Zero Trading Fees',
      'promo_description', '0% fees on all futures and swap trades'
    );
  ELSE
    RETURN jsonb_build_object(
      'active', false,
      'expires_at', v_expires_at,
      'kyc_verified_at', v_kyc_verified_at,
      'expired', v_expires_at IS NOT NULL AND v_expires_at <= now(),
      'never_activated', v_expires_at IS NULL
    );
  END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_zero_fee_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_zero_fee_status(uuid) TO authenticated;
