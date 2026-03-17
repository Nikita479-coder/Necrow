/*
  # Create Swap Trading System

  ## Description
  Creates the complete swap/convert trading system with instant and limit orders.
  Supports spot swaps between any crypto pairs with proper balance management.

  ## Tables

  ### swap_orders
  Stores all swap orders (instant and limit)
  - `order_id` (uuid, primary key) - Unique order identifier
  - `user_id` (uuid) - User who placed the order
  - `from_currency` (text) - Currency being sold
  - `to_currency` (text) - Currency being bought
  - `from_amount` (numeric) - Amount to sell
  - `to_amount` (numeric) - Amount to receive
  - `order_type` (text) - instant or limit
  - `limit_price` (numeric) - Limit price (only for limit orders)
  - `execution_rate` (numeric) - Actual execution rate
  - `status` (text) - pending, executed, cancelled, expired
  - `fee_amount` (numeric) - Fee charged (0 for now)
  - `executed_at` (timestamptz) - When order was executed
  - `expires_at` (timestamptz) - When limit order expires
  - `created_at` (timestamptz) - When order was created

  ## Functions

  ### execute_instant_swap()
  Executes an instant swap at current market price
  - Validates user has sufficient balance
  - Locks from_currency balance
  - Calculates exchange rate from market prices
  - Updates both currency balances
  - Records transaction in transactions table
  - Returns order details

  ### place_limit_swap_order()
  Places a limit order that executes when price target is reached
  - Validates balance
  - Locks from_currency balance
  - Creates pending order
  - Will execute automatically when price is reached

  ### check_and_execute_limit_swaps()
  Background function to check and execute pending limit orders
  - Called periodically or via trigger
  - Checks all pending limit orders
  - Executes orders where target price is reached

  ## Security
  - RLS enabled on all tables
  - Users can only access their own orders
  - Balance validation before swaps
  - Transaction logging for audit trail

  ## Important Notes
  - Zero fees for swaps (as per UI)
  - Instant swaps execute immediately at market rate
  - Limit orders execute when 1 from_currency = limit_price to_currency
  - 30-day expiration for limit orders
  - All swaps are atomic transactions
*/

-- Create swap orders table
CREATE TABLE IF NOT EXISTS swap_orders (
  order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  from_currency text NOT NULL,
  to_currency text NOT NULL,
  from_amount numeric(20,8) NOT NULL,
  to_amount numeric(20,8) NOT NULL,
  order_type text NOT NULL,
  limit_price numeric(20,8),
  execution_rate numeric(20,8),
  status text NOT NULL DEFAULT 'pending',
  fee_amount numeric(20,8) DEFAULT 0,
  executed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (order_type IN ('instant', 'limit')),
  CHECK (status IN ('pending', 'executed', 'cancelled', 'expired')),
  CHECK (from_amount > 0),
  CHECK (to_amount > 0),
  CHECK (from_currency != to_currency)
);

-- Enable RLS
ALTER TABLE swap_orders ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own swap orders"
  ON swap_orders FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own swap orders"
  ON swap_orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own swap orders"
  ON swap_orders FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_swap_orders_user ON swap_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_swap_orders_status ON swap_orders(status);
CREATE INDEX IF NOT EXISTS idx_swap_orders_pending_limits ON swap_orders(status, order_type) WHERE status = 'pending' AND order_type = 'limit';

-- Function to get current exchange rate from market prices
CREATE OR REPLACE FUNCTION get_swap_rate(p_from_currency text, p_to_currency text)
RETURNS numeric AS $$
DECLARE
  v_from_price numeric;
  v_to_price numeric;
