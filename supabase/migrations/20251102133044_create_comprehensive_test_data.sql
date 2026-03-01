/*
  # Create Test Data Setup Function
  
  This migration creates a function that will populate test data
  for any user, making it easy to set up demo accounts.
  
  Usage: After creating a user through signup, run:
  SELECT setup_demo_user(auth.uid());
*/

CREATE OR REPLACE FUNCTION setup_demo_user(user_uuid uuid)
RETURNS void AS $$
BEGIN
  -- Update user profile with demo data
  UPDATE user_profiles 
  SET 
    username = 'SharkTrader',
    full_name = 'Demo User',
    country = 'US',
    kyc_status = 'verified',
    kyc_level = 2
  WHERE id = user_uuid;

  -- Initialize wallets with substantial balances
  INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited)
  VALUES
    (user_uuid, 'USDT', 50000.00, 5000.00, 50000.00),
    (user_uuid, 'BTC', 1.25, 0.25, 1.5),
    (user_uuid, 'ETH', 15.0, 2.0, 17.0),
    (user_uuid, 'BNB', 50.0, 5.0, 55.0),
    (user_uuid, 'SOL', 100.0, 10.0, 110.0),
    (user_uuid, 'XRP', 5000.0, 500.0, 5500.0),
    (user_uuid, 'ADA', 3000.0, 300.0, 3300.0),
    (user_uuid, 'DOGE', 10000.0, 1000.0, 11000.0)
  ON CONFLICT (user_id, currency) DO UPDATE
  SET 
    balance = EXCLUDED.balance,
    locked_balance = EXCLUDED.locked_balance,
    total_deposited = EXCLUDED.total_deposited;

  -- Create deposit addresses
  INSERT INTO wallet_addresses (user_id, currency, address, network)
  VALUES
    (user_uuid, 'BTC', '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa', 'Bitcoin'),
    (user_uuid, 'ETH', '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb', 'ERC20'),
    (user_uuid, 'USDT', '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb', 'ERC20'),
    (user_uuid, 'USDT', 'TLPfGvWr4K8wd2SvqAx3RJWQ5Qx8LPkjQN', 'TRC20'),
    (user_uuid, 'BNB', '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb', 'BEP20')
  ON CONFLICT (user_id, currency, network) DO NOTHING;

  -- Create mock trading account
  INSERT INTO mock_trading_accounts (user_id, balance_usdt, total_pnl, win_rate, total_trades)
  VALUES (user_uuid, 100000.00, 15750.50, 68.5, 247)
  ON CONFLICT (user_id) DO UPDATE
  SET 
    balance_usdt = EXCLUDED.balance_usdt,
    total_pnl = EXCLUDED.total_pnl,
    win_rate = EXCLUDED.win_rate,
    total_trades = EXCLUDED.total_trades;

  -- Create referral stats
  INSERT INTO referral_stats (user_id, vip_level, total_volume_30d, total_referrals, total_earnings)
  VALUES (user_uuid, 4, 125000.00, 12, 850.00)
  ON CONFLICT (user_id) DO UPDATE
  SET 
    vip_level = EXCLUDED.vip_level,
    total_volume_30d = EXCLUDED.total_volume_30d,
    total_referrals = EXCLUDED.total_referrals,
    total_earnings = EXCLUDED.total_earnings;

  -- Create some sample open orders
  INSERT INTO orders (user_id, order_type, side, pair, price, quantity, filled_quantity, order_kind, status, leverage)
  VALUES
    (user_uuid, 'futures', 'long', 'BTC/USDT', 68500.00, 0.1, 0, 'limit', 'pending', 10),
    (user_uuid, 'spot', 'buy', 'ETH/USDT', 3200.00, 2.0, 0, 'limit', 'pending', 1),
    (user_uuid, 'futures', 'short', 'BNB/USDT', 590.00, 5.0, 0, 'limit', 'pending', 5);

  -- Create some sample positions
  INSERT INTO positions (user_id, pair, side, entry_price, quantity, leverage, margin, unrealized_pnl, liquidation_price)
  VALUES
    (user_uuid, 'BTC/USDT', 'long', 67000.00, 0.5, 10, 3350.00, 750.00, 60300.00),
    (user_uuid, 'ETH/USDT', 'long', 3100.00, 5.0, 5, 3100.00, 500.00, 2480.00);

  -- Create some trade history
  INSERT INTO trades (user_id, pair, side, price, quantity, fee, fee_currency, trade_type, pnl, executed_at)
  VALUES
    (user_uuid, 'BTC/USDT', 'buy', 66500.00, 0.2, 2.66, 'USDT', 'spot', NULL, NOW() - INTERVAL '2 days'),
    (user_uuid, 'ETH/USDT', 'buy', 3050.00, 3.0, 0.915, 'USDT', 'spot', NULL, NOW() - INTERVAL '1 day'),
    (user_uuid, 'BTC/USDT', 'long', 65000.00, 0.3, 1.95, 'USDT', 'futures', 1500.00, NOW() - INTERVAL '3 days'),
    (user_uuid, 'BNB/USDT', 'short', 600.00, 10.0, 0.60, 'USDT', 'futures', -200.00, NOW() - INTERVAL '5 days');

  -- Create some pending rewards
  INSERT INTO user_rewards (user_id, task_type, amount, status, trading_volume)
  VALUES
    (user_uuid, 'welcome_bonus', 50.00, 'claimed', NULL),
    (user_uuid, 'trading_volume_bonus', 100.00, 'pending', 10000.00),
    (user_uuid, 'referral_bonus', 25.00, 'claimed', NULL);

  -- Create task progress
  INSERT INTO user_tasks_progress (user_id, task_id, current_progress, target_progress, completed)
  VALUES
    (user_uuid, 'first_deposit', 1, 1, true),
    (user_uuid, 'first_trade', 1, 1, true),
    (user_uuid, 'trade_volume_10k', 8500, 10000, false),
    (user_uuid, 'kyc_verification', 1, 1, true);

  -- Create some transaction history
  INSERT INTO transactions (user_id, transaction_type, currency, amount, fee, status, tx_hash, network, confirmed_at)
  VALUES
    (user_uuid, 'deposit', 'USDT', 50000.00, 0, 'completed', '0xabc123...', 'ERC20', NOW() - INTERVAL '7 days'),
    (user_uuid, 'deposit', 'BTC', 1.5, 0.0001, 'completed', 'bc1q...', 'Bitcoin', NOW() - INTERVAL '5 days'),
    (user_uuid, 'withdrawal', 'USDT', 5000.00, 25.00, 'completed', '0xdef456...', 'ERC20', NOW() - INTERVAL '2 days');

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to automatically setup demo data for new signups
CREATE OR REPLACE FUNCTION auto_setup_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Wait a moment for profile to be created by the other trigger
  PERFORM pg_sleep(0.5);
  
  -- Setup demo data for the new user
  PERFORM setup_demo_user(NEW.id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Optional trigger to auto-setup users (commented out by default)
-- Uncomment this if you want all new users to get demo data automatically
-- CREATE TRIGGER auto_setup_user_data
--   AFTER INSERT ON auth.users
--   FOR EACH ROW
--   EXECUTE FUNCTION auto_setup_new_user();