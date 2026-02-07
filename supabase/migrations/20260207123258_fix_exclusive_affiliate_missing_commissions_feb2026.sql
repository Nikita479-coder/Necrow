/*
  # Fix Missing Exclusive Affiliate Commissions (February 2026)

  ## Problem
  The deposit commission was calculated using the crypto amount (e.g., 0.20099 BNB)
  instead of the USD value (e.g., $125.95). This resulted in incorrect commissions.

  ## Affected Deposits
  1. David Baron's SOL deposit: 5.8 SOL = $495.79 USD
     - Joshua Robinson got $0.58, should be $49.58 (missing $49.00)
  
  2. Mario Paolillo's BNB deposit: 0.20099 BNB = $125.95 USD
     - Alfredo got $0.01, should be $6.30 (missing $6.29)
     - KenzyCrypto (tier 2) got $0.01, should be $5.04 (missing $5.03)

  ## Fix
  Credit the missing amounts to the exclusive affiliate balances and create
  correction records.
*/

DO $$
DECLARE
  -- Joshua Robinson (David Baron's referrer)
  v_joshua_id uuid := '52cc5e6a-8366-40e6-9def-da70f2b01aa1';
  v_joshua_missing numeric := 49.00;  -- $49.58 - $0.58
  
  -- Alfredo (Mario's referrer)
  v_alfredo_id uuid := '1565226d-b56a-4393-bc8d-d4cea46ced32';
  v_alfredo_missing numeric := 6.29;  -- $6.30 - $0.01
  
  -- KenzyCrypto (Mario's tier 2)
  v_kenzy_id uuid := '1bf2f09f-e19f-4241-96c8-facf3873d931';
  v_kenzy_missing numeric := 5.03;  -- $5.04 - $0.01
BEGIN
  -- 1. Credit Joshua Robinson
  UPDATE exclusive_affiliate_balances
  SET 
    available_balance = available_balance + v_joshua_missing,
    total_earned = total_earned + v_joshua_missing,
    deposit_commissions_earned = deposit_commissions_earned + v_joshua_missing,
    updated_at = now()
  WHERE user_id = v_joshua_id;
  
  -- Record correction commission
  INSERT INTO exclusive_affiliate_commissions (
    affiliate_id, source_user_id, tier_level, commission_type,
    source_amount, commission_rate, commission_amount,
    reference_id, reference_type, status
  ) VALUES (
    v_joshua_id,
    '23d92992-e061-46d2-9075-037cb27a1911',  -- David Baron
    1,
    'deposit',
    495.79,  -- Correct USD value
    10,
    v_joshua_missing,
    'd325b746-2976-4e34-956d-7972a4ee7f44'::uuid,
    'correction',
    'credited'
  );
  
  -- Update network stats
  UPDATE exclusive_affiliate_network_stats
  SET level_1_earnings = level_1_earnings + v_joshua_missing,
      updated_at = now()
  WHERE affiliate_id = v_joshua_id;
  
  -- Notification
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_joshua_id,
    'affiliate_payout',
    'Commission Correction',
    'A deposit commission correction of $' || v_joshua_missing || ' has been credited to your account.',
    false
  );
  
  RAISE NOTICE 'Joshua Robinson credited: $%', v_joshua_missing;

  -- 2. Credit Alfredo
  UPDATE exclusive_affiliate_balances
  SET 
    available_balance = available_balance + v_alfredo_missing,
    total_earned = total_earned + v_alfredo_missing,
    deposit_commissions_earned = deposit_commissions_earned + v_alfredo_missing,
    updated_at = now()
  WHERE user_id = v_alfredo_id;
  
  -- Record correction commission
  INSERT INTO exclusive_affiliate_commissions (
    affiliate_id, source_user_id, tier_level, commission_type,
    source_amount, commission_rate, commission_amount,
    reference_id, reference_type, status
  ) VALUES (
    v_alfredo_id,
    '59f70d1d-5236-44d0-a969-bebbdc738686',  -- Mario
    1,
    'deposit',
    125.95,  -- Correct USD value
    5,
    v_alfredo_missing,
    'e39ea916-ac0f-439d-812f-637cbad22d48'::uuid,
    'correction',
    'credited'
  );
  
  -- Update network stats
  UPDATE exclusive_affiliate_network_stats
  SET level_1_earnings = level_1_earnings + v_alfredo_missing,
      updated_at = now()
  WHERE affiliate_id = v_alfredo_id;
  
  -- Notification
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_alfredo_id,
    'affiliate_payout',
    'Commission Correction',
    'A deposit commission correction of $' || v_alfredo_missing || ' has been credited to your account.',
    false
  );
  
  RAISE NOTICE 'Alfredo credited: $%', v_alfredo_missing;

  -- 3. Credit KenzyCrypto
  UPDATE exclusive_affiliate_balances
  SET 
    available_balance = available_balance + v_kenzy_missing,
    total_earned = total_earned + v_kenzy_missing,
    deposit_commissions_earned = deposit_commissions_earned + v_kenzy_missing,
    updated_at = now()
  WHERE user_id = v_kenzy_id;
  
  -- Record correction commission
  INSERT INTO exclusive_affiliate_commissions (
    affiliate_id, source_user_id, tier_level, commission_type,
    source_amount, commission_rate, commission_amount,
    reference_id, reference_type, status
  ) VALUES (
    v_kenzy_id,
    '59f70d1d-5236-44d0-a969-bebbdc738686',  -- Mario
    2,
    'deposit',
    125.95,  -- Correct USD value
    4,
    v_kenzy_missing,
    'e39ea916-ac0f-439d-812f-637cbad22d48'::uuid,
    'correction',
    'credited'
  );
  
  -- Update network stats
  UPDATE exclusive_affiliate_network_stats
  SET level_2_earnings = level_2_earnings + v_kenzy_missing,
      updated_at = now()
  WHERE affiliate_id = v_kenzy_id;
  
  -- Notification
  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    v_kenzy_id,
    'affiliate_payout',
    'Commission Correction',
    'A deposit commission correction of $' || v_kenzy_missing || ' has been credited to your account.',
    false
  );
  
  RAISE NOTICE 'KenzyCrypto credited: $%', v_kenzy_missing;
  RAISE NOTICE 'All corrections applied successfully!';
END $$;