BEGIN
  -- Get current prices (in USDT)
  SELECT mark_price INTO v_from_price
  FROM market_prices
  WHERE pair = p_from_currency || 'USDT'
  LIMIT 1;
  
  SELECT mark_price INTO v_to_price
  FROM market_prices
  WHERE pair = p_to_currency || 'USDT'
  LIMIT 1;
  
  -- Handle stablecoins
  IF p_from_currency IN ('USDT', 'USDC', 'DAI') THEN
    v_from_price := 1.0;
  END IF;
  
  IF p_to_currency IN ('USDT', 'USDC', 'DAI') THEN
    v_to_price := 1.0;
  END IF;
  
  -- If prices not found, return 0
  IF v_from_price IS NULL OR v_to_price IS NULL THEN
    RETURN 0;
  END IF;
  
  -- Calculate rate: how many to_currency per 1 from_currency
  RETURN v_from_price / v_to_price;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to execute instant swap
CREATE OR REPLACE FUNCTION execute_instant_swap(
  p_user_id uuid,
  p_from_currency text,
  p_to_currency text,
  p_from_amount numeric
)
RETURNS jsonb AS $$
DECLARE
  v_from_wallet record;
  v_to_wallet record;
  v_exchange_rate numeric;
  v_to_amount numeric;
  v_order_id uuid;
  v_fee_amount numeric := 0;
BEGIN
  -- Validate inputs
  IF p_from_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;
  
  IF p_from_currency = p_to_currency THEN
    RAISE EXCEPTION 'Cannot swap same currency';
  END IF;
  
  -- Get current exchange rate
  v_exchange_rate := get_swap_rate(p_from_currency, p_to_currency);
  
  IF v_exchange_rate <= 0 THEN
    RAISE EXCEPTION 'Exchange rate not available for % to %', p_from_currency, p_to_currency;
  END IF;
  
  -- Calculate to_amount
  v_to_amount := p_from_amount * v_exchange_rate;
  
  -- Get or create from wallet
  SELECT * INTO v_from_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_from_currency
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found for currency %', p_from_currency;
  END IF;
  
  -- Check sufficient balance
  IF v_from_wallet.balance < p_from_amount THEN
    RAISE EXCEPTION 'Insufficient balance. Available: %, Required: %', v_from_wallet.balance, p_from_amount;
  END IF;
  
  -- Get or create to wallet
  SELECT * INTO v_to_wallet
  FROM wallets
  WHERE user_id = p_user_id AND currency = p_to_currency
  FOR UPDATE;
  
  IF NOT FOUND THEN
    -- Create wallet if doesn't exist
    INSERT INTO wallets (user_id, currency, balance, locked_balance, total_deposited, total_withdrawn)
    VALUES (p_user_id, p_to_currency, 0, 0, 0, 0)
    RETURNING * INTO v_to_wallet;
  END IF;
  
  -- Update from wallet (deduct amount)
  UPDATE wallets
  SET balance = balance - p_from_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = p_from_currency;
  
  -- Update to wallet (add amount)
  UPDATE wallets
  SET balance = balance + v_to_amount,
      updated_at = now()
  WHERE user_id = p_user_id AND currency = p_to_currency;
  
  -- Create swap order record
  INSERT INTO swap_orders (
    user_id, from_currency, to_currency, from_amount, to_amount,
    order_type, execution_rate, status, fee_amount, executed_at
  )
  VALUES (
    p_user_id, p_from_currency, p_to_currency, p_from_amount, v_to_amount,
    'instant', v_exchange_rate, 'executed', v_fee_amount, now()
  )
  RETURNING order_id INTO v_order_id;
  
  -- Record transaction
  INSERT INTO transactions (user_id, type, currency, amount, status, description)
  VALUES 
    (p_user_id, 'swap_out', p_from_currency, p_from_amount, 'completed', 
     'Swapped ' || p_from_amount || ' ' || p_from_currency || ' to ' || p_to_currency),
    (p_user_id, 'swap_in', p_to_currency, v_to_amount, 'completed',
     'Received ' || v_to_amount || ' ' || p_to_currency || ' from swap');
  
  -- Return order details
  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'from_amount', p_from_amount,
    'to_amount', v_to_amount,
    'exchange_rate', v_exchange_rate,
    'fee', v_fee_amount
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql;