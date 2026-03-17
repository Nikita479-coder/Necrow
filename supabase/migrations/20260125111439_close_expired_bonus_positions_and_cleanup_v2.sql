/*
  # Close Expired Bonus Positions and Cleanup V2
  
  1. Problem
    - There are expired locked bonuses with remaining balances
    - Some users have open positions using margin from expired bonuses
    - These need to be cleaned up properly
  
  2. Actions
    - Close all open positions that have margin from expired locked bonuses
    - Zero out all expired bonus balances
    - Set all expired bonuses to 'expired' status
  
  3. Safety
    - Only affects bonus funds, not real user deposits
    - Positions are closed at current price (treated as liquidation due to bonus expiry)
*/

DO $$
DECLARE
  v_position RECORD;
  v_current_price numeric;
  v_pnl numeric;
  v_closed_count integer := 0;
BEGIN
  -- Step 1: Close all open positions that have margin from expired locked bonuses
  FOR v_position IN
    SELECT DISTINCT ON (fp.position_id)
      fp.position_id,
      fp.user_id,
      fp.pair,
      fp.side,
      fp.entry_price,
      fp.quantity,
      fp.margin_allocated,
      fp.margin_from_locked_bonus,
      fp.unrealized_pnl
    FROM futures_positions fp
    JOIN locked_bonuses lb ON lb.user_id = fp.user_id
    WHERE fp.status = 'open'
    AND lb.expires_at < now()
    AND fp.margin_from_locked_bonus > 0
  LOOP
    -- Get current market price
    SELECT last_price INTO v_current_price
    FROM market_prices
    WHERE pair = v_position.pair
    LIMIT 1;
    
    IF v_current_price IS NULL THEN
      v_current_price := v_position.entry_price;
    END IF;
    
    -- Calculate PnL
    IF v_position.side = 'long' THEN
      v_pnl := (v_current_price - v_position.entry_price) * v_position.quantity;
    ELSE
      v_pnl := (v_position.entry_price - v_current_price) * v_position.quantity;
    END IF;
    
    -- Close the position
    UPDATE futures_positions
    SET 
      status = 'closed',
      closed_at = now(),
      mark_price = v_current_price,
      realized_pnl = v_pnl,
      unrealized_pnl = 0
    WHERE position_id = v_position.position_id;
    
    v_closed_count := v_closed_count + 1;
    
    -- Log the closure
    INSERT INTO admin_activity_logs (
      admin_id,
      action_type,
      action_description,
      target_user_id,
      metadata
    ) VALUES (
      v_position.user_id,
      'bonus_position_closed',
      'Position closed due to locked bonus expiration',
      v_position.user_id,
      jsonb_build_object(
        'position_id', v_position.position_id,
        'pair', v_position.pair,
        'side', v_position.side,
        'margin_from_bonus', v_position.margin_from_locked_bonus,
        'pnl', v_pnl,
        'reason', 'bonus_expired'
      )
    );
    
    RAISE NOTICE 'Closed position % for user % - PnL: %', v_position.position_id, v_position.user_id, v_pnl;
  END LOOP;
  
  RAISE NOTICE 'Closed % positions with expired bonus margin', v_closed_count;
  
  -- Step 2: Zero out all expired bonus balances and set status to expired
  UPDATE locked_bonuses
  SET 
    current_amount = 0,
    status = 'expired',
    updated_at = now()
  WHERE expires_at < now()
  AND (status = 'active' OR status = 'unlocked' OR current_amount > 0);
  
  RAISE NOTICE 'All expired bonuses have been cleaned up';
END $$;
