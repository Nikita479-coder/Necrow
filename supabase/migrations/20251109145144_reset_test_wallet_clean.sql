/*
  # Reset Test Wallet - Clean Version

  ## Description
  Cleans up broken test data and resets wallet to working state

  ## Changes
  - Deletes positions and orders for test user
  - Resets wallet balance to 25000 USDT
*/

DO $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT user_id INTO v_user_id
  FROM futures_margin_wallets
  WHERE available_balance < 100 AND locked_balance > 100
  LIMIT 1;

  IF v_user_id IS NOT NULL THEN
    -- Delete all positions
    DELETE FROM futures_positions WHERE user_id = v_user_id;
    
    -- Delete all orders
    DELETE FROM futures_orders WHERE user_id = v_user_id;

    -- Reset wallet
    UPDATE futures_margin_wallets
    SET available_balance = 25000,
        locked_balance = 0,
        updated_at = now()
    WHERE user_id = v_user_id;

    RAISE NOTICE 'Reset complete for user: %', v_user_id;
  END IF;
END $$;