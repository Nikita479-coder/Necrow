/*
  # Clean Fake Referral Data and Add Monthly Earnings Column
  
  1. Changes
    - Delete all fake referral_stats entries where user has no actual referrals
    - Add this_month_earnings column to referral_stats table
    - Reset all stats to 0 for users with no actual referrals
  
  2. Why
    - Seed data created fake referral stats
    - Users see incorrect earnings and referral counts
    - Need accurate, real data only
*/

-- Add this_month_earnings column if it doesn't exist
ALTER TABLE referral_stats 
ADD COLUMN IF NOT EXISTS this_month_earnings numeric(20, 8) DEFAULT 0 NOT NULL;

-- Delete referral_stats entries for users who don't actually have any referrals
DELETE FROM referral_stats
WHERE user_id IN (
  SELECT rs.user_id
  FROM referral_stats rs
  LEFT JOIN user_profiles up ON up.referred_by = rs.user_id
  WHERE up.id IS NULL
);

-- Also clean up any referral_commissions that don't have valid referrals
DELETE FROM referral_commissions
WHERE referrer_id NOT IN (
  SELECT DISTINCT referred_by 
  FROM user_profiles 
  WHERE referred_by IS NOT NULL
);

-- Clean up any referral_rebates for users who weren't actually referred
DELETE FROM referral_rebates
WHERE user_id NOT IN (
  SELECT id 
  FROM user_profiles 
  WHERE referred_by IS NOT NULL
);
