/*
  # Futures Trading Core Tables

  ## Description
  This migration creates the core tables for futures trading including orders,
  positions, margin wallets, and tracking tables for liquidations and modifications.

  ## New Tables

  ### 1. futures_margin_wallets
  Separate wallet for futures trading with available and locked balances
  - `user_id` (uuid, primary key)
  - `available_balance` (numeric) - Free balance for new positions
  - `locked_balance` (numeric) - Balance locked in orders and positions
  - `total_deposited` (numeric) - Lifetime deposits to futures wallet
  - `total_withdrawn` (numeric) - Lifetime withdrawals from futures wallet
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. futures_orders
  All futures orders including pending, filled, and cancelled
  - `order_id` (uuid, primary key)
  - `user_id` (uuid) - User who placed the order
  - `pair` (text) - Trading pair (e.g., BTCUSDT)
  - `side` (text) - long or short
  - `order_type` (text) - market, limit, or stop_limit
  - `order_status` (text) - pending, filled, partially_filled, cancelled, rejected
  - `price` (numeric) - Limit price for limit orders
  - `trigger_price` (numeric) - Trigger price for stop orders
  - `quantity` (numeric) - Total order quantity
  - `filled_quantity` (numeric) - Amount filled so far
  - `remaining_quantity` (numeric) - Amount still pending
  - `leverage` (integer) - Selected leverage
  - `margin_mode` (text) - cross or isolated
  - `margin_amount` (numeric) - Margin locked for this order
  - `stop_loss` (numeric) - Optional stop loss price
  - `take_profit` (numeric) - Optional take profit price
  - `reduce_only` (boolean) - Only reduce position size
  - `maker_or_taker` (text) - Filled as maker or taker
  - `fee_paid` (numeric) - Total fees paid
  - `average_fill_price` (numeric) - Average execution price
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)
  - `filled_at` (timestamptz)
  - `cancelled_at` (timestamptz)

  ### 3. futures_positions
  All open and closed positions
  - `position_id` (uuid, primary key)
  - `user_id` (uuid) - Position owner
  - `pair` (text) - Trading pair
  - `side` (text) - long or short
  - `entry_price` (numeric) - Average entry price
  - `mark_price` (numeric) - Current mark price
  - `quantity` (numeric) - Position size
  - `leverage` (integer) - Position leverage
  - `margin_mode` (text) - cross or isolated
  - `margin_allocated` (numeric) - Margin dedicated to this position
  - `liquidation_price` (numeric) - Price at which liquidation occurs
  - `unrealized_pnl` (numeric) - Current profit/loss
  - `realized_pnl` (numeric) - Locked in profit/loss from partial closes
  - `cumulative_fees` (numeric) - Total fees paid
  - `stop_loss` (numeric) - Stop loss price
  - `take_profit` (numeric) - Take profit price
  - `status` (text) - open, closed, liquidated
  - `maintenance_margin_rate` (numeric) - MMR for this position
  - `opened_at` (timestamptz)
  - `closed_at` (timestamptz)
  - `last_price_update` (timestamptz)

  ### 4. position_modifications
  Log of all position changes
  - `id` (uuid, primary key)
  - `position_id` (uuid) - Position being modified
  - `modification_type` (text) - Type of change
  - `old_value` (jsonb) - Previous values
  - `new_value` (jsonb) - New values
  - `created_at` (timestamptz)

  ### 5. liquidation_events
  Record of all liquidations
  - `id` (uuid, primary key)
  - `position_id` (uuid) - Liquidated position
  - `user_id` (uuid) - User whose position was liquidated
  - `pair` (text) - Trading pair
  - `side` (text) - Position side
  - `quantity` (numeric) - Position size
  - `entry_price` (numeric) - Original entry
  - `liquidation_price` (numeric) - Actual liquidation price
  - `equity_before` (numeric) - Margin before liquidation
  - `loss_amount` (numeric) - Total loss
  - `liquidation_fee` (numeric) - Fee charged
  - `insurance_fund_used` (numeric) - Insurance coverage
  - `created_at` (timestamptz)

  ### 6. liquidation_queue
  Positions approaching liquidation for monitoring
  - `id` (uuid, primary key)
  - `position_id` (uuid) - Position at risk
  - `user_id` (uuid) - User to notify
  - `pair` (text) - Trading pair
  - `margin_ratio` (numeric) - Current margin health
  - `warning_level` (text) - warning, critical, immediate
  - `checked_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Users can only access their own data
  - Separate read and write policies

  ## Indexes
  - Optimized for order matching and position monitoring
  - Fast lookups by user, pair, and status
*/

