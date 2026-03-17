/*
  # Move Wallet Balances to Locked KYC Bonus

  For users who have a KYC Verification Bonus locked bonus,
  moves their main wallet USDT balance into the locked bonus.

  1. Changes Made
    - Adds main wallet USDT balance to locked bonus current_amount
    - Sets main wallet USDT balance to 0
    
  2. Security
    - Only affects users with active KYC Verification Bonus
    - Preserves total value, just moves location
*/

DO $$
DECLARE
  rec RECORD;
  wallet_balance NUMERIC;
BEGIN
  FOR rec IN 
    SELECT 
      lb.id as bonus_id,
      lb.user_id,
      lb.current_amount as bonus_balance
    FROM locked_bonuses lb
    WHERE lb.bonus_type_name = 'KYC Verification Bonus'
      AND lb.status = 'active'
  LOOP
    SELECT COALESCE(w.balance, 0) INTO wallet_balance
    FROM wallets w
    WHERE w.user_id = rec.user_id
      AND w.currency = 'USDT'
      AND w.wallet_type = 'main';
    
    IF wallet_balance > 0 THEN
      UPDATE locked_bonuses
      SET current_amount = current_amount + wallet_balance,
          original_amount = original_amount + wallet_balance,
          updated_at = now()
      WHERE id = rec.bonus_id;
      
      UPDATE wallets
      SET balance = 0,
          updated_at = now()
      WHERE user_id = rec.user_id
        AND currency = 'USDT'
        AND wallet_type = 'main';
      
      RAISE NOTICE 'Moved % USDT from wallet to locked bonus for user %', wallet_balance, rec.user_id;
    END IF;
  END LOOP;
END $$;
