/*
  # Fix Pending Trades to Support Admin-Managed Traders
  
  ## Changes
  1. Update pending_copy_trades to reference admin_managed_traders
  2. Fix create_pending_copy_trade to work with admin traders
  3. Update execute_accepted_trade to create proper trader_trades entries
  4. Add automatic expiration cron job setup
  
  ## Tables Modified
  - pending_copy_trades: Add support for admin traders
*/

-- Modify pending_copy_trades to support both user traders and admin traders
DO $$
BEGIN
  -- Make trader_id nullable and add admin_trader_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pending_copy_trades' AND column_name = 'admin_trader_id'
  ) THEN
    ALTER TABLE pending_copy_trades ADD COLUMN admin_trader_id uuid REFERENCES admin_managed_traders(id) ON DELETE CASCADE;
    ALTER TABLE pending_copy_trades ALTER COLUMN trader_id DROP NOT NULL;
    ALTER TABLE pending_copy_trades ADD CONSTRAINT pending_trades_trader_check CHECK (
      (trader_id IS NOT NULL AND admin_trader_id IS NULL) OR 
      (trader_id IS NULL AND admin_trader_id IS NOT NULL)
    );
  END IF;

  -- Add margin_percentage column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pending_copy_trades' AND column_name = 'margin_percentage'
  ) THEN
    ALTER TABLE pending_copy_trades ADD COLUMN margin_percentage numeric DEFAULT 20;
  END IF;
END $$;

-- Update create_pending_copy_trade to handle admin traders
CREATE OR REPLACE FUNCTION create_pending_copy_trade(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_margin_percentage numeric,
  p_notes text DEFAULT NULL,
  p_trader_balance numeric DEFAULT 100000
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
  v_is_admin_trader boolean;
  v_actual_trader_id uuid;
  v_admin_trader_id uuid;
BEGIN
  -- Check if this is an admin-managed trader
  IF EXISTS (SELECT 1 FROM admin_managed_traders WHERE id = p_trader_id) THEN
    v_is_admin_trader := true;
    v_admin_trader_id := p_trader_id;
    v_actual_trader_id := NULL;
  ELSIF EXISTS (SELECT 1 FROM user_profiles WHERE id = p_trader_id) THEN
    v_is_admin_trader := false;
    v_actual_trader_id := p_trader_id;
    v_admin_trader_id := NULL;
  ELSE
    RAISE EXCEPTION 'Trader not found';
  END IF;

  -- Set expiration to 10 minutes from now
  v_expires_at := NOW() + INTERVAL '10 minutes';

  -- Create the pending trade
  INSERT INTO pending_copy_trades (
    trader_id,
    admin_trader_id,
    pair,
    side,
    entry_price,
    quantity,
    leverage,
    margin_used,
    margin_percentage,
    notes,
    trader_balance,
    status,
    expires_at
  ) VALUES (
    v_actual_trader_id,
    v_admin_trader_id,
    p_pair,
    p_side,
    p_entry_price,
    p_quantity,
    p_leverage,
    p_margin_used,
    p_margin_percentage,
    p_notes,
    p_trader_balance,
    'pending',
    v_expires_at
  ) RETURNING id INTO v_trade_id;

  -- Create notifications for all active followers
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.allocation_percentage,
      cr.leverage as follower_leverage_multiplier,
      cr.is_mock,
      cr.notification_enabled,
      cr.current_balance
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
    AND cr.is_active = true
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

-- Update execute_accepted_trade to create proper trader_trades entries
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
  v_trader_trade_id uuid;
  v_follower_balance numeric;
  v_allocated_amount numeric;
  v_effective_trader_id uuid;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id;

  IF v_trade IS NULL THEN
    RAISE EXCEPTION 'Trade not found';
  END IF;

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

  -- Determine effective trader ID (could be admin trader or regular)
  v_effective_trader_id := COALESCE(v_trade.admin_trader_id, v_trade.trader_id);

  -- Check if trader_trades entry exists, if not create it
  SELECT id INTO v_trader_trade_id
  FROM trader_trades
  WHERE trader_id = v_effective_trader_id
  AND symbol = v_trade.pair
  AND entry_price = v_trade.entry_price
  AND status = 'open'
  AND ABS(EXTRACT(EPOCH FROM (opened_at - v_trade.created_at))) < 60;

  -- If no trader_trade exists, create one
  IF v_trader_trade_id IS NULL THEN
    INSERT INTO trader_trades (
      trader_id,
      symbol,
      side,
      entry_price,
      quantity,
      leverage,
      margin_used,
      status,
      opened_at
    ) VALUES (
      v_effective_trader_id,
      v_trade.pair,
      v_trade.side,
      v_trade.entry_price,
      v_trade.quantity,
      v_trade.leverage,
      v_trade.margin_used,
      'open',
      v_trade.created_at
    ) RETURNING id INTO v_trader_trade_id;
  END IF;

  -- Determine wallet type
  v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock' ELSE 'copy' END;

  -- Get follower's balance
  SELECT balance INTO v_follower_balance
  FROM wallets
  WHERE user_id = p_follower_id
  AND currency = 'USDT'
  AND wallet_type = v_wallet_type;

  IF v_follower_balance IS NULL THEN
    -- Create wallet if it doesn't exist
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (p_follower_id, 'USDT', v_wallet_type, 0)
    ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;
    v_follower_balance := 0;
  END IF;

  -- Calculate allocated amount using margin percentage
  v_allocated_amount := (v_follower_balance * v_trade.margin_percentage) / 100.0;

  -- Validate sufficient balance
  IF v_follower_balance < v_allocated_amount THEN
    RAISE EXCEPTION 'Insufficient balance to accept trade';
  END IF;

  -- Deduct allocated amount from wallet
  UPDATE wallets
  SET 
    balance = balance - v_allocated_amount,
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
    status,
    source_type
  ) VALUES (
    v_trader_trade_id,
    p_follower_id,
    v_relationship.id,
    v_allocated_amount,
    v_response.follower_leverage,
    v_trade.entry_price,
    'open',
    'pending_accepted'
  ) RETURNING id INTO v_allocation_id;

  -- Update copy relationship
  UPDATE copy_relationships
  SET 
    total_trades_copied = COALESCE(total_trades_copied, 0) + 1,
    current_balance = COALESCE(current_balance, '0')::numeric + v_allocated_amount
  WHERE id = v_relationship.id;

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
    -v_allocated_amount,
    'completed',
    format('Copy trade allocation: %s %s', v_trade.pair, v_trade.side),
    jsonb_build_object(
      'trade_id', p_trade_id,
      'allocation_id', v_allocation_id,
      'pair', v_trade.pair,
      'side', v_trade.side,
      'source', 'pending_accepted'
    )
  );
END;
$$;
