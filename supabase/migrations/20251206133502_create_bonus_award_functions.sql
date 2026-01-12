/*
  # Create Bonus Award Functions

  ## Summary
  Creates functions to award bonuses to users with automatic wallet transfer,
  transaction logging, and notification sending.

  ## Functions

  ### 1. award_user_bonus
  Awards a bonus to a user with automatic wallet credit
  - Creates bonus record
  - Credits user's USDT wallet
  - Logs transaction
  - Sends notification
  - Returns bonus details

  ### 2. cancel_user_bonus
  Cancels an active bonus (admin only)
  - Updates bonus status to cancelled
  - Does not reverse wallet credit (already spent)

  ### 3. get_active_bonuses_count
  Gets count of active bonuses for a user
*/

-- Function to award bonus to user (automatic wallet credit)
CREATE OR REPLACE FUNCTION award_user_bonus(
  p_user_id uuid,
  p_bonus_type_id uuid,
  p_amount numeric,
  p_awarded_by uuid,
  p_notes text DEFAULT NULL,
  p_expiry_days integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus_id uuid;
  v_bonus_type_name text;
  v_expires_at timestamptz;
  v_wallet_id uuid;
  v_username text;
BEGIN
  -- Validate bonus type exists and is active
  SELECT name INTO v_bonus_type_name
  FROM bonus_types
  WHERE id = p_bonus_type_id AND is_active = true;

  IF v_bonus_type_name IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus type not found or inactive'
    );
  END IF;

  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus amount must be greater than 0'
    );
  END IF;

  -- Calculate expiry date if specified
  IF p_expiry_days IS NOT NULL AND p_expiry_days > 0 THEN
    v_expires_at := now() + (p_expiry_days || ' days')::interval;
  END IF;

  -- Get username for notification
  SELECT username INTO v_username
  FROM user_profiles
  WHERE id = p_user_id;

  -- Create bonus record with 'active' status
  INSERT INTO user_bonuses (
    user_id,
    bonus_type_id,
    bonus_type_name,
    amount,
    status,
    awarded_by,
    awarded_at,
    claimed_at,
    expires_at,
    notes
  ) VALUES (
    p_user_id,
    p_bonus_type_id,
    v_bonus_type_name,
    p_amount,
    'claimed',  -- Immediately claimed since automatic
    p_awarded_by,
    now(),
    now(),  -- Claimed immediately
    v_expires_at,
    p_notes
  ) RETURNING id INTO v_bonus_id;

  -- Ensure user has USDT wallet
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_user_id, 'USDT', 'spot', 0)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET balance = wallets.balance
  RETURNING id INTO v_wallet_id;

  -- Credit the wallet
  UPDATE wallets
  SET 
    balance = balance + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'spot';

  -- Log transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    description,
    metadata
  ) VALUES (
    p_user_id,
    'bonus',
    'USDT',
    p_amount,
    'completed',
    'Bonus: ' || v_bonus_type_name,
    jsonb_build_object(
      'bonus_id', v_bonus_id,
      'bonus_type', v_bonus_type_name,
      'awarded_by', p_awarded_by
    )
  );

  -- Send notification to user
  PERFORM send_notification(
    p_user_id,
    'account_update',
    'Bonus Awarded!',
    'You have received a ' || v_bonus_type_name || ' bonus of $' || p_amount::text || ' USDT',
    jsonb_build_object(
      'bonus_id', v_bonus_id,
      'amount', p_amount,
      'bonus_type', v_bonus_type_name
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'bonus_id', v_bonus_id,
    'amount', p_amount,
    'message', 'Bonus awarded and credited successfully'
  );
END;
$$;

-- Function to cancel a bonus
CREATE OR REPLACE FUNCTION cancel_user_bonus(
  p_bonus_id uuid,
  p_cancelled_by uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_bonus_status text;
BEGIN
  -- Get bonus details
  SELECT user_id, status INTO v_user_id, v_bonus_status
  FROM user_bonuses
  WHERE id = p_bonus_id;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus not found'
    );
  END IF;

  IF v_bonus_status IN ('cancelled', 'expired') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus already ' || v_bonus_status
    );
  END IF;

  -- Update bonus status
  UPDATE user_bonuses
  SET 
    status = 'cancelled',
    notes = COALESCE(notes || E'\n\n', '') || 'Cancelled by admin: ' || COALESCE(p_reason, 'No reason provided'),
    metadata = metadata || jsonb_build_object('cancelled_by', p_cancelled_by, 'cancelled_at', now())
  WHERE id = p_bonus_id;

  -- Send notification
  PERFORM send_notification(
    v_user_id,
    'account_update',
    'Bonus Cancelled',
    'A bonus has been cancelled by administration.',
    jsonb_build_object('bonus_id', p_bonus_id, 'reason', p_reason)
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Bonus cancelled successfully'
  );
END;
$$;

-- Function to get active bonuses count for user
CREATE OR REPLACE FUNCTION get_active_bonuses_count(p_user_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::integer
  FROM user_bonuses
  WHERE user_id = p_user_id 
    AND status IN ('active', 'claimed')
    AND (expires_at IS NULL OR expires_at > now());
$$;

-- Function to expire old bonuses (to be called periodically)
CREATE OR REPLACE FUNCTION expire_old_bonuses()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer;
BEGIN
  WITH expired AS (
    UPDATE user_bonuses
    SET status = 'expired'
    WHERE status IN ('pending', 'active')
      AND expires_at IS NOT NULL
      AND expires_at <= now()
    RETURNING id
  )
  SELECT COUNT(*)::integer INTO v_expired_count FROM expired;

  RETURN v_expired_count;
END;
$$;
