/*
  # Auto-Create Wallets on User Signup

  ## Summary
  This migration ensures that every new user automatically gets essential
  wallets created when they register. This includes main wallets for USDT
  and other major cryptocurrencies, so admins can add balance without
  having to manually create wallets first.

  ## Changes Made

  ### 1. Update create_user_profile() Trigger Function
  - Modified to also create essential wallets for new users
  - Creates main wallet type for primary currencies
  - Creates futures margin wallet

  ### 2. Wallets Created on Signup
  - USDT (main wallet) - Primary trading currency
  - BTC, ETH, BNB, SOL, USDC (main wallets) - Major cryptocurrencies
  - Futures margin wallet - For futures trading

  ### 3. Retroactive Fix
  - Also ensures all existing users have these wallets

  ## Security
  - All existing RLS policies remain in effect
  - Wallets created through secure trigger function
*/

-- Drop the existing trigger first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Replace the create_user_profile function to also create wallets
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referral_code text;
BEGIN
  -- Generate unique referral code
  v_referral_code := generate_referral_code();

  -- Create user profile
  INSERT INTO user_profiles (id, referral_code)
  VALUES (NEW.id, v_referral_code);

  -- Create main wallets for essential currencies
  INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, total_deposited, total_withdrawn)
  VALUES
    -- USDT - Primary trading currency
    (NEW.id, 'USDT', 'main', 0, 0, 0, 0),
    -- Major cryptocurrencies
    (NEW.id, 'BTC', 'main', 0, 0, 0, 0),
    (NEW.id, 'ETH', 'main', 0, 0, 0, 0),
    (NEW.id, 'BNB', 'main', 0, 0, 0, 0),
    (NEW.id, 'SOL', 'main', 0, 0, 0, 0),
    (NEW.id, 'USDC', 'main', 0, 0, 0, 0)
  ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

  -- Create futures margin wallet
  INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
  VALUES (NEW.id, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  -- Initialize referral stats
  INSERT INTO referral_stats (
    user_id,
    vip_level,
    total_volume_30d,
    total_referrals,
    total_earnings,
    this_month_earnings,
    total_volume_all_time,
    lifetime_earnings,
    cpa_earnings,
    pending_payout,
    tier_2_referrals,
    tier_3_referrals,
    tier_4_referrals,
    tier_5_referrals,
    tier_2_earnings,
    tier_3_earnings,
    tier_4_earnings,
    tier_5_earnings
  )
  VALUES (
    NEW.id,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();

-- Ensure all existing users have essential wallets (retroactive fix)
-- Create main wallets for existing users who don't have them
INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance, total_deposited, total_withdrawn)
SELECT
  u.id,
  c.currency,
  'main',
  0,
  0,
  0,
  0
FROM auth.users u
CROSS JOIN (
  SELECT 'USDT' as currency
  UNION ALL SELECT 'BTC'
  UNION ALL SELECT 'ETH'
  UNION ALL SELECT 'BNB'
  UNION ALL SELECT 'SOL'
  UNION ALL SELECT 'USDC'
) c
WHERE NOT EXISTS (
  SELECT 1 FROM wallets w
  WHERE w.user_id = u.id
    AND w.currency = c.currency
    AND w.wallet_type = 'main'
)
ON CONFLICT (user_id, currency, wallet_type) DO NOTHING;

-- Ensure all existing users have futures margin wallets
INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
SELECT
  u.id,
  0,
  0
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM futures_margin_wallets fw
  WHERE fw.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;

-- Ensure all existing users have referral stats
INSERT INTO referral_stats (
  user_id,
  vip_level,
  total_volume_30d,
  total_referrals,
  total_earnings,
  this_month_earnings,
  total_volume_all_time,
  lifetime_earnings,
  cpa_earnings,
  pending_payout,
  tier_2_referrals,
  tier_3_referrals,
  tier_4_referrals,
  tier_5_referrals,
  tier_2_earnings,
  tier_3_earnings,
  tier_4_earnings,
  tier_5_earnings
)
SELECT
  u.id,
  1,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM referral_stats rs
  WHERE rs.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;
