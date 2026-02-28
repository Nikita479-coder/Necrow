/*
  # Create Promo Code Redemption Functions

  1. Functions
    - `validate_and_redeem_promo_code` - Validates a promo code and awards the bonus
    - `get_user_copy_trading_minimum` - Returns the minimum copy trading amount for a user
    - `get_user_active_promo_bonus` - Returns active promo bonus details for a user

  2. Changes
    - Awards $20 to copy wallet for COPY20 promo code
    - Tracks redemptions and expiry dates
    - Provides minimum override for users with active promo bonus
*/

-- Function to validate and redeem a promo code
CREATE OR REPLACE FUNCTION validate_and_redeem_promo_code(
  p_user_id uuid,
  p_promo_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promo_record RECORD;
  v_existing_redemption RECORD;
  v_bonus_expires_at timestamptz;
  v_redemption_id uuid;
BEGIN
  -- Check if promo code is empty
  IF p_promo_code IS NULL OR trim(p_promo_code) = '' THEN
    RETURN jsonb_build_object('success', true, 'message', 'No promo code provided');
  END IF;

  -- Find the promo code
  SELECT * INTO v_promo_record
  FROM promo_codes
  WHERE UPPER(code) = UPPER(trim(p_promo_code))
    AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid or inactive promo code');
  END IF;

  -- Check if max redemptions reached
  IF v_promo_record.max_redemptions IS NOT NULL 
     AND v_promo_record.current_redemptions >= v_promo_record.max_redemptions THEN
    RETURN jsonb_build_object('success', false, 'error', 'This promo code has reached its maximum redemptions');
  END IF;

  -- Check if user already redeemed this promo code
  SELECT * INTO v_existing_redemption
  FROM promo_code_redemptions
  WHERE user_id = p_user_id
    AND promo_code_id = v_promo_record.id;

  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'You have already redeemed this promo code');
  END IF;

  -- Calculate expiry date
  v_bonus_expires_at := now() + (v_promo_record.expiry_days || ' days')::interval;

  -- Create redemption record
  INSERT INTO promo_code_redemptions (
    user_id,
    promo_code_id,
    bonus_amount,
    bonus_expires_at,
    status
  ) VALUES (
    p_user_id,
    v_promo_record.id,
    v_promo_record.bonus_amount,
    v_bonus_expires_at,
    'active'
  )
  RETURNING id INTO v_redemption_id;

  -- Increment redemption count
  UPDATE promo_codes
  SET current_redemptions = current_redemptions + 1,
      updated_at = now()
  WHERE id = v_promo_record.id;

  -- For copy_trading_only bonus type, add to copy wallet
  IF v_promo_record.bonus_type = 'copy_trading_only' THEN
    -- Ensure copy wallet exists and add bonus
    INSERT INTO wallets (user_id, wallet_type, currency, balance, updated_at)
    VALUES (p_user_id, 'copy', 'USDT', v_promo_record.bonus_amount, now())
    ON CONFLICT (user_id, wallet_type, currency) 
    DO UPDATE SET 
      balance = wallets.balance + v_promo_record.bonus_amount,
      updated_at = now();

    -- Create a transaction record
    INSERT INTO transactions (
      user_id,
      transaction_type,
      amount,
      currency,
      status,
      details
    ) VALUES (
      p_user_id,
      'reward',
      v_promo_record.bonus_amount,
      'USDT',
      'completed',
      jsonb_build_object(
        'type', 'promo_code_bonus',
        'promo_code', v_promo_record.code,
        'description', 'Promo code bonus: ' || v_promo_record.code,
        'expires_at', v_bonus_expires_at,
        'wallet_type', 'copy'
      )
    );

    -- Create notification
    INSERT INTO notifications (
      user_id,
      notification_type,
      title,
      message,
      read
    ) VALUES (
      p_user_id,
      'bonus',
      'Promo Code Bonus Activated!',
      'You received $' || v_promo_record.bonus_amount || ' copy trading bonus with code ' || v_promo_record.code || '. This bonus is valid for ' || v_promo_record.expiry_days || ' days and can only be used for copy trading. You can withdraw any profits, but not the bonus itself.',
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Promo code redeemed successfully',
    'bonus_amount', v_promo_record.bonus_amount,
    'bonus_type', v_promo_record.bonus_type,
    'expires_at', v_bonus_expires_at,
    'redemption_id', v_redemption_id
  );
END;
$$;

-- Function to get user's copy trading minimum amount
CREATE OR REPLACE FUNCTION get_user_copy_trading_minimum(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_active_promo RECORD;
  v_default_minimum numeric := 100;
  v_promo_minimum numeric := 20;
BEGIN
  -- Check for active copy trading promo bonus
  SELECT 
    pcr.*,
    pc.code,
    pc.bonus_type
  INTO v_active_promo
  FROM promo_code_redemptions pcr
  JOIN promo_codes pc ON pc.id = pcr.promo_code_id
  WHERE pcr.user_id = p_user_id
    AND pcr.status = 'active'
    AND pcr.bonus_expires_at > now()
    AND pc.bonus_type = 'copy_trading_only'
  ORDER BY pcr.created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'minimum_amount', v_promo_minimum,
      'has_promo_bonus', true,
      'promo_code', v_active_promo.code,
      'bonus_amount', v_active_promo.bonus_amount,
      'expires_at', v_active_promo.bonus_expires_at,
      'days_remaining', EXTRACT(DAY FROM v_active_promo.bonus_expires_at - now())::integer
    );
  END IF;

  RETURN jsonb_build_object(
    'minimum_amount', v_default_minimum,
    'has_promo_bonus', false
  );
END;
$$;

-- Function to get user's active promo bonus details
CREATE OR REPLACE FUNCTION get_user_active_promo_bonus(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'redemption_id', pcr.id,
      'promo_code', pc.code,
      'bonus_amount', pcr.bonus_amount,
      'bonus_type', pc.bonus_type,
      'expires_at', pcr.bonus_expires_at,
      'days_remaining', GREATEST(0, EXTRACT(DAY FROM pcr.bonus_expires_at - now())::integer),
      'status', pcr.status,
      'created_at', pcr.created_at
    )
  ) INTO v_result
  FROM promo_code_redemptions pcr
  JOIN promo_codes pc ON pc.id = pcr.promo_code_id
  WHERE pcr.user_id = p_user_id
    AND pcr.status = 'active'
    AND pcr.bonus_expires_at > now();

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION validate_and_redeem_promo_code TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_copy_trading_minimum TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_active_promo_bonus TO authenticated;
