/*
  # Add Tier 2 Deposit Commissions for New Referrals
  
  1. Summary
    - Creates exclusive affiliate deposit commissions for Michael Rodriguez and Sarah Chen
    - Both are tier 2 referrals with 9% deposit commission rate
    - Updates cryptowisejr's exclusive affiliate balances and network stats
    
  2. Commissions
    - Michael Rodriguez: $100 * 9% = $9.00
    - Sarah Chen: $50 * 9% = $4.50
    - Total: $13.50
*/

-- Insert tier 2 deposit commissions for Michael Rodriguez
INSERT INTO exclusive_affiliate_commissions (
  affiliate_id,
  source_user_id,
  tier_level,
  commission_type,
  source_amount,
  commission_rate,
  commission_amount,
  reference_id,
  reference_type,
  status
) VALUES (
  '52cc5e6a-8366-40e6-9def-da70f2b01aa1',  -- cryptowisejr
  '845b3598-aaa5-462c-93b4-eea8ddfd419c',  -- Michael Rodriguez
  2,                                        -- Tier 2
  'deposit',
  100,
  9,                                        -- 9% for tier 2
  9.00,
  '2df41f48-cece-494a-aae6-5c3b55b76f14',  -- deposit payment_id
  'deposit',
  'credited'
);

-- Insert tier 2 deposit commissions for Sarah Chen
INSERT INTO exclusive_affiliate_commissions (
  affiliate_id,
  source_user_id,
  tier_level,
  commission_type,
  source_amount,
  commission_rate,
  commission_amount,
  reference_id,
  reference_type,
  status
) VALUES (
  '52cc5e6a-8366-40e6-9def-da70f2b01aa1',  -- cryptowisejr
  'a80c975f-b716-4273-a699-79ee6bfc590b',  -- Sarah Chen
  2,                                        -- Tier 2
  'deposit',
  50,
  9,                                        -- 9% for tier 2
  4.50,
  '2522844a-f63f-4a21-9987-62bc6370f03f',  -- deposit payment_id
  'deposit',
  'credited'
);

-- Update exclusive affiliate balances
UPDATE exclusive_affiliate_balances
SET 
  available_balance = available_balance + 13.50,
  total_earned = total_earned + 13.50,
  deposit_commissions_earned = deposit_commissions_earned + 13.50,
  updated_at = now()
WHERE user_id = '52cc5e6a-8366-40e6-9def-da70f2b01aa1';

-- Update exclusive affiliate network stats
UPDATE exclusive_affiliate_network_stats
SET 
  level_2_earnings = level_2_earnings + 13.50,
  this_month_earnings = this_month_earnings + 13.50,
  updated_at = now()
WHERE affiliate_id = '52cc5e6a-8366-40e6-9def-da70f2b01aa1';

-- Create notifications for the commissions
INSERT INTO notifications (user_id, type, title, message, read)
VALUES 
  (
    '52cc5e6a-8366-40e6-9def-da70f2b01aa1',
    'affiliate_payout',
    'Deposit Commission Received',
    'You earned $9.00 (Level 2 - 9%) from a deposit in your network.',
    false
  ),
  (
    '52cc5e6a-8366-40e6-9def-da70f2b01aa1',
    'affiliate_payout',
    'Deposit Commission Received',
    'You earned $4.50 (Level 2 - 9%) from a deposit in your network.',
    false
  );