-- Futures Margin Wallets Table
CREATE TABLE IF NOT EXISTS futures_margin_wallets (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  available_balance numeric(20,8) NOT NULL DEFAULT 0,
  locked_balance numeric(20,8) NOT NULL DEFAULT 0,
  total_deposited numeric(20,8) NOT NULL DEFAULT 0,
  total_withdrawn numeric(20,8) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (available_balance >= 0),
  CHECK (locked_balance >= 0)
);

-- Futures Orders Table
CREATE TABLE IF NOT EXISTS futures_orders (
  order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pair text NOT NULL,
  side text NOT NULL,
  order_type text NOT NULL,
  order_status text NOT NULL DEFAULT 'pending',
  price numeric(20,8),
  trigger_price numeric(20,8),
  quantity numeric(20,8) NOT NULL,
  filled_quantity numeric(20,8) DEFAULT 0,
  remaining_quantity numeric(20,8),
  leverage integer NOT NULL,
  margin_mode text NOT NULL,
  margin_amount numeric(20,8) NOT NULL,
  stop_loss numeric(20,8),
  take_profit numeric(20,8),
  reduce_only boolean DEFAULT false,
  maker_or_taker text,
  fee_paid numeric(20,8) DEFAULT 0,
  average_fill_price numeric(20,8),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  filled_at timestamptz,
  cancelled_at timestamptz,
  CHECK (side IN ('long', 'short')),
  CHECK (order_type IN ('market', 'limit', 'stop_limit')),
  CHECK (order_status IN ('pending', 'filled', 'partially_filled', 'cancelled', 'rejected')),
  CHECK (margin_mode IN ('cross', 'isolated')),
  CHECK (leverage >= 1 AND leverage <= 125),
  CHECK (quantity > 0),
  CHECK (filled_quantity >= 0),
  CHECK (maker_or_taker IS NULL OR maker_or_taker IN ('maker', 'taker'))
);

-- Futures Positions Table
CREATE TABLE IF NOT EXISTS futures_positions (
  position_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pair text NOT NULL,
  side text NOT NULL,
  entry_price numeric(20,8) NOT NULL,
  mark_price numeric(20,8),
  quantity numeric(20,8) NOT NULL,
  leverage integer NOT NULL,
  margin_mode text NOT NULL,
  margin_allocated numeric(20,8) NOT NULL,
  liquidation_price numeric(20,8),
  unrealized_pnl numeric(20,8) DEFAULT 0,
  realized_pnl numeric(20,8) DEFAULT 0,
  cumulative_fees numeric(20,8) DEFAULT 0,
  stop_loss numeric(20,8),
  take_profit numeric(20,8),
  status text NOT NULL DEFAULT 'open',
  maintenance_margin_rate numeric(10,6),
  opened_at timestamptz DEFAULT now(),
  closed_at timestamptz,
  last_price_update timestamptz DEFAULT now(),
  CHECK (side IN ('long', 'short')),
  CHECK (margin_mode IN ('cross', 'isolated')),
  CHECK (status IN ('open', 'closed', 'liquidated')),
  CHECK (leverage >= 1 AND leverage <= 125),
  CHECK (quantity > 0),
  CHECK (margin_allocated > 0)
);

-- Position Modifications Log
CREATE TABLE IF NOT EXISTS position_modifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  position_id uuid REFERENCES futures_positions(position_id) ON DELETE CASCADE NOT NULL,
  modification_type text NOT NULL,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz DEFAULT now(),
  CHECK (modification_type IN ('margin_added', 'margin_removed', 'tp_sl_updated', 'partial_close', 'leverage_changed'))
);

-- Liquidation Events Log
CREATE TABLE IF NOT EXISTS liquidation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  position_id uuid NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pair text NOT NULL,
  side text NOT NULL,
  quantity numeric(20,8) NOT NULL,
  entry_price numeric(20,8) NOT NULL,
  liquidation_price numeric(20,8) NOT NULL,
  equity_before numeric(20,8),
  loss_amount numeric(20,8),
  liquidation_fee numeric(20,8),
  insurance_fund_used numeric(20,8) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  CHECK (side IN ('long', 'short'))
);

