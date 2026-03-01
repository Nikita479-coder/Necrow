/*
  # Restore Denis's Missing $100 in Copy Wallet

  1. Problem
    - User denissimion555@yahoo.com (dc0c3270-db1c-4d55-8cb9-27f8675edd74)
    - Transfer of $100 on 2026-02-28 19:55:52 debited main wallet but did NOT credit copy wallet
    - Main wallet shows $0 (correctly debited), copy wallet shows $82.88 (should be $182.88)

  2. Fix
    - Credit copy wallet with the missing $100
    - Update copy relationship initial_balance from $100 to $200
    - Update copy relationship current_balance by adding $100

  3. Verification
    - Expected copy wallet after fix: ~$182.88
    - Expected relationship initial_balance: $200
*/

-- Step 1: Credit the missing $100 to Denis's copy wallet
UPDATE wallets
SET balance = balance + 100.00,
    updated_at = now()
WHERE user_id = 'dc0c3270-db1c-4d55-8cb9-27f8675edd74'
  AND wallet_type = 'copy'
  AND currency = 'USDT';

-- Step 2: Update the copy relationship to include the additional $100
UPDATE copy_relationships
SET initial_balance = initial_balance + 100.00,
    current_balance = current_balance + 100.00,
    updated_at = now()
WHERE id = 'dcb55341-37ab-4ce1-9f60-ac9b36d9a7e4'
  AND follower_id = 'dc0c3270-db1c-4d55-8cb9-27f8675edd74';
