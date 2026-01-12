/*
  # Fix Notifications Column Names - Batch 2

  1. Problem
    - Multiple functions reference non-existent columns in notifications table
    - `is_read` should be `read`
    - `notification_type` should be `type`

  2. Functions Fixed
    - admin_block_withdrawals
    - admin_unblock_withdrawals
    - distribute_vip_weekly_refills
    - execute_accepted_trade
    - transfer_to_user
*/

-- Drop functions with different signatures first
DROP FUNCTION IF EXISTS admin_unblock_withdrawals(uuid, uuid);
DROP FUNCTION IF EXISTS transfer_to_user(uuid, text, decimal, text, text);

-- Fix admin_block_withdrawals
CREATE OR REPLACE FUNCTION admin_block_withdrawals(
  p_admin_id uuid,
  p_user_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text;
  v_admin_username text;
BEGIN
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  SELECT username INTO v_username FROM user_profiles WHERE id = p_user_id;
  SELECT username INTO v_admin_username FROM user_profiles WHERE id = p_admin_id;

  UPDATE user_profiles
  SET 
    withdrawal_blocked = true,
    withdrawal_block_reason = p_reason,
    withdrawal_blocked_by = p_admin_id,
    withdrawal_blocked_at = now()
  WHERE id = p_user_id;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id,
    'withdrawal_blocked',
    'Withdrawals Temporarily Blocked',
    'Your withdrawals have been temporarily blocked. Reason: ' || p_reason || '. Please contact support for more information.',
    false
  );

  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details,
    ip_address
  ) VALUES (
    p_admin_id,
    'block_withdrawals',
    p_user_id,
    jsonb_build_object(
      'reason', p_reason,
      'username', v_username,
      'admin_username', v_admin_username
    ),
    NULL
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Withdrawals blocked for user'
  );
END;
$$;

-- Fix admin_unblock_withdrawals
CREATE OR REPLACE FUNCTION admin_unblock_withdrawals(
  p_admin_id uuid,
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text;
  v_admin_username text;
BEGIN
  IF NOT is_user_admin(p_admin_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Unauthorized: Admin access required'
    );
  END IF;

  SELECT username INTO v_username FROM user_profiles WHERE id = p_user_id;
  SELECT username INTO v_admin_username FROM user_profiles WHERE id = p_admin_id;

  UPDATE user_profiles
  SET 
    withdrawal_blocked = false,
    withdrawal_block_reason = NULL,
    withdrawal_blocked_by = NULL,
    withdrawal_blocked_at = NULL
  WHERE id = p_user_id;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id,
    'withdrawal_unblocked',
    'Withdrawals Enabled',
    'Your withdrawals have been enabled. You can now withdraw funds.',
    false
  );

  INSERT INTO admin_action_logs (
    admin_id,
    action_type,
    target_user_id,
    details,
    ip_address
  ) VALUES (
    p_admin_id,
    'unblock_withdrawals',
    p_user_id,
    jsonb_build_object(
      'username', v_username,
      'admin_username', v_admin_username
    ),
    NULL
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Withdrawals unblocked for user'
  );
END;
$$;

-- Fix distribute_vip_weekly_refills
CREATE OR REPLACE FUNCTION distribute_vip_weekly_refills()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_record RECORD;
  v_vip_level_record RECORD;
  v_refill_amount numeric;
  v_transaction_id uuid;
  v_distributed_count integer := 0;
  v_total_amount numeric := 0;