-- Liquidation Queue for Monitoring
CREATE TABLE IF NOT EXISTS liquidation_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  position_id uuid REFERENCES futures_positions(position_id) ON DELETE CASCADE NOT NULL UNIQUE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  pair text NOT NULL,
  margin_ratio numeric(10,4),
  warning_level text NOT NULL,
  checked_at timestamptz DEFAULT now(),
  CHECK (warning_level IN ('warning', 'critical', 'immediate'))
);

-- Enable RLS
ALTER TABLE futures_margin_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE futures_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE futures_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE position_modifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE liquidation_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE liquidation_queue ENABLE ROW LEVEL SECURITY;

-- RLS Policies for futures_margin_wallets
CREATE POLICY "Users can view own margin wallet"
  ON futures_margin_wallets FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own margin wallet"
  ON futures_margin_wallets FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- RLS Policies for futures_orders
CREATE POLICY "Users can view own orders"
  ON futures_orders FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own orders"
  ON futures_orders FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- RLS Policies for futures_positions
CREATE POLICY "Users can view own positions"
  ON futures_positions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- RLS Policies for position_modifications
CREATE POLICY "Users can view own position modifications"
  ON position_modifications FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM futures_positions
      WHERE position_id = position_modifications.position_id
      AND user_id = auth.uid()
    )
  );

-- RLS Policies for liquidation_events
CREATE POLICY "Users can view own liquidation events"
  ON liquidation_events FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- RLS Policies for liquidation_queue
CREATE POLICY "Users can view own liquidation warnings"
  ON liquidation_queue FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_futures_orders_user_id ON futures_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_futures_orders_status ON futures_orders(order_status) WHERE order_status IN ('pending', 'partially_filled');
CREATE INDEX IF NOT EXISTS idx_futures_orders_pair ON futures_orders(pair);
CREATE INDEX IF NOT EXISTS idx_futures_orders_user_pair ON futures_orders(user_id, pair);

CREATE INDEX IF NOT EXISTS idx_futures_positions_user_id ON futures_positions(user_id);
CREATE INDEX IF NOT EXISTS idx_futures_positions_status ON futures_positions(status) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS idx_futures_positions_pair ON futures_positions(pair);
CREATE INDEX IF NOT EXISTS idx_futures_positions_user_pair_status ON futures_positions(user_id, pair, status);

CREATE INDEX IF NOT EXISTS idx_liquidation_queue_checked_at ON liquidation_queue(checked_at);
CREATE INDEX IF NOT EXISTS idx_liquidation_queue_warning_level ON liquidation_queue(warning_level);
CREATE INDEX IF NOT EXISTS idx_liquidation_events_user_id ON liquidation_events(user_id);
CREATE INDEX IF NOT EXISTS idx_liquidation_events_created_at ON liquidation_events(created_at DESC);

-- Trigger to initialize margin wallet for new users
CREATE OR REPLACE FUNCTION initialize_futures_margin_wallet()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO futures_margin_wallets (user_id, available_balance)
  VALUES (NEW.id, 0)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_user_created_init_futures_wallet
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_futures_margin_wallet();

-- Trigger to update remaining_quantity on orders
CREATE OR REPLACE FUNCTION update_order_remaining_quantity()
RETURNS TRIGGER AS $$
BEGIN
  NEW.remaining_quantity := NEW.quantity - NEW.filled_quantity;
  NEW.updated_at := now();
  
  -- Auto-update status based on fill
  IF NEW.filled_quantity = 0 THEN
    NEW.order_status := 'pending';
  ELSIF NEW.filled_quantity < NEW.quantity THEN
    NEW.order_status := 'partially_filled';
  ELSIF NEW.filled_quantity >= NEW.quantity THEN
    NEW.order_status := 'filled';
    NEW.filled_at := now();
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_remaining_quantity_on_order_change
  BEFORE INSERT OR UPDATE OF filled_quantity ON futures_orders
  FOR EACH ROW
  EXECUTE FUNCTION update_order_remaining_quantity();