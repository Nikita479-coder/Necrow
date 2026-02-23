/*
  # Fix auto-accept for users with both mock and live copy relationships

  ## Problem
  When a user follows the same trader on both mock and live, auto-accept only
  processes one relationship. The `pending_trade_responses` table has a UNIQUE
  constraint on `(pending_trade_id, follower_id)`, so the second auto-accept
  call finds "Already responded" and skips it.

  ## Fix
  1. Add `copy_relationship_id` column to `pending_trade_responses`
  2. Drop the old unique constraint, add new one on `(pending_trade_id, follower_id, copy_relationship_id)`
  3. Update `auto_accept_pending_trade` to check and record with relationship_id
  4. Update `respond_to_copy_trade` to loop through ALL active relationships for the follower
  5. Update `create_pending_trade_only` - already loops per relationship, just needs the inner
     functions to work correctly

  ## Modified Tables
  - `pending_trade_responses` - add `copy_relationship_id` column, change unique constraint

  ## Modified Functions
  - `auto_accept_pending_trade` - check duplicate by relationship_id
  - `respond_to_copy_trade` - process all relationships for follower
*/

-- 1. Add copy_relationship_id column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pending_trade_responses' AND column_name = 'copy_relationship_id'
  ) THEN
    ALTER TABLE pending_trade_responses ADD COLUMN copy_relationship_id uuid REFERENCES copy_relationships(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 2. Drop old unique constraint, add new one
ALTER TABLE pending_trade_responses
  DROP CONSTRAINT IF EXISTS pending_trade_responses_pending_trade_id_follower_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS pending_trade_responses_trade_follower_relationship_key
  ON pending_trade_responses (pending_trade_id, follower_id, copy_relationship_id);

-- 3. Update auto_accept_pending_trade to use relationship_id in duplicate check
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
  v_is_mock boolean;
BEGIN
  IF EXISTS (
    SELECT 1 FROM pending_trade_responses ptr
    WHERE ptr.pending_trade_id = p_trade_id
    AND ptr.follower_id = p_follower_id
    AND ptr.copy_relationship_id = p_relationship_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Already responded to this trade for this relationship'
    );
  END IF;

  SELECT * INTO v_pending_trade
  FROM pending_copy_trades pct
  WHERE pct.id = p_trade_id
  AND pct.status = 'pending'
  AND pct.expires_at > NOW();

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

  v_is_mock := v_relationship.is_mock;

  INSERT INTO pending_trade_responses (
    pending_trade_id,
    follower_id,
    copy_relationship_id,
    response,
    decline_reason,
    auto_accepted
  ) VALUES (
    p_trade_id,
    p_follower_id,
    p_relationship_id,
    'accepted',
    'auto-accepted',
    true
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

    UPDATE pending_copy_trades pct
    SET trader_trade_id = v_trader_trade_id
    WHERE pct.id = p_trade_id;
  ELSE
    v_trader_trade_id := v_pending_trade.trader_trade_id;
  END IF;

  IF v_is_mock THEN
    v_wallet_balance := COALESCE(v_relationship.current_balance, 0);
  ELSE
    v_wallet_type := v_relationship.wallet_type_name;
    SELECT COALESCE(w.balance, 0) INTO v_wallet_balance
    FROM wallets w
    WHERE w.user_id = p_follower_id
    AND w.currency = 'USDT'
    AND w.wallet_type = v_wallet_type;
  END IF;

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

  IF v_is_mock THEN
    UPDATE copy_relationships cr
    SET
      current_balance = cr.current_balance - v_allocated_amount,
      updated_at = NOW()
    WHERE cr.id = p_relationship_id;
  ELSE
    UPDATE wallets w
    SET
      balance = w.balance - v_allocated_amount,
      updated_at = NOW()
    WHERE w.user_id = p_follower_id
    AND w.currency = 'USDT'
    AND w.wallet_type = v_wallet_type;
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

  UPDATE copy_relationships cr
  SET
    total_trades_copied = COALESCE(cr.total_trades_copied, 0) + 1,
    updated_at = NOW()
  WHERE cr.id = v_relationship.id;

  UPDATE pending_copy_trades pct
  SET total_accepted = pct.total_accepted + 1
  WHERE pct.id = p_trade_id;

  UPDATE notifications n
  SET read = true
  WHERE n.user_id = p_follower_id
  AND n.type = 'pending_copy_trade'
  AND (n.data->>'pending_trade_id')::uuid = p_trade_id;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_follower_id,
    'copy_trade',
    'Trade Auto-Accepted',
    'Auto-accepted ' || v_pending_trade.pair || ' ' || CASE WHEN v_is_mock THEN '(Mock) ' ELSE '' END || 'trade with ' || ROUND(v_allocated_amount, 2)::text || ' USDT at $' || ROUND(v_pending_trade.entry_price, 2)::text,
    false
  );

  RETURN json_build_object(
    'success', true,
    'allocation_id', v_allocation_id,
    'allocated_amount', v_allocated_amount
  );
END;
$$;


-- 4. Update respond_to_copy_trade to handle ALL relationships for a follower
CREATE OR REPLACE FUNCTION respond_to_copy_trade(
  p_trade_id uuid,
  p_follower_id uuid,
  p_response text,
  p_decline_reason text DEFAULT NULL
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
  v_is_mock boolean;
  v_total_accepted integer := 0;
  v_total_allocations json[] := '{}';
BEGIN
  IF auth.uid() != p_follower_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_pending_trade
  FROM pending_copy_trades
  WHERE id = p_trade_id
  AND status = 'pending'
  AND expires_at > NOW();

  IF v_pending_trade IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Trade not found, already responded to, or expired'
    );
  END IF;

  FOR v_relationship IN
    SELECT cr.*,
      CASE WHEN cr.is_mock THEN 'mock' ELSE 'copy' END as wallet_type_name
    FROM copy_relationships cr
    WHERE cr.trader_id = v_pending_trade.trader_id
    AND cr.follower_id = p_follower_id
    AND cr.status = 'active'
    AND cr.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM pending_trade_responses ptr
      WHERE ptr.pending_trade_id = p_trade_id
      AND ptr.follower_id = p_follower_id
      AND ptr.copy_relationship_id = cr.id
    )
    ORDER BY cr.is_mock ASC
  LOOP
    v_is_mock := v_relationship.is_mock;

    INSERT INTO pending_trade_responses (
      pending_trade_id,
      follower_id,
      copy_relationship_id,
      response,
      decline_reason
    ) VALUES (
      p_trade_id,
      p_follower_id,
      v_relationship.id,
      p_response,
      p_decline_reason
    );

    IF p_response = 'declined' THEN
      UPDATE pending_copy_trades
      SET total_declined = total_declined + 1
      WHERE id = p_trade_id;
      CONTINUE;
    END IF;

    IF v_pending_trade.trader_trade_id IS NULL AND v_trader_trade_id IS NULL THEN
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
        v_pending_trade.trader_id,
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
      v_trader_trade_id := COALESCE(v_trader_trade_id, v_pending_trade.trader_trade_id);
    END IF;

    IF v_is_mock THEN
      v_wallet_balance := COALESCE(v_relationship.current_balance, 0);
    ELSE
      SELECT COALESCE(balance, 0) INTO v_wallet_balance
      FROM wallets
      WHERE user_id = p_follower_id
      AND currency = 'USDT'
      AND wallet_type = v_relationship.wallet_type_name;
    END IF;

    IF v_wallet_balance IS NULL OR v_wallet_balance <= 0 THEN
      CONTINUE;
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

    IF v_is_mock THEN
      UPDATE copy_relationships cr
      SET
        current_balance = cr.current_balance - v_allocated_amount,
        updated_at = NOW()
      WHERE cr.id = v_relationship.id;
    ELSE
      UPDATE wallets
      SET
        balance = balance - v_allocated_amount,
        updated_at = NOW()
      WHERE user_id = p_follower_id
      AND currency = 'USDT'
      AND wallet_type = v_relationship.wallet_type_name;
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
    ) VALUES (
      v_trader_trade_id,
      p_follower_id,
      v_relationship.id,
      v_allocated_amount,
      v_pending_trade.leverage * COALESCE(v_relationship.leverage, 1),
      v_pending_trade.entry_price,
      v_pending_trade.side,
      'open',
      'pending_accepted'
    ) RETURNING id INTO v_allocation_id;

    UPDATE copy_relationships
    SET
      total_trades_copied = COALESCE(total_trades_copied, 0) + 1,
      updated_at = NOW()
    WHERE id = v_relationship.id;

    v_total_accepted := v_total_accepted + 1;

    INSERT INTO notifications (user_id, type, title, message, read)
    VALUES (
      p_follower_id,
      'copy_trade',
      'Trade Copied Successfully',
      'Copied ' || v_pending_trade.pair || ' ' || CASE WHEN v_is_mock THEN '(Mock) ' ELSE '' END || 'trade with ' || ROUND(v_allocated_amount, 2)::text || ' USDT',
      false
    );
  END LOOP;

  IF v_total_accepted > 0 THEN
    UPDATE pending_copy_trades
    SET total_accepted = total_accepted + v_total_accepted
    WHERE id = p_trade_id;
  END IF;

  UPDATE notifications
  SET read = true
  WHERE user_id = p_follower_id
  AND type = 'pending_copy_trade'
  AND (data->>'pending_trade_id')::uuid = p_trade_id;

  IF p_response = 'declined' THEN
    RETURN json_build_object(
      'success', true,
      'message', 'Trade declined'
    );
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'Trade accepted for ' || v_total_accepted || ' relationship(s)',
    'total_accepted', v_total_accepted
  );
END;
$$;