BEGIN
  FOR v_user_record IN
    SELECT uvs.user_id, uvs.current_level
    FROM user_vip_status uvs
    INNER JOIN vip_levels vl ON vl.level_number = uvs.current_level
    WHERE vl.weekly_refill_amount > 0
  LOOP
    SELECT * INTO v_vip_level_record
    FROM vip_levels
    WHERE level_number = v_user_record.current_level;

    v_refill_amount := v_vip_level_record.weekly_refill_amount;

    IF EXISTS (
      SELECT 1 FROM vip_refill_distributions
      WHERE user_id = v_user_record.user_id
      AND distributed_at >= NOW() - INTERVAL '7 days'
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (v_user_record.user_id, 'USDT', 0, 'main')
    ON CONFLICT (user_id, currency, wallet_type) 
    DO NOTHING;

    UPDATE wallets
    SET 
      balance = balance + v_refill_amount,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id
    AND currency = 'USDT'
    AND wallet_type = 'main';

    INSERT INTO transactions (
      user_id,
      transaction_type,
      amount,
      currency,
      status,
      details
    ) VALUES (
      v_user_record.user_id,
      'vip_refill',
      v_refill_amount,
      'USDT',
      'completed',
      jsonb_build_object(
        'vip_level', v_user_record.current_level,
        'level_name', v_vip_level_record.level_name,
        'refill_type', 'weekly_shark_card'
      )
    ) RETURNING id INTO v_transaction_id;

    INSERT INTO vip_refill_distributions (
      user_id,
      vip_level,
      refill_amount,
      transaction_id,
      distributed_at
    ) VALUES (
      v_user_record.user_id,
      v_user_record.current_level,
      v_refill_amount,
      v_transaction_id,
      NOW()
    );

    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      read
    ) VALUES (
      v_user_record.user_id,
      'vip_refill',
      'Weekly VIP Shark Card Refill',
      format('You received $%s USDT as your weekly %s shark card refill!', 
        v_refill_amount, v_vip_level_record.level_name),
      false
    );

    v_distributed_count := v_distributed_count + 1;
    v_total_amount := v_total_amount + v_refill_amount;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'distributed_count', v_distributed_count,
    'total_amount', v_total_amount,
    'timestamp', NOW()
  );
END;
$$;

-- Fix execute_accepted_trade
CREATE OR REPLACE FUNCTION execute_accepted_trade(
  p_pending_trade_id uuid,
  p_follower_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade RECORD;
  v_response RECORD;
  v_relationship RECORD;
  v_trader_trade_id uuid;
  v_allocated_amount numeric;
  v_wallet_type text;
BEGIN
  SELECT * INTO v_trade
  FROM pending_copy_trades
  WHERE id = p_pending_trade_id
  AND follower_id = p_follower_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending trade not found';
  END IF;

  SELECT * INTO v_response
  FROM copy_trade_responses
  WHERE pending_trade_id = p_pending_trade_id
  AND follower_id = p_follower_id
  AND response_status = 'accepted';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No accepted response found';
  END IF;

  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE trader_id = v_trade.trader_id
  AND follower_id = p_follower_id
  AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active copy relationship not found';
  END IF;

  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'copy' END;

  PERFORM ensure_copy_wallet(p_follower_id, v_wallet_type);

  v_allocated_amount := (v_relationship.allocation_percentage / 100.0) * COALESCE(v_relationship.allocated_amount, 0);

  IF NOT EXISTS (
    SELECT 1 FROM wallets
    WHERE user_id = p_follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type
    AND balance >= v_allocated_amount
  ) THEN
    RAISE EXCEPTION 'Insufficient balance in copy wallet';
  END IF;

  UPDATE wallets
  SET 
    balance = balance - v_allocated_amount,
    updated_at = NOW()
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  SELECT trader_trade_id INTO v_trader_trade_id
  FROM pending_copy_trades
  WHERE id = p_pending_trade_id;

  IF v_trader_trade_id IS NULL THEN
    RAISE EXCEPTION 'Trader trade not yet created';
  END IF;

  INSERT INTO copy_trade_allocations (
    trader_trade_id,
    follower_id,
    copy_relationship_id,
    allocated_amount,
    follower_leverage,
    entry_price,
    side,
    status,
    source_type
  )
  SELECT
    v_trader_trade_id,
    p_follower_id,
    v_relationship.id,
    v_allocated_amount,
    v_response.follower_leverage,
    v_trade.entry_price,
    tt.side,
    'open',
    'pending_trade'
  FROM trader_trades tt
  WHERE tt.id = v_trader_trade_id;

  UPDATE pending_copy_trades
  SET 
    status = 'executed',
    updated_at = NOW()
  WHERE id = p_pending_trade_id;

  UPDATE copy_trade_responses
  SET 
    execution_status = 'executed',
    updated_at = NOW()
  WHERE pending_trade_id = p_pending_trade_id
  AND follower_id = p_follower_id;

  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    read
  ) VALUES (
    p_follower_id,
    'copy_trade_executed',
    'Copy Trade Executed',
    'Your copy trade for ' || v_trade.symbol || ' has been executed',
    false
  );
