/*
  # Add Helper Views and Automatic Expiration (Fixed)
  
  ## Changes
  1. Create a unified view for traders (admin only for now)
  2. Update respond_to_copy_trade to check expiration
  
  ## Features
  - Better trader info retrieval
  - Expiration checking in response function
*/

-- Update respond_to_copy_trade to automatically check expiration
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
  v_effective_trader_id uuid;
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
    -- Mark as expired
    UPDATE pending_copy_trades
    SET status = 'expired'
    WHERE id = p_trade_id;
    
    RAISE EXCEPTION 'Trade has expired';
  END IF;

  -- Determine effective trader ID
  v_effective_trader_id := COALESCE(v_trade.admin_trader_id, v_trade.trader_id);

  -- Get relationship details
  SELECT * INTO v_relationship
  FROM copy_relationships
  WHERE follower_id = p_follower_id
  AND trader_id = v_effective_trader_id
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

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'copy' END;

  -- Get current balance
  SELECT balance INTO v_current_balance
  FROM wallets
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  -- Calculate allocated amount based on margin percentage
  v_allocated_amount := (COALESCE(v_current_balance, 0) * v_trade.margin_percentage) / 100.0;

  -- If accepting, validate balance
  IF p_response = 'accepted' THEN
    IF v_current_balance IS NULL OR v_current_balance < v_allocated_amount THEN
      RAISE EXCEPTION 'Insufficient balance to accept trade. Need % USDT, have % USDT', 
        v_allocated_amount, COALESCE(v_current_balance, 0);
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
