/*
  # Global Auto-Accept for Copy Trading

  ## Summary
  Adds a 24-hour auto-accept toggle for copy trading. When enabled, all pending
  trades from followed traders are automatically accepted without manual approval.
  The feature automatically turns off after 24 hours, requiring users to re-enable.

  ## New Columns on user_profiles
  - `copy_auto_accept_enabled` (boolean): Whether auto-accept is currently active
  - `copy_auto_accept_until` (timestamptz): When auto-accept expires (24h from enable)

  ## Security
  - Users can only toggle their own auto-accept setting
  - Auto-accept uses same allocation logic as manual acceptance
  - No additional permissions required beyond existing copy trading RLS
*/

-- Add auto-accept columns to user_profiles
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS copy_auto_accept_enabled boolean DEFAULT false;

ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS copy_auto_accept_until timestamptz DEFAULT NULL;

-- Create function to toggle auto-accept
CREATE OR REPLACE FUNCTION toggle_copy_auto_accept(
  p_enable boolean
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_until timestamptz;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_enable THEN
    v_until := NOW() + INTERVAL '24 hours';
    
    UPDATE user_profiles
    SET 
      copy_auto_accept_enabled = true,
      copy_auto_accept_until = v_until,
      updated_at = NOW()
    WHERE id = v_user_id;
    
    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      v_user_id,
      'system',
      'Auto-Accept Enabled',
      'Copy trading auto-accept is now enabled for 24 hours. All pending trades will be automatically accepted.',
      false
    );
    
    RETURN json_build_object(
      'success', true,
      'enabled', true,
      'until', v_until,
      'message', 'Auto-accept enabled for 24 hours'
    );
  ELSE
    UPDATE user_profiles
    SET 
      copy_auto_accept_enabled = false,
      copy_auto_accept_until = NULL,
      updated_at = NOW()
    WHERE id = v_user_id;
    
    RETURN json_build_object(
      'success', true,
      'enabled', false,
      'until', NULL,
      'message', 'Auto-accept disabled'
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION toggle_copy_auto_accept TO authenticated;

-- Create function to get auto-accept status
CREATE OR REPLACE FUNCTION get_copy_auto_accept_status()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_enabled boolean;
  v_until timestamptz;
  v_is_active boolean;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN json_build_object(
      'enabled', false,
      'until', NULL,
      'is_active', false
    );
  END IF;

  SELECT 
    copy_auto_accept_enabled,
    copy_auto_accept_until
  INTO v_enabled, v_until
  FROM user_profiles
  WHERE id = v_user_id;

  v_is_active := v_enabled AND v_until IS NOT NULL AND v_until > NOW();

  IF v_enabled AND NOT v_is_active THEN
    UPDATE user_profiles
    SET 
      copy_auto_accept_enabled = false,
      copy_auto_accept_until = NULL,
      updated_at = NOW()
    WHERE id = v_user_id;
    v_enabled := false;
    v_until := NULL;
  END IF;

  RETURN json_build_object(
    'enabled', COALESCE(v_is_active, false),
    'until', v_until,
    'is_active', COALESCE(v_is_active, false)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_copy_auto_accept_status TO authenticated;

-- Create internal function to auto-accept a trade for a user
CREATE OR REPLACE FUNCTION auto_accept_pending_trade(
  p_trade_id uuid,
  p_follower_id uuid,
  p_relationship_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_trade RECORD;
  v_relationship RECORD;
  v_wallet_balance numeric;
  v_allocated_amount numeric;
  v_allocation_id uuid;
  v_wallet_type text;
  v_trader_trade_id uuid;
  v_effective_percentage numeric;
BEGIN
  IF EXISTS (
    SELECT 1 FROM pending_trade_responses
    WHERE pending_trade_id = p_trade_id
    AND follower_id = p_follower_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Already responded to this trade'
    );
  END IF;

  SELECT * INTO v_pending_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id
  AND status = 'pending'
  AND expires_at > NOW();

  IF v_pending_trade IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Trade expired or not found'
    );
  END IF;

  SELECT cr.*, 
    CASE WHEN cr.is_mock THEN 'mock' ELSE 'copy' END as wallet_type_name
  INTO v_relationship
  FROM copy_relationships cr
  WHERE cr.id = p_relationship_id
  AND cr.follower_id = p_follower_id
  AND cr.status = 'active'
  AND cr.is_active = true;

  IF v_relationship IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Relationship not active'
    );
  END IF;

  INSERT INTO pending_trade_responses (
    pending_trade_id,
    follower_id,
    response,
    decline_reason
  ) VALUES (
    p_trade_id,
    p_follower_id,
    'accepted',
    'auto-accepted'
  );

  IF v_pending_trade.trader_trade_id IS NULL THEN
    INSERT INTO trader_trades (
      trader_id,
      symbol,
      side,
      entry_price,
      quantity,
      leverage,
      margin_used,
      pnl,
      pnl_percent,
      status,
      opened_at
    ) VALUES (
      COALESCE(v_pending_trade.admin_trader_id, v_pending_trade.trader_id),
      v_pending_trade.pair,
      v_pending_trade.side,
      v_pending_trade.entry_price,
      v_pending_trade.quantity,
      v_pending_trade.leverage,
      v_pending_trade.margin_used,
      0,
      0,
      'open',
      NOW()
    ) RETURNING id INTO v_trader_trade_id;

    UPDATE pending_copy_trades
    SET trader_trade_id = v_trader_trade_id
    WHERE id = p_trade_id;
  ELSE
    v_trader_trade_id := v_pending_trade.trader_trade_id;
  END IF;

  v_wallet_type := v_relationship.wallet_type_name;

  SELECT COALESCE(balance, 0) INTO v_wallet_balance
  FROM wallets
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_wallet_balance IS NULL OR v_wallet_balance <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Insufficient balance'
    );
  END IF;

  v_effective_percentage := LEAST(
    v_relationship.allocation_percentage,
    COALESCE(v_pending_trade.margin_percentage, v_relationship.allocation_percentage)
  );
  
  v_allocated_amount := v_wallet_balance * v_effective_percentage / 100.0;

  IF v_allocated_amount < 1 THEN
    v_allocated_amount := LEAST(v_wallet_balance * 0.1, 10);
  END IF;

  IF v_allocated_amount > v_wallet_balance THEN
    v_allocated_amount := v_wallet_balance * 0.95;
  END IF;

  UPDATE wallets
  SET 
    balance = balance - v_allocated_amount,
    updated_at = NOW()
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

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
  ) VALUES (
    v_trader_trade_id,
    p_follower_id,
    v_relationship.id,
    v_allocated_amount,
    v_pending_trade.leverage * COALESCE(v_relationship.leverage, 1),
    v_pending_trade.entry_price,
    v_pending_trade.side,
    'open',
    'auto_accepted'
  ) RETURNING id INTO v_allocation_id;

  UPDATE copy_relationships
  SET 
    total_trades_copied = COALESCE(total_trades_copied, 0) + 1,
    updated_at = NOW()
  WHERE id = v_relationship.id;

  UPDATE pending_copy_trades
  SET total_accepted = total_accepted + 1
  WHERE id = p_trade_id;

  UPDATE notifications
  SET read = true
  WHERE user_id = p_follower_id
  AND type = 'pending_copy_trade'
  AND (data->>'pending_trade_id')::uuid = p_trade_id;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_follower_id,
    'copy_trade',
    'Trade Auto-Accepted',
    'Auto-accepted ' || v_pending_trade.pair || ' ' || v_pending_trade.side || ' trade with ' || ROUND(v_allocated_amount, 2)::text || ' USDT',
    false
  );

  RETURN json_build_object(
    'success', true,
    'allocation_id', v_allocation_id,
    'allocated_amount', v_allocated_amount
  );
END;
$$;
