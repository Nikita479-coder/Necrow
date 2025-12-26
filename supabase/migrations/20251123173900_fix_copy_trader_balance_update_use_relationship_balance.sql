/*
  # Fix Copy Trader Balance Update

  1. Changes
    - Update balances directly in copy_relationships table
    - Don't rely on separate wallet entries
    - Use current_balance from the relationship itself
*/

CREATE OR REPLACE FUNCTION update_copy_trader_daily_balances()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_trader_daily_roi numeric;
  v_current_balance numeric;
  v_daily_pnl numeric;
  v_new_balance numeric;
  v_updated_count int := 0;
BEGIN
  -- Loop through all active copy relationships
  FOR v_relationship IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.trader_id,
      cr.initial_balance,
      cr.current_balance,
      cr.total_pnl,
      cr.is_mock,
      t.name as trader_name
    FROM copy_relationships cr
    JOIN traders t ON t.id = cr.trader_id
    WHERE cr.status = 'active'
    AND cr.is_active = true
  LOOP
    -- Get current balance (use initial if current is 0)
    v_current_balance := COALESCE(
      NULLIF(v_relationship.current_balance::numeric, 0),
      v_relationship.initial_balance::numeric
    );

    -- Skip if no balance to update
    IF v_current_balance <= 0 THEN
      CONTINUE;
    END IF;

    -- Get trader's daily ROI from today's performance
    SELECT daily_roi INTO v_trader_daily_roi
    FROM trader_daily_performance
    WHERE trader_id = v_relationship.trader_id
    AND performance_date = CURRENT_DATE
    LIMIT 1;

    -- Skip if no performance data for today
    IF v_trader_daily_roi IS NULL THEN
      CONTINUE;
    END IF;

    -- Calculate daily P&L for follower (apply trader's daily ROI)
    v_daily_pnl := v_current_balance * (v_trader_daily_roi / 100);
    v_new_balance := v_current_balance + v_daily_pnl;

    -- Update copy relationship balance and pnl
    UPDATE copy_relationships
    SET
      current_balance = v_new_balance,
      total_pnl = COALESCE(total_pnl::numeric, 0) + v_daily_pnl,
      updated_at = NOW()
    WHERE id = v_relationship.relationship_id;

    -- Record daily performance
    INSERT INTO copy_trade_daily_performance (
      follower_id,
      trader_id,
      copy_relationship_id,
      performance_date,
      starting_balance,
      daily_pnl,
      daily_roi,
      ending_balance,
      trader_daily_roi
    ) VALUES (
      v_relationship.follower_id,
      v_relationship.trader_id,
      v_relationship.relationship_id,
      CURRENT_DATE,
      v_current_balance,
      v_daily_pnl,
      v_trader_daily_roi,
      v_new_balance,
      v_trader_daily_roi
    )
    ON CONFLICT (follower_id, trader_id, performance_date)
    DO UPDATE SET
      starting_balance = EXCLUDED.starting_balance,
      daily_pnl = EXCLUDED.daily_pnl,
      ending_balance = EXCLUDED.ending_balance,
      trader_daily_roi = EXCLUDED.trader_daily_roi;

    -- Record transaction
    INSERT INTO transactions (
      user_id,
      type,
      currency,
      amount,
      status,
      description
    ) VALUES (
      v_relationship.follower_id,
      'copy_trade_daily_pnl',
      'USDT',
      v_daily_pnl,
      'completed',
      format('Daily copy trading P&L from %s: %s%%', v_relationship.trader_name, ROUND(v_trader_daily_roi, 2))
    );

    v_updated_count := v_updated_count + 1;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'updated_count', v_updated_count,
    'date', CURRENT_DATE
  );
END;
$$;