END;
$$;

-- Fix transfer_to_user
CREATE OR REPLACE FUNCTION transfer_to_user(
  sender_id uuid,
  recipient_email_or_username text,
  transfer_amount decimal,
  transfer_currency text DEFAULT 'USDT',
  wallet_type_param text DEFAULT 'main'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recipient_id uuid;
  sender_wallet_id uuid;
  recipient_wallet_id uuid;
  sender_balance decimal;
  recipient_name text;
  sender_name text;
BEGIN
  IF transfer_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Transfer amount must be greater than zero'
    );
  END IF;

  SELECT up.user_id, COALESCE(up.full_name, up.username, 'User')
  INTO recipient_id, recipient_name
  FROM user_profiles up
  INNER JOIN auth.users au ON au.id = up.user_id
  WHERE au.email = recipient_email_or_username
  OR up.username = recipient_email_or_username
  LIMIT 1;

  IF recipient_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found. Please check the email or username.'
    );
  END IF;

  IF sender_id = recipient_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You cannot send funds to yourself'
    );
  END IF;

  SELECT COALESCE(full_name, username, 'User')
  INTO sender_name
  FROM user_profiles
  WHERE user_id = sender_id;

  INSERT INTO wallets (user_id, currency, balance, wallet_type)
  VALUES (sender_id, transfer_currency, 0, wallet_type_param)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET updated_at = now()
  RETURNING id, balance INTO sender_wallet_id, sender_balance;

  IF sender_balance < transfer_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance. Available: ' || sender_balance || ' ' || transfer_currency
    );
  END IF;

  INSERT INTO wallets (user_id, currency, balance, wallet_type)
  VALUES (recipient_id, transfer_currency, 0, wallet_type_param)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET updated_at = now()
  RETURNING id INTO recipient_wallet_id;

  UPDATE wallets
  SET balance = balance - transfer_amount,
      updated_at = now()
  WHERE id = sender_wallet_id;

  UPDATE wallets
  SET balance = balance + transfer_amount,
      updated_at = now()
  WHERE id = recipient_wallet_id;

  INSERT INTO transactions (
    user_id,
    wallet_id,
    transaction_type,
    amount,
    currency,
    status,
    details
  ) VALUES (
    sender_id,
    sender_wallet_id,
    'user_transfer_sent',
    transfer_amount,
    transfer_currency,
    'completed',
    jsonb_build_object(
      'recipient_id', recipient_id,
      'recipient_name', recipient_name,
      'recipient_identifier', recipient_email_or_username,
      'transfer_type', 'peer_to_peer',
      'fee', 0
    )
  );

  INSERT INTO transactions (
    user_id,
    wallet_id,
    transaction_type,
    amount,
    currency,
    status,
    details
  ) VALUES (
    recipient_id,
    recipient_wallet_id,
    'user_transfer_received',
    transfer_amount,
    transfer_currency,
    'completed',
    jsonb_build_object(
      'sender_id', sender_id,
      'sender_name', sender_name,
      'transfer_type', 'peer_to_peer',
      'fee', 0
    )
  );

  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    read
  ) VALUES (
    recipient_id,
    'transfer_received',
    'Funds Received',
    'You received ' || transfer_amount || ' ' || transfer_currency || ' from ' || sender_name,
    false
  );

  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    read
  ) VALUES (
    sender_id,
    'transfer_sent',
    'Transfer Successful',
    'You sent ' || transfer_amount || ' ' || transfer_currency || ' to ' || recipient_name,
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'recipient_name', recipient_name,
    'amount', transfer_amount,
    'currency', transfer_currency
  );
END;
$$;
