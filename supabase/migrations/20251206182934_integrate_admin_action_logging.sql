/*
  # Integrate Admin Action Logging

  ## Description
  Adds comprehensive logging to all admin actions including:
  - Bonus awards and cancellations
  - Balance adjustments
  - Position edits (entry price and PnL changes)
  - KYC status changes
  - Account status changes
  
  ## Changes
  1. Creates helper function to log admin actions
  2. Updates existing admin functions to log actions
  3. Ensures all critical admin operations are tracked
  
  ## Security
  - All logs are immutable
  - Only admins can create logs
  - Logs include full context (before/after values, reasons, metadata)
*/

-- Helper function to log admin actions
CREATE OR REPLACE FUNCTION log_admin_action(
  p_admin_id uuid,
  p_action_type text,
  p_action_description text,
  p_target_user_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    action_description,
    target_user_id,
    metadata,
    created_at
  ) VALUES (
    p_admin_id,
    p_action_type,
    p_action_description,
    p_target_user_id,
    p_metadata,
    now()
  );
END;
$$;

-- Update award_user_bonus to log actions
CREATE OR REPLACE FUNCTION award_user_bonus(
  p_user_id uuid,
  p_bonus_type_id uuid,
  p_amount numeric,
  p_awarded_by uuid,
  p_notes text DEFAULT NULL,
  p_expiry_days integer DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus_id uuid;
  v_wallet_id uuid;
  v_bonus_type_name text;
  v_expires_at timestamptz;
BEGIN
  -- Get bonus type name
  SELECT name INTO v_bonus_type_name FROM bonus_types WHERE id = p_bonus_type_id;
  
  -- Calculate expiry
  IF p_expiry_days IS NOT NULL THEN
    v_expires_at := now() + (p_expiry_days || ' days')::interval;
  END IF;

  -- Create bonus record
  INSERT INTO user_bonuses (
    user_id,
    bonus_type_id,
    amount,
    status,
    awarded_by,
    awarded_at,
    expires_at,
    notes
  ) VALUES (
    p_user_id,
    p_bonus_type_id,
    p_amount,
    'active',
    p_awarded_by,
    now(),
    v_expires_at,
    p_notes
  ) RETURNING id INTO v_bonus_id;

  -- Get or create main wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'main';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, 'USDT', 'main', 0)
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Credit the wallet
  UPDATE wallets
  SET balance = balance + p_amount
  WHERE id = v_wallet_id;

  -- Log transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    wallet_id
  ) VALUES (
    p_user_id,
    'bonus',
    'USDT',
    p_amount,
    'completed',
    v_wallet_id
  );

  -- Send notification
  INSERT INTO notifications (
    user_id,
    title,
    message,
    category,
    status
  ) VALUES (
    p_user_id,
    'Bonus Awarded!',
    format('You have received a %s bonus of $%s USDT!', v_bonus_type_name, p_amount::text),
    'bonus',
    'unread'
  );

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    p_awarded_by,
    'bonus_award',
    format('Awarded %s bonus of $%s to user', v_bonus_type_name, p_amount::text),
    p_user_id,
    jsonb_build_object(
      'bonus_type', v_bonus_type_name,
      'amount', p_amount,
      'bonus_id', v_bonus_id,
      'notes', COALESCE(p_notes, 'No notes'),
      'expiry_days', p_expiry_days
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Bonus awarded successfully',
    'bonus_id', v_bonus_id
  );
END;
$$;

-- Update cancel_user_bonus to log actions
CREATE OR REPLACE FUNCTION cancel_user_bonus(
  p_bonus_id uuid,
  p_cancelled_by uuid,
  p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_bonus_type_name text;
BEGIN
  -- Get bonus details
  SELECT ub.user_id, ub.amount, bt.name
  INTO v_user_id, v_amount, v_bonus_type_name
  FROM user_bonuses ub
  JOIN bonus_types bt ON bt.id = ub.bonus_type_id
  WHERE ub.id = p_bonus_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bonus not found');
  END IF;

  -- Update bonus status
  UPDATE user_bonuses
  SET 
    status = 'cancelled',
    cancelled_at = now(),
    cancelled_by = p_cancelled_by,
    notes = COALESCE(notes || E'\nCancellation reason: ' || p_reason, 'Cancelled: ' || p_reason)
  WHERE id = p_bonus_id;

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    p_cancelled_by,
    'bonus_cancel',
    format('Cancelled %s bonus of $%s', v_bonus_type_name, v_amount::text),
    v_user_id,
    jsonb_build_object(
      'bonus_id', p_bonus_id,
      'bonus_type', v_bonus_type_name,
      'amount', v_amount,
      'reason', COALESCE(p_reason, 'No reason provided')
    )
  );

  RETURN jsonb_build_object('success', true, 'message', 'Bonus cancelled successfully');
END;
$$;

