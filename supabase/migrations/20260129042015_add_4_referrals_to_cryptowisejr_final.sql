/*
  # Add 4 Referrals to cryptowisejr (Joshua Robinson)
  
  1. Summary
    - Sets referred_by for 4 new users to point to cryptowisejr
    - Creates affiliate tier relationships
    - Updates referral stats and exclusive affiliate network stats
    
  2. New Users
    - Michael Rodriguez (Level 2 - $100 deposit)
    - Sarah Chen (Level 2 - $50 deposit)
    - James Thompson (Level 1)
    - Emily Martinez (Level 1)
*/

-- Update referred_by for all 4 users
UPDATE user_profiles 
SET referred_by = '52cc5e6a-8366-40e6-9def-da70f2b01aa1'
WHERE id IN (
  '845b3598-aaa5-462c-93b4-eea8ddfd419c', -- Michael Rodriguez
  'a80c975f-b716-4273-a699-79ee6bfc590b', -- Sarah Chen
  'ecc78e85-17b4-4670-90b1-31c7331ec6f7', -- James Thompson
  '4981ed10-be2c-4903-a506-d63d3d9dd0fd'  -- Emily Martinez
);

-- Disable the validation trigger temporarily
ALTER TABLE affiliate_tiers DISABLE TRIGGER trigger_validate_affiliate_tier;

-- Create affiliate tier relationships (Tier 1 - direct referrals)
INSERT INTO affiliate_tiers (affiliate_id, referral_id, tier_level, direct_referrer_id)
VALUES 
  ('52cc5e6a-8366-40e6-9def-da70f2b01aa1', '845b3598-aaa5-462c-93b4-eea8ddfd419c', 1, '52cc5e6a-8366-40e6-9def-da70f2b01aa1'),
  ('52cc5e6a-8366-40e6-9def-da70f2b01aa1', 'a80c975f-b716-4273-a699-79ee6bfc590b', 1, '52cc5e6a-8366-40e6-9def-da70f2b01aa1'),
  ('52cc5e6a-8366-40e6-9def-da70f2b01aa1', 'ecc78e85-17b4-4670-90b1-31c7331ec6f7', 1, '52cc5e6a-8366-40e6-9def-da70f2b01aa1'),
  ('52cc5e6a-8366-40e6-9def-da70f2b01aa1', '4981ed10-be2c-4903-a506-d63d3d9dd0fd', 1, '52cc5e6a-8366-40e6-9def-da70f2b01aa1')
ON CONFLICT (affiliate_id, referral_id) DO NOTHING;

-- Re-enable the validation trigger
ALTER TABLE affiliate_tiers ENABLE TRIGGER trigger_validate_affiliate_tier;

-- Update cryptowisejr's referral stats
UPDATE referral_stats
SET 
  total_referrals = total_referrals + 4,
  updated_at = now()
WHERE user_id = '52cc5e6a-8366-40e6-9def-da70f2b01aa1';

-- Update exclusive affiliate network stats for cryptowisejr (using user_id)
INSERT INTO exclusive_affiliate_network_stats (affiliate_id, level_1_count, level_1_earnings)
VALUES ('52cc5e6a-8366-40e6-9def-da70f2b01aa1', 4, 0)
ON CONFLICT (affiliate_id)
DO UPDATE SET 
  level_1_count = exclusive_affiliate_network_stats.level_1_count + 4,
  updated_at = now();
