/*
  # Add Exclusive Affiliate Test Data for cryptowisejr

  1. Purpose
    - Add 6 new level 1 referrals for cryptowisejr@gmail.com
    - Add 10 level 2 referrals under the new level 1 users
    - Create 3 deposit transactions with commissions
    - Update affiliate balances and network statistics
    - Create commission notifications

  2. New Level 1 Users (6 users)
    - Sarah Williams, Marcus Chen, Emily Rodriguez
    - James Thompson, Olivia Bennett, Daniel Park

  3. New Level 2 Users (10 users distributed across level 1)
    - Under Sarah: Alex Turner, Nina Patel
    - Under Marcus: Ryan Foster, Jessica Kim
    - Under Emily: Brandon Lee, Michelle Davis
    - Under James: Kevin Wright, Samantha Moore
    - Under Olivia: Tyler Johnson
    - Under Daniel: Amanda Garcia

  4. Deposits and Commissions
    - Marcus Chen: $100 deposit (yesterday) -> $10 L1 commission
    - Ryan Foster: $100 deposit (today) -> $9 L2 commission
    - Brandon Lee: $100 deposit (today) -> $9 L2 commission
    - Total new earnings: $28

  5. Tables Updated
    - auth.users (16 new users)
    - user_profiles (16 new profiles)
    - wallets (3 depositors + cryptowisejr main wallet)
    - transactions (deposits and commissions)
    - exclusive_affiliate_commissions
    - exclusive_affiliate_balances
    - exclusive_affiliate_network_stats
    - notifications (3 commission notifications)
*/

DO $$
DECLARE
  v_cryptowisejr_id uuid := '52cc5e6a-8366-40e6-9def-da70f2b01aa1';
  
  -- Level 1 user IDs
  v_sarah_id uuid := gen_random_uuid();
  v_marcus_id uuid := gen_random_uuid();
  v_emily_id uuid := gen_random_uuid();
  v_james_id uuid := gen_random_uuid();
  v_olivia_id uuid := gen_random_uuid();
  v_daniel_id uuid := gen_random_uuid();
  
  -- Level 2 user IDs
  v_alex_id uuid := gen_random_uuid();
  v_nina_id uuid := gen_random_uuid();
  v_ryan_id uuid := gen_random_uuid();
  v_jessica_id uuid := gen_random_uuid();
  v_brandon_id uuid := gen_random_uuid();
  v_michelle_id uuid := gen_random_uuid();
  v_kevin_id uuid := gen_random_uuid();
  v_samantha_id uuid := gen_random_uuid();
  v_tyler_id uuid := gen_random_uuid();
  v_amanda_id uuid := gen_random_uuid();
  
  -- Wallet IDs
  v_marcus_wallet_id uuid := gen_random_uuid();
  v_ryan_wallet_id uuid := gen_random_uuid();
  v_brandon_wallet_id uuid := gen_random_uuid();
  v_cryptowisejr_wallet_id uuid;
  
  -- Transaction IDs
  v_marcus_deposit_id uuid := gen_random_uuid();
  v_ryan_deposit_id uuid := gen_random_uuid();
  v_brandon_deposit_id uuid := gen_random_uuid();
  
  -- Timestamps
  v_yesterday timestamp with time zone := now() - interval '1 day';
  v_today_morning timestamp with time zone := now() - interval '6 hours';
  v_today_afternoon timestamp with time zone := now() - interval '2 hours';
  
