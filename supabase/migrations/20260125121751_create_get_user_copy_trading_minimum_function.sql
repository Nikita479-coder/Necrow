/*
  # Create Get User Copy Trading Minimum Function

  1. New Function
    - get_user_copy_trading_minimum: Returns the minimum copy trading amount for a user
    - Checks for active promo code bonuses and reduces minimum accordingly
    - Returns promo code details if applicable

  2. Returns
    - minimum_amount: The minimum USDT required (default 100, or promo bonus amount)
    - has_promo_bonus: Boolean indicating if user has active promo bonus
    - promo_code: The promo code name if applicable
    - bonus_amount: The bonus amount if applicable
    - days_remaining: Days until bonus expires
*/

CREATE OR REPLACE FUNCTION get_user_copy_trading_minimum(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promo_record RECORD;
  v_minimum_amount numeric := 100;
  v_has_promo_bonus boolean := false;
  v_promo_code text;
  v_bonus_amount numeric := 0;
  v_days_remaining integer := 0;
BEGIN
  -- Check for active copy_trading_only promo bonus
  SELECT 
    pcr.bonus_amount,
    pc.code,
    pcr.bonus_expires_at
  INTO v_promo_record
  FROM promo_code_redemptions pcr
  JOIN promo_codes pc ON pc.id = pcr.promo_code_id
  WHERE pcr.user_id = p_user_id
  AND pcr.status = 'active'
  AND pcr.bonus_expires_at > now()
  AND pc.bonus_type = 'copy_trading_only'
  ORDER BY pcr.created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_has_promo_bonus := true;
    v_promo_code := v_promo_record.code;
    v_bonus_amount := v_promo_record.bonus_amount;
    v_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_promo_record.bonus_expires_at - now()))::integer);
    -- Reduce minimum to the promo bonus amount
    v_minimum_amount := LEAST(v_promo_record.bonus_amount, 100);
  END IF;

  RETURN jsonb_build_object(
    'minimum_amount', v_minimum_amount,
    'has_promo_bonus', v_has_promo_bonus,
    'promo_code', v_promo_code,
    'bonus_amount', v_bonus_amount,
    'days_remaining', v_days_remaining
  );
END;
$$;
