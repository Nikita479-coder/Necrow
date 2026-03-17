/*
  # Remove Demo Data Setup - Start All Users at Zero

  1. Changes
    - Update wallet initialization to start with zero balances
    - Update mock trading to start at zero
    - Update referral stats to start at zero
    - Replace demo setup function to create clean accounts

  2. Note
    - All new users will start with no balances
    - Users must deposit to get started
    - Mock trading accounts start at zero
*/

-- Update initialize_user_wallets to start at zero
CREATE OR REPLACE FUNCTION initialize_user_wallets(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO wallets (user_id, currency, balance, locked_balance)
  VALUES
    (user_uuid, 'USDT', 0, 0),
    (user_uuid, 'BTC', 0, 0),
    (user_uuid, 'ETH', 0, 0),
    (user_uuid, 'BNB', 0, 0)
  ON CONFLICT (user_id, currency) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update initialize_mock_trading to start at zero
CREATE OR REPLACE FUNCTION initialize_mock_trading(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO mock_trading_accounts (user_id, balance_usdt, total_pnl, win_rate, total_trades)
  VALUES (user_uuid, 0, 0, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update initialize_referral_stats to start at zero
CREATE OR REPLACE FUNCTION initialize_referral_stats(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO referral_stats (user_id, vip_level, total_volume_30d, total_referrals, total_earnings)
  VALUES (user_uuid, 0, 0, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Replace setup_demo_user with clean account setup
CREATE OR REPLACE FUNCTION setup_demo_user(user_uuid uuid)
RETURNS void AS $$
BEGIN
  -- This function now just creates a clean account with zero balances
  -- Keeping the name for backwards compatibility but it no longer adds demo data
  
  -- Initialize basic wallets with zero balance
  PERFORM initialize_user_wallets(user_uuid);
  
  -- Initialize mock trading account with zero
  PERFORM initialize_mock_trading(user_uuid);
  
  -- Initialize referral stats at zero
  PERFORM initialize_referral_stats(user_uuid);
  
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remove auto_setup_new_user trigger if it exists
DROP TRIGGER IF EXISTS auto_setup_user_data ON auth.users;

-- Update auto_setup_new_user function to not add any demo data
CREATE OR REPLACE FUNCTION auto_setup_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Just return without setting up demo data
  -- Profile creation is handled by the handle_new_user trigger
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
