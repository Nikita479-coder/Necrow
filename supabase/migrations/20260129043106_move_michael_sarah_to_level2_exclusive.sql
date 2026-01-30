/*
  # Move Michael and Sarah to Level 2 in Exclusive Affiliate Network
  
  1. Summary
    - Updates Michael Rodriguez and Sarah Chen to appear as Level 2 referrals
    - Moves their deposit commissions from Level 1 to Level 2
    - Updates cryptowisejr's exclusive affiliate stats accordingly
    
  2. Changes
    - Update exclusive_affiliate_commissions tier_level from 1 to 2
    - Adjust network stats: L1: 10→8, L2: 0→2
    - Move earnings from level_1_earnings to level_2_earnings
*/

-- Update the commission records to Level 2
UPDATE exclusive_affiliate_commissions
SET tier_level = 2
WHERE affiliate_id = '52cc5e6a-8366-40e6-9def-da70f2b01aa1'
  AND source_user_id IN (
    '845b3598-aaa5-462c-93b4-eea8ddfd419c',  -- Michael Rodriguez
    'a80c975f-b716-4273-a699-79ee6bfc590b'   -- Sarah Chen
  )
  AND commission_type = 'deposit';

-- Calculate the amount to move from L1 to L2
DO $$
DECLARE
  v_commission_total numeric;
BEGIN
  -- Get total commissions from Michael and Sarah
  SELECT COALESCE(SUM(commission_amount), 0)
  INTO v_commission_total
  FROM exclusive_affiliate_commissions
  WHERE affiliate_id = '52cc5e6a-8366-40e6-9def-da70f2b01aa1'
    AND source_user_id IN (
      '845b3598-aaa5-462c-93b4-eea8ddfd419c',
      'a80c975f-b716-4273-a699-79ee6bfc590b'
    )
    AND commission_type = 'deposit'
    AND tier_level = 2;

  -- Update the network stats
  UPDATE exclusive_affiliate_network_stats
  SET 
    level_1_count = level_1_count - 2,  -- Remove 2 from Level 1
    level_2_count = level_2_count + 2,  -- Add 2 to Level 2
    level_1_earnings = level_1_earnings - v_commission_total,  -- Remove earnings from L1
    level_2_earnings = level_2_earnings + v_commission_total,  -- Add earnings to L2
    updated_at = now()
  WHERE affiliate_id = '52cc5e6a-8366-40e6-9def-da70f2b01aa1';
END $$;