BEGIN
  -- ============================================
  -- STEP 1: Create Level 1 Users in auth.users
  -- ============================================
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    (v_sarah_id, 'sarah.williams@outlook.com', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday - interval '5 days', now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Sarah Williams"}'::jsonb),
    (v_marcus_id, 'marcus.chen@gmail.com', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday - interval '4 days', now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Marcus Chen"}'::jsonb),
    (v_emily_id, 'emily.rodriguez@yahoo.com', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday - interval '3 days', now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Emily Rodriguez"}'::jsonb),
    (v_james_id, 'james.thompson@proton.me', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday - interval '2 days', now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"James Thompson"}'::jsonb),
    (v_olivia_id, 'olivia.bennett@icloud.com', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday - interval '1 day', now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Olivia Bennett"}'::jsonb),
    (v_daniel_id, 'daniel.park@gmail.com', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Daniel Park"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  -- ============================================
  -- STEP 2: Create Level 2 Users in auth.users
  -- ============================================
  
  INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
  VALUES
    -- Under Sarah
    (v_alex_id, 'alex.turner@gmail.com', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Alex Turner"}'::jsonb),
    (v_nina_id, 'nina.patel@outlook.com', crypt('TestPass123!', gen_salt('bf')), now(), v_yesterday, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Nina Patel"}'::jsonb),
    -- Under Marcus
    (v_ryan_id, 'ryan.foster@gmail.com', crypt('TestPass123!', gen_salt('bf')), now(), v_today_morning - interval '2 hours', now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Ryan Foster"}'::jsonb),
    (v_jessica_id, 'jessica.kim@yahoo.com', crypt('TestPass123!', gen_salt('bf')), now(), v_today_morning, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Jessica Kim"}'::jsonb),
    -- Under Emily
    (v_brandon_id, 'brandon.lee@proton.me', crypt('TestPass123!', gen_salt('bf')), now(), v_today_morning, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Brandon Lee"}'::jsonb),
    (v_michelle_id, 'michelle.davis@gmail.com', crypt('TestPass123!', gen_salt('bf')), now(), v_today_afternoon, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Michelle Davis"}'::jsonb),
    -- Under James
    (v_kevin_id, 'kevin.wright@icloud.com', crypt('TestPass123!', gen_salt('bf')), now(), v_today_afternoon, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Kevin Wright"}'::jsonb),
    (v_samantha_id, 'samantha.moore@outlook.com', crypt('TestPass123!', gen_salt('bf')), now(), v_today_afternoon, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Samantha Moore"}'::jsonb),
    -- Under Olivia
    (v_tyler_id, 'tyler.johnson@gmail.com', crypt('TestPass123!', gen_salt('bf')), now(), v_today_afternoon, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Tyler Johnson"}'::jsonb),
    -- Under Daniel
    (v_amanda_id, 'amanda.garcia@yahoo.com', crypt('TestPass123!', gen_salt('bf')), now(), v_today_afternoon, now(), '{"provider":"email","providers":["email"]}'::jsonb, '{"full_name":"Amanda Garcia"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  -- ============================================
  -- STEP 3: Create Level 1 User Profiles
  -- ============================================
  
  INSERT INTO user_profiles (id, full_name, referred_by, referral_code, created_at)
  VALUES
    (v_sarah_id, 'Sarah Williams', v_cryptowisejr_id, 'SARAH' || substring(v_sarah_id::text from 1 for 6), v_yesterday - interval '5 days'),
    (v_marcus_id, 'Marcus Chen', v_cryptowisejr_id, 'MARCUS' || substring(v_marcus_id::text from 1 for 6), v_yesterday - interval '4 days'),
    (v_emily_id, 'Emily Rodriguez', v_cryptowisejr_id, 'EMILY' || substring(v_emily_id::text from 1 for 6), v_yesterday - interval '3 days'),
    (v_james_id, 'James Thompson', v_cryptowisejr_id, 'JAMES' || substring(v_james_id::text from 1 for 6), v_yesterday - interval '2 days'),
    (v_olivia_id, 'Olivia Bennett', v_cryptowisejr_id, 'OLIVIA' || substring(v_olivia_id::text from 1 for 6), v_yesterday - interval '1 day'),
    (v_daniel_id, 'Daniel Park', v_cryptowisejr_id, 'DANIEL' || substring(v_daniel_id::text from 1 for 6), v_yesterday)
  ON CONFLICT (id) DO UPDATE SET referred_by = EXCLUDED.referred_by;

  -- ============================================
  -- STEP 4: Create Level 2 User Profiles
  -- ============================================
  
  INSERT INTO user_profiles (id, full_name, referred_by, referral_code, created_at)
  VALUES
    -- Under Sarah
    (v_alex_id, 'Alex Turner', v_sarah_id, 'ALEX' || substring(v_alex_id::text from 1 for 6), v_yesterday),
    (v_nina_id, 'Nina Patel', v_sarah_id, 'NINA' || substring(v_nina_id::text from 1 for 6), v_yesterday),
    -- Under Marcus
    (v_ryan_id, 'Ryan Foster', v_marcus_id, 'RYAN' || substring(v_ryan_id::text from 1 for 6), v_today_morning - interval '2 hours'),
    (v_jessica_id, 'Jessica Kim', v_marcus_id, 'JESSICA' || substring(v_jessica_id::text from 1 for 6), v_today_morning),
    -- Under Emily
    (v_brandon_id, 'Brandon Lee', v_emily_id, 'BRANDON' || substring(v_brandon_id::text from 1 for 6), v_today_morning),
    (v_michelle_id, 'Michelle Davis', v_emily_id, 'MICHELLE' || substring(v_michelle_id::text from 1 for 6), v_today_afternoon),
    -- Under James
    (v_kevin_id, 'Kevin Wright', v_james_id, 'KEVIN' || substring(v_kevin_id::text from 1 for 6), v_today_afternoon),
    (v_samantha_id, 'Samantha Moore', v_james_id, 'SAMANTHA' || substring(v_samantha_id::text from 1 for 6), v_today_afternoon),
    -- Under Olivia
    (v_tyler_id, 'Tyler Johnson', v_olivia_id, 'TYLER' || substring(v_tyler_id::text from 1 for 6), v_today_afternoon),
    -- Under Daniel
    (v_amanda_id, 'Amanda Garcia', v_daniel_id, 'AMANDA' || substring(v_amanda_id::text from 1 for 6), v_today_afternoon)
  ON CONFLICT (id) DO UPDATE SET referred_by = EXCLUDED.referred_by;

  -- ============================================
  -- STEP 5: Create Wallets for Depositors
  -- ============================================
  
  INSERT INTO wallets (id, user_id, currency, wallet_type, balance, total_deposited, created_at)
  VALUES
    (v_marcus_wallet_id, v_marcus_id, 'USDT', 'main', 100, 100, v_yesterday),
    (v_ryan_wallet_id, v_ryan_id, 'USDT', 'main', 100, 100, v_today_morning),
    (v_brandon_wallet_id, v_brandon_id, 'USDT', 'main', 100, 100, v_today_afternoon)
  ON CONFLICT (user_id, currency, wallet_type) DO UPDATE SET 
    balance = wallets.balance + 100,
    total_deposited = wallets.total_deposited + 100;

  -- ============================================
  -- STEP 6: Create Deposit Transactions
  -- ============================================
  
  INSERT INTO transactions (id, user_id, transaction_type, amount, currency, status, created_at, details)
  VALUES
    (v_marcus_deposit_id, v_marcus_id, 'deposit', 100, 'USDT', 'completed', v_yesterday, '{"source": "test_data", "payment_method": "crypto"}'::jsonb),
    (v_ryan_deposit_id, v_ryan_id, 'deposit', 100, 'USDT', 'completed', v_today_morning, '{"source": "test_data", "payment_method": "crypto"}'::jsonb),
    (v_brandon_deposit_id, v_brandon_id, 'deposit', 100, 'USDT', 'completed', v_today_afternoon, '{"source": "test_data", "payment_method": "crypto"}'::jsonb)
  ON CONFLICT (id) DO NOTHING;

  -- ============================================
  -- STEP 7: Create Affiliate Commission Transactions
  -- ============================================
  
  INSERT INTO transactions (user_id, transaction_type, amount, currency, status, created_at, details)
  VALUES
    (v_cryptowisejr_id, 'affiliate_commission', 10.00, 'USDT', 'completed', v_yesterday + interval '1 minute', 
      jsonb_build_object('type', 'deposit_commission', 'depositor_id', v_marcus_id, 'deposit_id', v_marcus_deposit_id, 'deposit_amount', 100, 'tier_level', 1, 'commission_rate', 10)),
    (v_cryptowisejr_id, 'affiliate_commission', 9.00, 'USDT', 'completed', v_today_morning + interval '1 minute', 
      jsonb_build_object('type', 'deposit_commission', 'depositor_id', v_ryan_id, 'deposit_id', v_ryan_deposit_id, 'deposit_amount', 100, 'tier_level', 2, 'commission_rate', 9)),
    (v_cryptowisejr_id, 'affiliate_commission', 9.00, 'USDT', 'completed', v_today_afternoon + interval '1 minute', 
      jsonb_build_object('type', 'deposit_commission', 'depositor_id', v_brandon_id, 'deposit_id', v_brandon_deposit_id, 'deposit_amount', 100, 'tier_level', 2, 'commission_rate', 9));

  -- ============================================
  -- STEP 8: Record Exclusive Affiliate Commissions
  -- ============================================
  
  INSERT INTO exclusive_affiliate_commissions (affiliate_id, source_user_id, commission_type, tier_level, source_amount, commission_rate, commission_amount, reference_type, reference_id, status, created_at)
  VALUES
    (v_cryptowisejr_id, v_marcus_id, 'deposit', 1, 100.00, 10.00, 10.00, 'deposit', v_marcus_deposit_id, 'credited', v_yesterday + interval '1 minute'),
    (v_cryptowisejr_id, v_ryan_id, 'deposit', 2, 100.00, 9.00, 9.00, 'deposit', v_ryan_deposit_id, 'credited', v_today_morning + interval '1 minute'),
    (v_cryptowisejr_id, v_brandon_id, 'deposit', 2, 100.00, 9.00, 9.00, 'deposit', v_brandon_deposit_id, 'credited', v_today_afternoon + interval '1 minute');

  -- ============================================
  -- STEP 9: Update Exclusive Affiliate Balances
  -- ============================================
  
  UPDATE exclusive_affiliate_balances
  SET 
    available_balance = available_balance + 28.00,
    total_earned = total_earned + 28.00,
    deposit_commissions_earned = deposit_commissions_earned + 28.00,
    updated_at = now()
  WHERE user_id = v_cryptowisejr_id;

  -- ============================================
  -- STEP 10: Update Network Statistics
  -- ============================================
  
  UPDATE exclusive_affiliate_network_stats
  SET 
    level_1_count = level_1_count + 6,
    level_2_count = level_2_count + 10,
    level_1_earnings = level_1_earnings + 10.00,
    level_2_earnings = level_2_earnings + 18.00,
    this_month_earnings = this_month_earnings + 28.00,
    updated_at = now()
  WHERE affiliate_id = v_cryptowisejr_id;

  -- ============================================
  -- STEP 11: Get or Create cryptowisejr's Main Wallet
  -- ============================================
  
  SELECT id INTO v_cryptowisejr_wallet_id
  FROM wallets
  WHERE user_id = v_cryptowisejr_id
  AND currency = 'USDT'
  AND wallet_type = 'main';
  
  IF v_cryptowisejr_wallet_id IS NOT NULL THEN
    UPDATE wallets
    SET balance = balance + 28.00,
        updated_at = now()
    WHERE id = v_cryptowisejr_wallet_id;
  ELSE
    INSERT INTO wallets (user_id, currency, wallet_type, balance)
    VALUES (v_cryptowisejr_id, 'USDT', 'main', 28.00);
  END IF;

  -- ============================================
  -- STEP 12: Create Commission Notifications
  -- ============================================
  
  INSERT INTO notifications (user_id, type, title, message, read, created_at)
  VALUES
    (v_cryptowisejr_id, 'affiliate_payout', 'Deposit Commission Received', 'You earned $10.00 (Level 1 - 10%) from a deposit in your network.', false, v_yesterday + interval '1 minute'),
    (v_cryptowisejr_id, 'affiliate_payout', 'Deposit Commission Received', 'You earned $9.00 (Level 2 - 9%) from a deposit in your network.', false, v_today_morning + interval '1 minute'),
    (v_cryptowisejr_id, 'affiliate_payout', 'Deposit Commission Received', 'You earned $9.00 (Level 2 - 9%) from a deposit in your network.', false, v_today_afternoon + interval '1 minute');

  -- ============================================
  -- STEP 13: Update Referral Stats for Level 1 Users
  -- ============================================
  
  INSERT INTO referral_stats (user_id, total_referrals, total_earnings)
  VALUES
    (v_sarah_id, 2, 0),
    (v_marcus_id, 2, 0),
    (v_emily_id, 2, 0),
    (v_james_id, 2, 0),
    (v_olivia_id, 1, 0),
    (v_daniel_id, 1, 0)
  ON CONFLICT (user_id) DO UPDATE SET 
    total_referrals = referral_stats.total_referrals + EXCLUDED.total_referrals;

END $$;
