/*
  # Fix respond_to_copy_trade to Auto-Create Relationship

  ## Problem
  Users receive pending trade notifications but may not have an existing copy_relationships record.
  This causes "No active copy relationship found" errors when trying to accept trades.

  ## Solution
  Auto-create the copy_relationships record when a user accepts their first trade from a trader.
  Use default settings: 10% allocation, 1x leverage, mock mode initially.

  ## Changes
  - Modify respond_to_copy_trade to create relationship if it doesn't exist
  - Only create on acceptance, not on decline
  - Use sensible defaults for first-time copiers
*/

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
  v_relationship_created boolean := false;
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

  -- If no relationship exists and user is accepting, create one
  IF v_relationship IS NULL AND p_response = 'accepted' THEN
    -- Determine if this should be mock or real based on wallet balance
    DECLARE
      v_copy_wallet_balance numeric := 0;
      v_is_mock boolean := true;
    BEGIN
      -- Check if user has copy wallet with balance
      SELECT COALESCE(balance, 0) INTO v_copy_wallet_balance
      FROM wallets
      WHERE user_id = p_follower_id
      AND currency = 'USDT'
      AND wallet_type = 'copy';

      -- If they have > 100 USDT in copy wallet, use real mode
      IF v_copy_wallet_balance >= 100 THEN
        v_is_mock := false;
      END IF;

      -- Create the relationship
      INSERT INTO copy_relationships (
        follower_id,
        trader_id,
        allocation_percentage,
        leverage,
        is_mock,
        status,
        is_active,
        started_at
      ) VALUES (
        p_follower_id,
        v_trade.trader_id,
        10, -- Default 10% allocation
        1,  -- Default 1x leverage
        v_is_mock,
        'active',
        true,
        NOW()
      )
      ON CONFLICT (follower_id, trader_id, is_mock)
      DO UPDATE SET
        status = 'active',
        is_active = true,
        started_at = CASE WHEN copy_relationships.status != 'active' THEN NOW() ELSE copy_relationships.started_at END,
        updated_at = NOW()
      RETURNING * INTO v_relationship;

      v_relationship_created := true;
    END;
  END IF;

  -- If still no relationship (e.g., declining without one), that's fine
  IF v_relationship IS NULL AND p_response = 'declined' THEN
    -- Just record the decline, no relationship needed
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
      NULL, -- No relationship for declines
      p_response,
      p_decline_reason,
      p_risk_acknowledged,
      0,
      0,
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
    UPDATE pending_copy_trades
    SET total_declined = total_declined + 1
    WHERE id = p_trade_id;

    RETURN v_response_id;
  END IF;

  -- If still no relationship at this point, something's wrong
  IF v_relationship IS NULL THEN
    RAISE EXCEPTION 'Failed to establish copy relationship';
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

  -- Determine wallet type: copy for real trading, main for mock
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'main' ELSE 'copy' END;

  -- Ensure wallet exists using helper function
  PERFORM ensure_wallet(p_follower_id, 'USDT', v_wallet_type, 0);

  -- Get follower's current balance
  SELECT COALESCE(balance, 0) INTO v_current_balance
  FROM wallets
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_current_balance IS NULL THEN
    v_current_balance := 0;
  END IF;

  -- Calculate allocated amount based on PERCENTAGE of follower's balance
  v_allocated_amount := (v_current_balance * COALESCE(v_trade.margin_percentage, 0)) / 100.0;

  -- Apply relationship multiplier if configured
  IF v_relationship.allocation_percentage IS NOT NULL AND v_relationship.allocation_percentage > 0 THEN
    v_allocated_amount := v_allocated_amount * (v_relationship.allocation_percentage / 100.0);
  END IF;

  -- Validate sufficient balance if accepting
  IF p_response = 'accepted' THEN
    IF v_current_balance < v_allocated_amount THEN
      RAISE EXCEPTION 'Insufficient balance: need % but have %', v_allocated_amount, v_current_balance;
    END IF;

    -- Ensure minimum allocation
    IF v_allocated_amount < 1 THEN
      RAISE EXCEPTION 'Calculated allocation too small: minimum $1 required';
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

    -- If we created a relationship, notify the user
    IF v_relationship_created THEN
      PERFORM send_notification(
        p_follower_id,
        'copy_started',
        'Copy Trading Started',
        'You are now copying this trader in ' || CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'real' END || ' mode with 10% allocation.',
        jsonb_build_object('trader_id', v_trade.trader_id, 'relationship_id', v_relationship.id)
      );
    END IF;
  ELSE
    UPDATE pending_copy_trades
    SET total_declined = total_declined + 1
    WHERE id = p_trade_id;
  END IF;

  RETURN v_response_id;
END;
$$;