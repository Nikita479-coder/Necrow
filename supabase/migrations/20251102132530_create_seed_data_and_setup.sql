/*
  # Create Seed Data and Helper Functions
  
  1. Helper Functions
    - Function to initialize default wallets for a user
    - Function to create mock trading account
    
  2. Note
    - Mock user must be created through Supabase Auth UI or signup flow
    - Credentials: demo@sharktrades.com / Demo123456!
*/

CREATE OR REPLACE FUNCTION initialize_user_wallets(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO wallets (user_id, currency, balance, locked_balance)
  VALUES
    (user_uuid, 'USDT', 10000.00, 0),
    (user_uuid, 'BTC', 0.5, 0),
    (user_uuid, 'ETH', 5.0, 0),
    (user_uuid, 'BNB', 10.0, 0)
  ON CONFLICT (user_id, currency) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION initialize_mock_trading(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO mock_trading_accounts (user_id, balance_usdt, total_pnl, win_rate, total_trades)
  VALUES (user_uuid, 100000.00, 5000.00, 65.5, 120)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION initialize_referral_stats(user_uuid uuid)
RETURNS void AS $$
BEGIN
  INSERT INTO referral_stats (user_id, vip_level, total_volume_30d, total_referrals, total_earnings)
  VALUES (user_uuid, 3, 50000.00, 5, 250.00)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;