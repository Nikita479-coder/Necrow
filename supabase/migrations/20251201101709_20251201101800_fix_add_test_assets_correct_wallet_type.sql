/*
  # Fix Test Crypto Assets - Use Correct Wallet Type

  ## Summary
  Corrects the wallet type from 'spot' to 'assets' and adds diverse crypto holdings.

  ## Changes
  1. Drops and recreates the function with correct wallet types
  2. Valid wallet types are: 'main', 'assets', 'copy', 'futures'
*/

-- Drop the old function
DROP FUNCTION IF EXISTS add_test_crypto_assets(text);

-- Function to add test crypto assets to a user (corrected)
CREATE OR REPLACE FUNCTION add_test_crypto_assets(user_email text)
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_result jsonb;
  v_assets_added integer := 0;
BEGIN
  -- Find user by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = user_email;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('User not found with email: %s', user_email)
    );
  END IF;

  -- Add various crypto assets to main wallet (for trading/swap)
  INSERT INTO wallets (user_id, currency, balance, locked_balance, wallet_type)
  VALUES
    (v_user_id, 'USDT', 50000, 0, 'main'),
    (v_user_id, 'BTC', 0.5, 0, 'main'),
    (v_user_id, 'ETH', 5, 0, 'main'),
    (v_user_id, 'BNB', 25, 0, 'main')
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET 
    balance = wallets.balance + EXCLUDED.balance;

  v_assets_added := v_assets_added + 4;

  -- Add assets to assets wallet (for withdrawal and staking)
  INSERT INTO wallets (user_id, currency, balance, locked_balance, wallet_type)
  VALUES
    (v_user_id, 'USDT', 75000, 0, 'assets'),
    (v_user_id, 'USDC', 30000, 0, 'assets'),
    (v_user_id, 'BTC', 1.25, 0, 'assets'),
    (v_user_id, 'ETH', 12, 0, 'assets'),
    (v_user_id, 'BNB', 80, 0, 'assets'),
    (v_user_id, 'SOL', 250, 0, 'assets'),
    (v_user_id, 'XRP', 15000, 0, 'assets'),
    (v_user_id, 'ADA', 10000, 0, 'assets'),
    (v_user_id, 'MATIC', 5000, 0, 'assets'),
    (v_user_id, 'LINK', 500, 0, 'assets'),
    (v_user_id, 'DOT', 800, 0, 'assets'),
    (v_user_id, 'AVAX', 300, 0, 'assets'),
    (v_user_id, 'ATOM', 1200, 0, 'assets'),
    (v_user_id, 'LTC', 100, 0, 'assets'),
    (v_user_id, 'TRX', 50000, 0, 'assets'),
    (v_user_id, 'DOGE', 100000, 0, 'assets'),
    (v_user_id, 'ALGO', 8000, 0, 'assets'),
    (v_user_id, 'VET', 75000, 0, 'assets')
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET 
    balance = wallets.balance + EXCLUDED.balance;

  v_assets_added := v_assets_added + 18;

  -- Add copy trading wallet assets
  INSERT INTO wallets (user_id, currency, balance, locked_balance, wallet_type)
  VALUES
    (v_user_id, 'USDT', 25000, 0, 'copy')
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET 
    balance = wallets.balance + EXCLUDED.balance;

  v_assets_added := v_assets_added + 1;

  -- Add futures wallet
  INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
  VALUES (v_user_id, 100000, 0)
  ON CONFLICT (user_id) 
  DO UPDATE SET 
    available_balance = futures_margin_wallets.available_balance + 100000;

  v_assets_added := v_assets_added + 1;

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Added %s crypto assets to user %s', v_assets_added, user_email),
    'user_id', v_user_id,
    'assets_added', v_assets_added
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('Error adding assets: %s', SQLERRM)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION add_test_crypto_assets TO authenticated;

-- Add assets to admin@test.com if the account exists
DO $$
DECLARE
  v_result jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@test.com') THEN
    SELECT add_test_crypto_assets('admin@test.com') INTO v_result;
    RAISE NOTICE 'Result: %', v_result;
  END IF;
END $$;
