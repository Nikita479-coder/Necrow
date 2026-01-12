/*
  # Fix Liquidation Notification Type

  1. Changes
    - Update notifications type constraint to include all existing types plus 'position_liquidated'
    - Fix execute_liquidation function to use correct column name 'type' instead of 'notification_type'
    
  2. Security
    - No RLS changes needed
*/

-- Update the notifications table constraint to include all existing types
DO $$ 
BEGIN
  -- Drop the old constraint
  ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
  
  -- Add comprehensive constraint with all notification types
  ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
    CHECK (type IN (
      'referral_payout',
      'trade_executed',
      'kyc_update',
      'account_update',
      'system',
      'copy_trade',
      'position_closed',
      'position_sl_hit',
      'position_tp_hit',
      'position_liquidated',
      'vip_downgrade',
      'vip_upgrade',
      'shark_card_application',
      'withdrawal_completed',
      'withdrawal_rejected',
      'bonus',
      'affiliate_payout',
      'pending_copy_trade',
      'deposit_completed',
      'deposit_failed'
    ));
END $$;

-- Fix execute_liquidation function to use correct column name
CREATE OR REPLACE FUNCTION execute_liquidation(p_position_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position record;
  v_liquidation_price numeric;
  v_liquidation_fee numeric;
  v_remaining_equity numeric;
  v_insurance_fund_loss numeric := 0;
  v_transaction_id uuid;
  v_locked_bonus_id uuid;
BEGIN
  -- Lock position
  SELECT * INTO v_position
  FROM futures_positions
  WHERE position_id = p_position_id
    AND status = 'open'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Position not found');
  END IF;

  -- Get current mark price as liquidation price
  SELECT mark_price INTO v_liquidation_price
  FROM market_prices
  WHERE pair = v_position.pair;

  v_liquidation_price := COALESCE(v_liquidation_price, v_position.liquidation_price);

  -- Calculate liquidation fee
  v_liquidation_fee := calculate_liquidation_fee_amount(
    v_position.pair,
    v_position.quantity,
    v_liquidation_price
  );

  -- Calculate remaining equity
  v_remaining_equity := v_position.margin_allocated +
    calculate_unrealized_pnl(v_position.side, v_position.entry_price, v_liquidation_price, v_position.quantity);

  v_remaining_equity := v_remaining_equity - v_liquidation_fee;

  -- If equity is negative, insurance fund covers it
  IF v_remaining_equity < 0 THEN
    v_insurance_fund_loss := ABS(v_remaining_equity);
    v_remaining_equity := 0;
  END IF;

  -- Mark position as liquidated
  UPDATE futures_positions
  SET status = 'liquidated',
      realized_pnl = v_remaining_equity - v_position.margin_allocated,
      cumulative_fees = cumulative_fees + v_liquidation_fee,
      closed_at = now()
  WHERE position_id = p_position_id;

  -- Return remaining equity to wallet (if any)
  IF v_remaining_equity > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance + v_remaining_equity,
        updated_at = now()
    WHERE user_id = v_position.user_id;
  END IF;

  -- Create transaction record for the liquidation
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    fee,
    status,
    details,
    created_at
  ) VALUES (
    v_position.user_id,
    'futures_close',
    'USDT',
    v_liquidation_fee,
    v_liquidation_fee,
    'completed',
    format('Position liquidated: %s %s %sx. Margin lost: %s USDT, Liquidation Fee: %s USDT',
      v_position.pair,
      UPPER(v_position.side),
      v_position.leverage,
      ROUND(v_position.margin_allocated, 2),
      ROUND(v_liquidation_fee, 2)
    ),
    now()
  ) RETURNING id INTO v_transaction_id;

  -- If position used locked bonus, deduct from locked bonus balance
  IF v_position.margin_from_locked_bonus > 0 THEN
    -- Find the active locked bonus to deduct from (oldest first)
    SELECT id INTO v_locked_bonus_id
    FROM locked_bonuses
    WHERE user_id = v_position.user_id
      AND status = 'active'
      AND current_amount > 0
    ORDER BY expires_at ASC
    LIMIT 1;

    IF v_locked_bonus_id IS NOT NULL THEN
      UPDATE locked_bonuses
      SET current_amount = GREATEST(0, current_amount - v_position.margin_from_locked_bonus),
          updated_at = now()
      WHERE id = v_locked_bonus_id;
    END IF;
  END IF;

  -- Log liquidation event
  INSERT INTO liquidation_events (
    position_id, user_id, pair, side, quantity, entry_price,
    liquidation_price, equity_before, loss_amount, liquidation_fee,
    insurance_fund_used
  )
  VALUES (
    p_position_id, v_position.user_id, v_position.pair, v_position.side,
    v_position.quantity, v_position.entry_price, v_liquidation_price,
    v_position.margin_allocated, v_position.margin_allocated - v_remaining_equity,
    v_liquidation_fee, v_insurance_fund_loss
  );

  -- Create notification for user (FIXED: use 'type' instead of 'notification_type')
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    read,
    created_at
  ) VALUES (
    v_position.user_id,
    'position_liquidated',
    'Position Liquidated',
    format('Your %s %s position at %sx leverage was liquidated. Margin lost: $%s',
      v_position.pair,
      UPPER(v_position.side),
      v_position.leverage,
      ROUND(v_position.margin_allocated, 2)
    ),
    false,
    now()
  );

  -- Remove from liquidation queue
  DELETE FROM liquidation_queue WHERE position_id = p_position_id;

  RETURN jsonb_build_object(
    'success', true,
    'liquidation_price', v_liquidation_price,
    'remaining_equity', v_remaining_equity,
    'liquidation_fee', v_liquidation_fee
  );
END;
$$;
