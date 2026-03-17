/*
  # Fix Notifications Column Names

  1. Problem
    - Several functions reference non-existent columns in notifications table
    - `metadata` should be `data`
    - `is_read` should be `read`

  2. Functions Fixed
    - notify_user_on_admin_reply
    - expire_locked_bonuses
    - complete_crypto_deposit
*/

-- Fix notify_user_on_admin_reply trigger function
CREATE OR REPLACE FUNCTION notify_user_on_admin_reply()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ticket_user_id uuid;
  v_ticket_subject text;
BEGIN
  IF NEW.sender_type = 'admin' AND (NEW.is_internal_note IS NULL OR NEW.is_internal_note = false) THEN
    SELECT user_id, subject
    INTO v_ticket_user_id, v_ticket_subject
    FROM support_tickets
    WHERE id = NEW.ticket_id;

    IF v_ticket_user_id IS NOT NULL THEN
      INSERT INTO notifications (
        user_id,
        title,
        message,
        type,
        read,
        redirect_url,
        data
      ) VALUES (
        v_ticket_user_id,
        'New Support Response',
        'You have a new response to your ticket: ' || COALESCE(LEFT(v_ticket_subject, 50), 'Support Request'),
        'system',
        false,
        '/support',
        jsonb_build_object(
          'ticket_id', NEW.ticket_id,
          'message_id', NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Fix expire_locked_bonuses function
CREATE OR REPLACE FUNCTION expire_locked_bonuses()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer := 0;
  v_expired_bonus record;
BEGIN
  FOR v_expired_bonus IN
    SELECT id, user_id, original_amount, current_amount, bonus_type_name
    FROM locked_bonuses
    WHERE status = 'active'
    AND expires_at <= now()
  LOOP
    UPDATE locked_bonuses
    SET 
      status = 'expired',
      updated_at = now()
    WHERE id = v_expired_bonus.id;

    UPDATE user_bonuses
    SET status = 'expired'
    WHERE locked_bonus_id = v_expired_bonus.id;

    INSERT INTO notifications (user_id, type, title, message, read, data)
    VALUES (
      v_expired_bonus.user_id,
      'account_update',
      'Locked Bonus Expired',
      'Your locked bonus of $' || v_expired_bonus.original_amount::text || ' (' || v_expired_bonus.bonus_type_name || ') has expired. Remaining balance of $' || v_expired_bonus.current_amount::text || ' has been removed.',
      false,
      jsonb_build_object(
        'locked_bonus_id', v_expired_bonus.id,
        'original_amount', v_expired_bonus.original_amount,
        'remaining_amount', v_expired_bonus.current_amount
      )
    );

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count
  );
END;
$$;

-- Fix complete_crypto_deposit function
CREATE OR REPLACE FUNCTION complete_crypto_deposit(
  p_payment_id text,
  p_actual_amount_received numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deposit record;
  v_wallet_id uuid;
  v_transaction_id uuid;
  v_tracking_result jsonb;
BEGIN
  SELECT * INTO v_deposit
  FROM crypto_deposits
  WHERE payment_id = p_payment_id
  AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Deposit not found or already processed'
    );
  END IF;

  UPDATE crypto_deposits
  SET
    status = 'completed',
    actual_amount_received = p_actual_amount_received,
    completed_at = now(),
    updated_at = now()
  WHERE payment_id = p_payment_id;

  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = v_deposit.user_id
  AND currency = v_deposit.currency
  AND wallet_type = 'main';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (v_deposit.user_id, v_deposit.currency, 'main', 0)
    RETURNING id INTO v_wallet_id;
  END IF;

  UPDATE wallets
  SET
    balance = balance + p_actual_amount_received,
    updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    description,
    details
  ) VALUES (
    v_deposit.user_id,
    'deposit',
    v_deposit.currency,
    p_actual_amount_received,
    'completed',
    'Crypto Deposit',
    jsonb_build_object(
      'payment_id', p_payment_id,
      'deposit_id', v_deposit.id,
      'expected_amount', v_deposit.amount_requested,
      'actual_amount', p_actual_amount_received
    )
  ) RETURNING id INTO v_transaction_id;

  v_tracking_result := track_deposit_for_unlock(
    v_deposit.user_id,
    p_actual_amount_received
  );

  INSERT INTO notifications (user_id, type, title, message, read, data)
  VALUES (
    v_deposit.user_id,
    'transaction',
    'Deposit Confirmed',
    'Your deposit of ' || p_actual_amount_received::text || ' ' || v_deposit.currency || ' has been confirmed and credited to your account.',
    false,
    jsonb_build_object(
      'transaction_id', v_transaction_id,
      'amount', p_actual_amount_received,
      'currency', v_deposit.currency,
      'bonuses_unlocked', v_tracking_result->'bonuses_unlocked'
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'deposit_id', v_deposit.id,
    'amount', p_actual_amount_received,
    'currency', v_deposit.currency,
    'bonuses_unlocked', v_tracking_result->'bonuses_unlocked'
  );
END;
$$;
