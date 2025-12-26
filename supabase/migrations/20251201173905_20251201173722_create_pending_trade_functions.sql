/*
  # Pending Copy Trade Functions

  ## Functions Created
  1. `create_pending_copy_trade()` - Creates a new trade proposal and notifies followers
  2. `respond_to_copy_trade()` - Follower accepts or declines a trade
  3. `execute_accepted_trade()` - Executes trade for a follower who accepted
  4. `expire_pending_trades()` - Marks expired trades and updates stats

  ## Security
  - All functions use SECURITY DEFINER with search_path set
  - Proper validation and authentication checks
*/

-- Function to create a pending copy trade
CREATE OR REPLACE FUNCTION create_pending_copy_trade(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text DEFAULT NULL,
  p_trader_balance numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trade_id uuid;
  v_follower RECORD;
  v_follower_count integer := 0;
  v_expires_at timestamptz;
BEGIN
  -- Verify trader
  IF p_trader_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only create trades as yourself';
  END IF;

  -- Set expiration to 10 minutes from now
  v_expires_at := NOW() + INTERVAL '10 minutes';

  -- Create the pending trade
  INSERT INTO pending_copy_trades (
    trader_id, pair, side, entry_price, quantity, leverage, margin_used,
    notes, trader_balance, status, expires_at
  ) VALUES (
    p_trader_id, p_pair, p_side, p_entry_price, p_quantity, p_leverage, p_margin_used,
    p_notes, p_trader_balance, 'pending', v_expires_at
  ) RETURNING id INTO v_trade_id;

  -- Create notifications for all active followers
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.copy_amount,
      cr.leverage as follower_leverage_multiplier,
      cr.is_mock,
      cr.notification_enabled,
      cr.require_approval
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.is_active = true
    AND cr.require_approval = true
    AND cr.notification_enabled = true
  LOOP
    -- Create notification for this follower
    INSERT INTO copy_trade_notifications (
      follower_id,
      pending_trade_id,
      notification_status,
      notification_type
    ) VALUES (
      v_follower.follower_id,
      v_trade_id,
      'unread',
      'pending_trade'
    ) ON CONFLICT (follower_id, pending_trade_id) DO NOTHING;

    v_follower_count := v_follower_count + 1;
  END LOOP;

  -- Update the trade with follower count
  UPDATE pending_copy_trades
  SET total_followers_notified = v_follower_count
  WHERE id = v_trade_id;

  RETURN v_trade_id;
END;
$$;

-- Function to respond to a pending copy trade
CREATE OR REPLACE FUNCTION respond_to_copy_trade(
  p_trade_id uuid,
  p_follower_id uuid,
  p_response text,
  p_decline_reason text DEFAULT NULL,
  p_risk_acknowledged boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_response_id uuid;
  v_trade RECORD;
  v_relationship RECORD;
  v_allocated_amount numeric;
  v_wallet_type text;
  v_current_balance numeric;
BEGIN
  -- Verify user
  IF p_follower_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Can only respond as yourself';
  END IF;

  -- Validate response type
  IF p_response NOT IN ('accepted', 'declined') THEN
    RAISE EXCEPTION 'Invalid response type';
  END IF;

  -- Get trade details
  SELECT * INTO v_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id;

  IF v_trade IS NULL THEN
    RAISE EXCEPTION 'Trade not found';
  END IF;

  -- Check if trade is still pending
  IF v_trade.status != 'pending' THEN
    RAISE EXCEPTION 'Trade is no longer pending';
  END IF;

  -- Check if trade has expired
  IF v_trade.expires_at < NOW() THEN
    RAISE EXCEPTION 'Trade has expired';
  END IF;

  -- Get relationship details
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE follower_id = p_follower_id
  AND trader_id = v_trade.trader_id
  AND status = 'active'
  AND is_active = true;

  IF v_relationship IS NULL THEN
    RAISE EXCEPTION 'No active copy relationship found';
  END IF;

  -- Check if already responded
  IF EXISTS (
    SELECT 1 FROM copy_trade_responses
    WHERE pending_trade_id = p_trade_id
    AND follower_id = p_follower_id
  ) THEN
    RAISE EXCEPTION 'Already responded to this trade';
  END IF;

  -- If accepting, validate risk acknowledgment
  IF p_response = 'accepted' AND NOT p_risk_acknowledged THEN
    RAISE EXCEPTION 'Must acknowledge risk to accept trade';
  END IF;

  -- Calculate allocated amount based on copy settings
  v_allocated_amount := (v_relationship.copy_amount / 100.0) * v_trade.margin_used;

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'spot' END;

  -- If accepting, validate balance
  IF p_response = 'accepted' THEN
    SELECT balance INTO v_current_balance
    FROM wallets
    WHERE user_id = p_follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    IF v_current_balance IS NULL OR v_current_balance < v_allocated_amount THEN
      RAISE EXCEPTION 'Insufficient balance to accept trade';
    END IF;
  END IF;

  -- Create response record
  INSERT INTO copy_trade_responses (
    pending_trade_id,
    follower_id,
    copy_relationship_id,
    response,
    decline_reason,
    risk_acknowledged,
    allocated_amount,
    follower_leverage,
    responded_at
  ) VALUES (
    p_trade_id,
    p_follower_id,
    v_relationship.id,
    p_response,
    p_decline_reason,
    p_risk_acknowledged,
    v_allocated_amount,
    v_trade.leverage * v_relationship.leverage,
    NOW()
  ) RETURNING id INTO v_response_id;

  -- Update notification status
  UPDATE copy_trade_notifications
  SET 
    notification_status = 'responded',
    responded_at = NOW()
  WHERE follower_id = p_follower_id
  AND pending_trade_id = p_trade_id;

  -- Update trade stats
  IF p_response = 'accepted' THEN
    UPDATE pending_copy_trades
    SET total_accepted = total_accepted + 1
    WHERE id = p_trade_id;

    -- Execute the trade immediately for this follower
    PERFORM execute_accepted_trade(p_trade_id, p_follower_id);
  ELSE
    UPDATE pending_copy_trades
    SET total_declined = total_declined + 1
    WHERE id = p_trade_id;
  END IF;

  RETURN v_response_id;
END;
$$;

-- Function to execute trade for an accepted follower
CREATE OR REPLACE FUNCTION execute_accepted_trade(
  p_trade_id uuid,
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
  v_wallet_type text;
  v_allocation_id uuid;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id;

  -- Get response details
  SELECT * INTO v_response
  FROM copy_trade_responses
  WHERE pending_trade_id = p_trade_id
  AND follower_id = p_follower_id
  AND response = 'accepted';

  IF v_response IS NULL THEN
    RAISE EXCEPTION 'No accepted response found';
  END IF;

  -- Get relationship
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE id = v_response.copy_relationship_id;

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'spot' END;

  -- Deduct allocated amount from wallet
  UPDATE wallets
  SET 
    balance = balance - v_response.allocated_amount,
    updated_at = NOW()
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  -- Create allocation in copy_trade_allocations
  INSERT INTO copy_trade_allocations (
    trader_trade_id,
    follower_id,
    copy_relationship_id,
    allocated_amount,
    follower_leverage,
    entry_price,
    status
  ) VALUES (
    p_trade_id,
    p_follower_id,
    v_relationship.id,
    v_response.allocated_amount,
    v_response.follower_leverage,
    v_trade.entry_price,
    'open'
  ) RETURNING id INTO v_allocation_id;

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
    p_follower_id,
    'copy_trade_allocation',
    'USDT',
    -v_response.allocated_amount,
    'completed',
    format('Copy trade allocation: %s %s', v_trade.pair, v_trade.side),
    jsonb_build_object(
      'trade_id', p_trade_id,
      'allocation_id', v_allocation_id,
      'pair', v_trade.pair,
      'side', v_trade.side
    )
  );
END;
$$;

-- Function to expire pending trades (to be called periodically)
CREATE OR REPLACE FUNCTION expire_pending_trades()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer := 0;
  v_trade RECORD;
  v_notification RECORD;
BEGIN
  -- Find all pending trades that have expired
  FOR v_trade IN
    SELECT *
    FROM pending_copy_trades
    WHERE status = 'pending'
    AND expires_at < NOW()
  LOOP
    -- Mark trade as expired
    UPDATE pending_copy_trades
    SET status = 'expired'
    WHERE id = v_trade.id;

    -- Mark unresponded notifications as expired
    FOR v_notification IN
      SELECT *
      FROM copy_trade_notifications
      WHERE pending_trade_id = v_trade.id
      AND notification_status = 'unread'
    LOOP
      -- Create expired response record
      INSERT INTO copy_trade_responses (
        pending_trade_id,
        follower_id,
        copy_relationship_id,
        response,
        risk_acknowledged,
        responded_at
      )
      SELECT
        v_trade.id,
        v_notification.follower_id,
        cr.id,
        'expired',
        false,
        NOW()
      FROM copy_relationships cr
      WHERE cr.follower_id = v_notification.follower_id
      AND cr.trader_id = v_trade.trader_id
      ON CONFLICT (pending_trade_id, follower_id) DO NOTHING;

      -- Update notification
      UPDATE copy_trade_notifications
      SET 
        notification_status = 'responded',
        responded_at = NOW()
      WHERE id = v_notification.id;

      -- Update expired count
      UPDATE pending_copy_trades
      SET total_expired = total_expired + 1
      WHERE id = v_trade.id;
    END LOOP;

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN v_expired_count;
END;
$$;