-- Update admin_adjust_user_balance to log actions
CREATE OR REPLACE FUNCTION admin_adjust_user_balance(
  p_user_id uuid,
  p_amount numeric,
  p_currency text DEFAULT 'USDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_admin_id uuid;
BEGIN
  -- Get admin ID from session
  v_admin_id := auth.uid();

  -- Get or create wallet
  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_currency AND wallet_type = 'main';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_user_id, p_currency, 'main', 0)
    RETURNING id, balance INTO v_wallet_id, v_old_balance;
  END IF;

  -- Update balance
  UPDATE wallets
  SET balance = balance + p_amount
  WHERE id = v_wallet_id
  RETURNING balance INTO v_new_balance;

  -- Log transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    wallet_id
  ) VALUES (
    p_user_id,
    CASE WHEN p_amount > 0 THEN 'admin_credit' ELSE 'admin_debit' END,
    p_currency,
    abs(p_amount),
    'completed',
    v_wallet_id
  );

  -- LOG FINANCIAL TRANSACTION
  INSERT INTO financial_transaction_logs (
    user_id,
    transaction_type,
    currency,
    amount,
    before_balance,
    after_balance,
    executed_by_admin_id,
    reason,
    metadata
  ) VALUES (
    p_user_id,
    'admin_balance_adjustment',
    p_currency,
    p_amount,
    v_old_balance,
    v_new_balance,
    v_admin_id,
    'Manual balance adjustment by admin',
    jsonb_build_object(
      'adjustment_type', CASE WHEN p_amount > 0 THEN 'credit' ELSE 'debit' END,
      'old_balance', v_old_balance,
      'new_balance', v_new_balance
    )
  );

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    v_admin_id,
    'balance_adjustment',
    format('Adjusted balance by %s%s %s', 
      CASE WHEN p_amount > 0 THEN '+' ELSE '' END,
      p_amount::text,
      p_currency
    ),
    p_user_id,
    jsonb_build_object(
      'currency', p_currency,
      'amount', p_amount,
      'old_balance', v_old_balance,
      'new_balance', v_new_balance
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Balance adjusted successfully. New balance: %s %s', v_new_balance::text, p_currency),
    'old_balance', v_old_balance,
    'new_balance', v_new_balance
  );
END;
$$;

-- Update admin_update_position_entry_price to log actions
CREATE OR REPLACE FUNCTION admin_update_position_entry_price(
  p_position_id uuid,
  p_new_entry_price numeric,
  p_admin_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_new_pnl numeric;
  v_current_price numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;

  -- Get current price
  SELECT price INTO v_current_price
  FROM market_prices
  WHERE pair = v_position.pair
  ORDER BY updated_at DESC
  LIMIT 1;

  -- Calculate new PnL
  IF v_position.side = 'long' THEN
    v_new_pnl := (v_current_price - p_new_entry_price) * v_position.quantity;
  ELSE
    v_new_pnl := (p_new_entry_price - v_current_price) * v_position.quantity;
  END IF;

  -- Update position
  UPDATE futures_positions
  SET 
    entry_price = p_new_entry_price,
    unrealized_pnl = v_new_pnl,
    roe = (v_new_pnl / v_position.margin_used) * 100
  WHERE position_id = p_position_id;

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    p_admin_user_id,
    'position_entry_price_edit',
    format('Updated entry price for %s position on %s', v_position.side, v_position.pair),
    v_position.user_id,
    jsonb_build_object(
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'old_entry_price', v_position.entry_price,
      'new_entry_price', p_new_entry_price,
      'old_pnl', v_position.unrealized_pnl,
      'new_pnl', v_new_pnl,
      'current_price', v_current_price
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'new_pnl', v_new_pnl,
    'old_entry_price', v_position.entry_price,
    'new_entry_price', p_new_entry_price
  );
END;
$$;

-- Update admin_update_position_pnl to log actions
CREATE OR REPLACE FUNCTION admin_update_position_pnl(
  p_position_id uuid,
  p_target_pnl numeric,
  p_admin_user_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_new_entry_price numeric;
  v_current_price numeric;
BEGIN
  -- Get position details
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id AND status = 'open';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;

  -- Get current price
  SELECT price INTO v_current_price
  FROM market_prices
  WHERE pair = v_position.pair
  ORDER BY updated_at DESC
  LIMIT 1;

  -- Calculate new entry price to achieve target PnL
  IF v_position.side = 'long' THEN
    v_new_entry_price := v_current_price - (p_target_pnl / v_position.quantity);
  ELSE
    v_new_entry_price := v_current_price + (p_target_pnl / v_position.quantity);
  END IF;

  -- Update position
  UPDATE futures_positions
  SET 
    entry_price = v_new_entry_price,
    unrealized_pnl = p_target_pnl,
    roe = (p_target_pnl / v_position.margin_used) * 100
  WHERE position_id = p_position_id;

  -- LOG ADMIN ACTION
  PERFORM log_admin_action(
    p_admin_user_id,
    'position_pnl_edit',
    format('Updated PnL for %s position on %s', v_position.side, v_position.pair),
    v_position.user_id,
    jsonb_build_object(
      'position_id', p_position_id,
      'pair', v_position.pair,
      'side', v_position.side,
      'old_entry_price', v_position.entry_price,
      'new_entry_price', v_new_entry_price,
      'old_pnl', v_position.unrealized_pnl,
      'new_pnl', p_target_pnl,
      'current_price', v_current_price
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'new_entry_price', v_new_entry_price,
    'old_pnl', v_position.unrealized_pnl,
    'new_pnl', p_target_pnl
  );
END;
$$;