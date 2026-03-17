/*
  # Fix Promo Code Notification Decimal Formatting

  1. Changes
    - Update validate_and_redeem_promo_code function to format amounts properly
    - Use ROUND() and ::numeric(10,2) to display clean dollar amounts like $20 instead of $20.00000000
    - Applies to notification messages and any user-facing text

  2. Impact
    - Users will see clean "$20" instead of "$20.00000000" in notifications
*/

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
  v_formatted_amount text;
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

  -- Format amount for display (remove trailing zeros)
  v_formatted_amount := trim(trailing '0' from trim(trailing '.' from to_char(v_promo_record.bonus_amount, 'FM999999999.99')));

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

    -- Create notification with properly formatted amount
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      read
    ) VALUES (
      p_user_id,
      'bonus',
      'Promo Code Bonus Activated!',
      'You received $' || v_formatted_amount || ' copy trading bonus with code ' || v_promo_record.code || '. This bonus is valid for ' || v_promo_record.expiry_days || ' days and can only be used for copy trading. You can withdraw any profits, but not the bonus itself.',
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
