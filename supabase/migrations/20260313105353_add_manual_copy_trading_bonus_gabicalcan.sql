/*
  # Add Manual 10 USD Copy Trading Bonus for gabicalcan@yahoo.com
  
  ## User Details
  - Email: gabicalcan@yahoo.com
  - User ID: fb945ebc-8136-4a0f-91fb-fbf2f1081f23
  - Active copy relationship ID: fad63ceb-f4d5-4742-97c1-a66522ca77f5
  - Trader: Satoshi Academy
  
  ## Bonus Details
  - Amount: 10 USDT
  - Lock period: 30 days (same as automatic bonus)
  - Similar to the 100 USD bonus awarded at 500 USD allocation
  
  ## Actions
  1. Add 10 USDT to copy wallet balance
  2. Update relationship with bonus amount and lock date
  3. Record claim in copy_trading_bonus_claims table
  4. Create notification for user
  5. Create transaction record
*/

DO $$
DECLARE
  v_user_id uuid := 'fb945ebc-8136-4a0f-91fb-fbf2f1081f23';
  v_relationship_id uuid := 'fad63ceb-f4d5-4742-97c1-a66522ca77f5';
  v_bonus_amount numeric := 10;
  v_lock_days integer := 30;
  v_trader_name text := 'Satoshi Academy';
BEGIN
  -- 1. Add bonus to copy wallet
  UPDATE wallets
  SET 
    balance = balance + v_bonus_amount,
    updated_at = now()
  WHERE user_id = v_user_id 
    AND currency = 'USDT' 
    AND wallet_type = 'copy';

  -- 2. Update relationship with bonus details
  UPDATE copy_relationships
  SET 
    initial_balance = initial_balance + v_bonus_amount,
    current_balance = current_balance + v_bonus_amount,
    bonus_amount = v_bonus_amount,
    bonus_claimed_at = now(),
    bonus_locked_until = now() + (v_lock_days || ' days')::interval,
    updated_at = now()
  WHERE id = v_relationship_id;

  -- 3. Record the claim
  INSERT INTO copy_trading_bonus_claims (
    user_id, 
    relationship_id, 
    amount, 
    claimed_at
  )
  VALUES (
    v_user_id, 
    v_relationship_id, 
    v_bonus_amount, 
    now()
  );

  -- 4. Create notification
  INSERT INTO notifications (
    user_id, 
    type, 
    title, 
    message, 
    read, 
    data, 
    created_at
  )
  VALUES (
    v_user_id,
    'reward',
    'Copy Trading Bonus!',
    'You received 10 USDT bonus on your copy trading with ' || v_trader_name || '. Keep it for 30 days to unlock!',
    false,
    jsonb_build_object(
      'bonus_amount', v_bonus_amount,
      'relationship_id', v_relationship_id,
      'trader_name', v_trader_name
    ),
    now()
  );

  -- 5. Record transaction
  INSERT INTO transactions (
    user_id,
    transaction_type,
    currency,
    amount,
    status,
    details,
    confirmed_at
  )
  VALUES (
    v_user_id,
    'reward',
    'USDT',
    v_bonus_amount,
    'completed',
    jsonb_build_object(
      'type', 'copy_trading_bonus_manual',
      'relationship_id', v_relationship_id,
      'trader_name', v_trader_name,
      'note', 'Manual bonus grant'
    ),
    now()
  );

  RAISE NOTICE 'Successfully granted 10 USDT copy trading bonus to gabicalcan@yahoo.com';
END $$;
