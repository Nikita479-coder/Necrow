/*
  # Credit retroactive deposit commission for koliza64@gmail.com

  1. Context
    - reshadmollik604@gmail.com (level 1 referral of koliza64) received a manual $110 deposit
    - The automatic deposit commission was not triggered because it was a manual deposit
    - Level 1 deposit commission rate is 5%, so commission = $110 * 5% = $5.50

  2. Changes
    - Insert commission record into `exclusive_affiliate_commissions`
    - Update `exclusive_affiliate_balances`: available_balance +5.50, total_earned +5.50, deposit_commissions_earned +5.50
*/

DO $$
DECLARE
  v_affiliate_user_id uuid := '74d7f68f-44ca-4a5c-b535-32f3c7a16445';
  v_source_user_id uuid := '14f44038-2e15-4113-95cf-be0a20ba7e99';
  v_commission_amount numeric := 5.50;
BEGIN
  INSERT INTO exclusive_affiliate_commissions (
    affiliate_id,
    source_user_id,
    tier_level,
    commission_type,
    source_amount,
    commission_rate,
    commission_amount,
    base_commission_amount,
    reference_type,
    status,
    boost_multiplier,
    boost_tier
  ) VALUES (
    v_affiliate_user_id,
    v_source_user_id,
    1,
    'deposit',
    110.00,
    5,
    v_commission_amount,
    v_commission_amount,
    'deposit',
    'credited',
    1.00,
    'No boost'
  );

  UPDATE exclusive_affiliate_balances
  SET available_balance = available_balance + v_commission_amount,
      total_earned = total_earned + v_commission_amount,
      deposit_commissions_earned = deposit_commissions_earned + v_commission_amount,
      updated_at = now()
  WHERE user_id = v_affiliate_user_id;
END $$;
