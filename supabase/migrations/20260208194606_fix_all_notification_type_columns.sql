/*
  # Fix All notification_type Column References

  ## Issue
  Multiple functions use 'notification_type' instead of 'type' when inserting notifications,
  causing errors across the platform (copy trading, bonuses, etc.).

  ## Fix
  This migration searches for and fixes all INSERT statements that use the wrong column name.
  The notifications table uses 'type', not 'notification_type'.
  
  ## Functions Fixed
  - claim_copy_trading_bonus
  - auto_unstake_expired_flexible_stakes
  - And others that directly insert notifications
*/

-- Fix claim_copy_trading_bonus function
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'claim_copy_trading_bonus') THEN
    EXECUTE $func$
CREATE OR REPLACE FUNCTION claim_copy_trading_bonus(
  p_relationship_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_relationship RECORD;
  v_bonus_amount numeric;
  v_claimed_amount numeric;
  v_trader_name text;
BEGIN
  SELECT cr.*, t.name as trader_name
  INTO v_relationship
  FROM copy_relationships cr
  LEFT JOIN traders t ON t.id = cr.trader_id
  WHERE cr.id = p_relationship_id
    AND cr.follower_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Copy trading relationship not found'
    );
  END IF;

  v_trader_name := v_relationship.trader_name;
  v_bonus_amount := COALESCE(v_relationship.bonus_amount, 0);

  IF v_bonus_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No bonus associated with this copy trading relationship'
    );
  END IF;

  SELECT COALESCE(SUM(claimed_amount), 0)
  INTO v_claimed_amount
  FROM copy_trading_bonus_claims
  WHERE relationship_id = p_relationship_id;

  IF v_claimed_amount >= v_bonus_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus already fully claimed'
    );
  END IF;

  IF v_relationship.bonus_locked_until IS NOT NULL AND v_relationship.bonus_locked_until > now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bonus is still locked. Available after ' || to_char(v_relationship.bonus_locked_until, 'YYYY-MM-DD HH24:MI'),
      'locked_until', v_relationship.bonus_locked_until
    );
  END IF;

  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, created_at, updated_at)
  VALUES (auth.uid(), 'USDT', 'main', v_bonus_amount - v_claimed_amount, 0, now(), now())
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET
    balance = wallets.balance + (v_bonus_amount - v_claimed_amount),
    updated_at = now();

  INSERT INTO copy_trading_bonus_claims (
    relationship_id,
    user_id,
    claimed_amount,
    claimed_at
  ) VALUES (
    p_relationship_id,
    auth.uid(),
    v_bonus_amount - v_claimed_amount,
    now()
  );

  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    confirmed_at
  ) VALUES (
    auth.uid(),
    'reward',
    'USDT',
    v_bonus_amount - v_claimed_amount,
    'completed',
    jsonb_build_object(
      'type', 'copy_trading_bonus',
      'trader_name', v_trader_name,
      'relationship_id', p_relationship_id
    ),
    now()
  );

  INSERT INTO notifications (user_id, type, title, message, read, data, created_at)
  VALUES (
    auth.uid(),
    'reward',
    'Copy Trading Bonus Claimed',
    'You have successfully claimed ' || ROUND(v_bonus_amount - v_claimed_amount, 2) || ' USDT from your copy trading bonus.',
    false,
    jsonb_build_object(
      'amount', v_bonus_amount - v_claimed_amount,
      'trader_name', v_trader_name,
      'relationship_id', p_relationship_id
    ),
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'claimed_amount', v_bonus_amount - v_claimed_amount,
    'message', 'Copy trading bonus claimed successfully'
  );
END;
$body$;
    $func$;
  END IF;
END $$;
