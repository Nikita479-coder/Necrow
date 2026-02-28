/*
  # Create Mock Trading System

  ## Description
  Creates a complete mock/paper trading system that mirrors real trading
  but uses virtual funds. Users start with 10,000 USDT demo balance.
  When mock trading is stopped, all history is cleared.

  ## New Tables

  ### 1. mock_wallets
  Virtual wallet for mock trading
  - `user_id` (uuid, primary key)
  - `balance` (numeric) - Available mock balance
  - `locked_balance` (numeric) - Balance locked in mock positions
  - Default 10,000 USDT on creation

  ### 2. mock_futures_positions
  Mock futures positions that mirror real positions structure
  - All columns mirror futures_positions
  - Isolated from real positions

  ### 3. mock_futures_orders
  Mock order history
  - All columns mirror futures_orders
  - Isolated from real orders

  ## Security
  - RLS enabled on all tables
  - Users can only access their own mock data
*/

-- Mock Wallets Table
CREATE TABLE IF NOT EXISTS mock_wallets (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  balance numeric(20,8) NOT NULL DEFAULT 10000,
  locked_balance numeric(20,8) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (balance >= 0),
  CHECK (locked_balance >= 0)
);

-- Mock Futures Positions Table
CREATE TABLE IF NOT EXISTS mock_futures_positions (
  position_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pair text NOT NULL,
  side text NOT NULL CHECK (side IN ('long', 'short')),
  quantity numeric(20,8) NOT NULL,
  entry_price numeric(20,8) NOT NULL,
  current_price numeric(20,8),
  leverage integer NOT NULL DEFAULT 1,
  margin_allocated numeric(20,8) NOT NULL,
  liquidation_price numeric(20,8),
  take_profit numeric(20,8),
  stop_loss numeric(20,8),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'liquidated')),
  realized_pnl numeric(20,8) DEFAULT 0,
  close_price numeric(20,8),
  opened_at timestamptz DEFAULT now(),
  closed_at timestamptz,
  updated_at timestamptz DEFAULT now()
);

-- Mock Futures Orders Table
CREATE TABLE IF NOT EXISTS mock_futures_orders (
  order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pair text NOT NULL,
  side text NOT NULL CHECK (side IN ('long', 'short')),
  order_type text NOT NULL CHECK (order_type IN ('market', 'limit')),
  order_status text NOT NULL DEFAULT 'pending' CHECK (order_status IN ('pending', 'filled', 'cancelled', 'expired')),
  price numeric(20,8),
  quantity numeric(20,8) NOT NULL,
  filled_quantity numeric(20,8) DEFAULT 0,
  leverage integer NOT NULL DEFAULT 1,
  margin_amount numeric(20,8) NOT NULL,
  created_at timestamptz DEFAULT now(),
  filled_at timestamptz,
  cancelled_at timestamptz
);

-- Enable RLS
ALTER TABLE mock_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE mock_futures_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE mock_futures_orders ENABLE ROW LEVEL SECURITY;

-- Mock Wallets Policies
CREATE POLICY "Users can read own mock wallet"
  ON mock_wallets FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own mock wallet"
  ON mock_wallets FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own mock wallet"
  ON mock_wallets FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Mock Positions Policies
CREATE POLICY "Users can read own mock positions"
  ON mock_futures_positions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own mock positions"
  ON mock_futures_positions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own mock positions"
  ON mock_futures_positions FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own mock positions"
  ON mock_futures_positions FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Mock Orders Policies
CREATE POLICY "Users can read own mock orders"
  ON mock_futures_orders FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own mock orders"
  ON mock_futures_orders FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own mock orders"
  ON mock_futures_orders FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own mock orders"
  ON mock_futures_orders FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_mock_futures_positions_user_id ON mock_futures_positions(user_id);
CREATE INDEX IF NOT EXISTS idx_mock_futures_positions_status ON mock_futures_positions(status);
CREATE INDEX IF NOT EXISTS idx_mock_futures_orders_user_id ON mock_futures_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_mock_futures_orders_status ON mock_futures_orders(order_status);

-- Function to get or create mock wallet
CREATE OR REPLACE FUNCTION get_or_create_mock_wallet()
RETURNS mock_wallets
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
  v_wallet mock_wallets;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_wallet FROM mock_wallets WHERE user_id = v_user_id;
  
  IF NOT FOUND THEN
    INSERT INTO mock_wallets (user_id, balance, locked_balance)
    VALUES (v_user_id, 10000, 0)
    RETURNING * INTO v_wallet;
  END IF;
  
  RETURN v_wallet;
END;
$$;

-- Function to reset mock trading (clears all history and resets balance)
CREATE OR REPLACE FUNCTION reset_mock_trading()
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Delete all mock positions
  DELETE FROM mock_futures_positions WHERE user_id = v_user_id;
  
  -- Delete all mock orders
  DELETE FROM mock_futures_orders WHERE user_id = v_user_id;
  
  -- Reset wallet to 10,000 USDT
  INSERT INTO mock_wallets (user_id, balance, locked_balance)
  VALUES (v_user_id, 10000, 0)
  ON CONFLICT (user_id) DO UPDATE SET
    balance = 10000,
    locked_balance = 0,
    updated_at = now();

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Mock trading reset successfully',
    'new_balance', 10000
  );
END;
$$;
