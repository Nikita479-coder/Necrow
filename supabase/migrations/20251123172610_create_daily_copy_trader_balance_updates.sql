/*
  # Daily Copy Trader Balance Updates

  1. New Function
    - `update_copy_trader_daily_balances()` - Updates all copy traders' balances based on traders' daily performance
    
  2. Logic
    - For each active copy relationship
    - Apply the trader's daily ROI to the follower's allocated amount
    - Update wallet balances in real-time
    - Track daily P&L in copy_trade_allocations
*/

-- Create a new table to track daily copy trading performance
CREATE TABLE IF NOT EXISTS copy_trade_daily_performance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trader_id uuid REFERENCES traders(id) ON DELETE CASCADE NOT NULL,
  copy_relationship_id uuid REFERENCES copy_relationships(id) ON DELETE CASCADE NOT NULL,
  performance_date date NOT NULL DEFAULT CURRENT_DATE,
  starting_balance numeric NOT NULL,
  daily_pnl numeric NOT NULL DEFAULT 0,
  daily_roi numeric NOT NULL DEFAULT 0,
  ending_balance numeric NOT NULL,
  trader_daily_roi numeric NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(follower_id, trader_id, performance_date)
);

-- Enable RLS
ALTER TABLE copy_trade_daily_performance ENABLE ROW LEVEL SECURITY;

-- Users can view their own copy performance
CREATE POLICY "Users can view own copy performance"
  ON copy_trade_daily_performance FOR SELECT
  TO authenticated
  USING (follower_id = auth.uid());

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_copy_daily_perf_follower ON copy_trade_daily_performance(follower_id);
CREATE INDEX IF NOT EXISTS idx_copy_daily_perf_date ON copy_trade_daily_performance(performance_date DESC);

-- Function to update copy trader balances daily
CREATE OR REPLACE FUNCTION update_copy_trader_daily_balances()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_relationship RECORD;
  v_trader_daily_roi numeric;
  v_follower_wallet_balance numeric;
  v_wallet_type text;
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
      cr.copy_amount,
      cr.is_mock,
      t.name as trader_name
    FROM copy_relationships cr
    JOIN traders t ON t.id = cr.trader_id
    WHERE cr.status = 'active'
    AND cr.is_active = true
  LOOP
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

    -- Determine wallet type
    v_wallet_type := CASE WHEN v_relationship.is_mock THEN 'mock_copy' ELSE 'copy_trading' END;

    -- Get follower's current wallet balance
    SELECT balance INTO v_follower_wallet_balance
    FROM wallets
    WHERE user_id = v_relationship.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    -- Skip if wallet doesn't exist or has no balance
    IF v_follower_wallet_balance IS NULL OR v_follower_wallet_balance <= 0 THEN
      CONTINUE;
    END IF;

    -- Use the allocated copy amount or current balance (whichever is smaller)
    v_follower_wallet_balance := LEAST(v_follower_wallet_balance, v_relationship.copy_amount);

    -- Calculate daily P&L for follower (apply trader's daily ROI)
    v_daily_pnl := v_follower_wallet_balance * (v_trader_daily_roi / 100);
    v_new_balance := v_follower_wallet_balance + v_daily_pnl;

    -- Update follower's wallet balance
    UPDATE wallets
    SET 
      balance = balance + v_daily_pnl,
      updated_at = NOW()
    WHERE user_id = v_relationship.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

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
      v_follower_wallet_balance,
      v_daily_pnl,
      v_trader_daily_roi,
      v_new_balance,
      v_trader_daily_roi
    )
    ON CONFLICT (follower_id, trader_id, performance_date)
    DO UPDATE SET
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

-- Update the main trader update function to also update copy traders
CREATE OR REPLACE FUNCTION process_daily_trader_updates()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader RECORD;
  v_results json[] := ARRAY[]::json[];
  v_daily_pnl numeric;
  v_copy_result json;
BEGIN
  -- Process each automated trader
  FOR v_trader IN 
    SELECT * FROM traders 
    WHERE is_automated = true
    ORDER BY id
  LOOP
    -- Generate daily P&L
    v_daily_pnl := generate_daily_trader_pnl(v_trader.id);
    
    -- Update statistics
    PERFORM update_trader_statistics(v_trader.id);
    
    -- Add to results
    v_results := array_append(v_results, json_build_object(
      'trader_id', v_trader.id,
      'trader_name', v_trader.name,
      'daily_pnl', v_daily_pnl,
      'updated', true
    ));
  END LOOP;

  -- Update all copy traders' balances
  v_copy_result := update_copy_trader_daily_balances();

  RETURN json_build_object(
    'success', true,
    'processed_count', array_length(v_results, 1),
    'results', v_results,
    'copy_traders', v_copy_result
  );
END;
$$;
