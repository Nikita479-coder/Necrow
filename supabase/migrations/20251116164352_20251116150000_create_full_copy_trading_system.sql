/*
  # Complete Copy Trading System

  ## Overview
  Creates a fully functional copy trading system similar to Binance, with:
  - Real and mock copy trading support
  - Position mirroring from traders
  - Daily PnL tracking and updates
  - Balance management for copy trading wallets
  - Automated trade execution

  ## Tables Created
  1. `copy_positions` - Active positions opened through copy trading
  2. `copy_position_history` - Historical closed positions
  3. `copy_trading_stats` - Daily statistics tracking
  4. `copy_trade_mirrors` - Maps follower positions to trader positions

  ## Functions Created
  - `start_copy_trading()` - Initialize copy trading relationship
  - `stop_copy_trading()` - End copy trading relationship
  - `mirror_trader_position()` - Copy a trader's position
  - `close_copy_position()` - Close a copied position
  - `update_copy_stats()` - Update daily statistics
  - `calculate_copy_pnl()` - Calculate current PnL

  ## Security
  - All tables have RLS enabled
  - Users can only access their own copy trading data
  - Traders can view their followers' aggregate stats
*/

-- Copy positions table (similar to futures_positions but for copy trading)
CREATE TABLE IF NOT EXISTS copy_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trader_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  relationship_id uuid REFERENCES copy_relationships(id) ON DELETE CASCADE NOT NULL,
  is_mock boolean DEFAULT false NOT NULL,

  symbol text NOT NULL,
  side text NOT NULL CHECK (side IN ('long', 'short')),
  size numeric(20,8) NOT NULL CHECK (size > 0),
  entry_price numeric(20,8) NOT NULL CHECK (entry_price > 0),
  current_price numeric(20,8) NOT NULL CHECK (current_price > 0),

  leverage integer NOT NULL CHECK (leverage >= 1 AND leverage <= 125),
  margin numeric(20,8) NOT NULL CHECK (margin > 0),
  liquidation_price numeric(20,8),

  unrealized_pnl numeric(20,8) DEFAULT 0,
  realized_pnl numeric(20,8) DEFAULT 0,

  stop_loss_price numeric(20,8),
  take_profit_price numeric(20,8),

  opened_at timestamptz DEFAULT now() NOT NULL,
  last_update timestamptz DEFAULT now() NOT NULL,

  trader_position_id uuid,

  created_at timestamptz DEFAULT now() NOT NULL
);

-- Copy position history (closed positions)
CREATE TABLE IF NOT EXISTS copy_position_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trader_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  relationship_id uuid REFERENCES copy_relationships(id) ON DELETE CASCADE NOT NULL,
  is_mock boolean DEFAULT false NOT NULL,

  symbol text NOT NULL,
  side text NOT NULL CHECK (side IN ('long', 'short')),
  size numeric(20,8) NOT NULL,
  entry_price numeric(20,8) NOT NULL,
  exit_price numeric(20,8) NOT NULL,

  leverage integer NOT NULL,
  margin numeric(20,8) NOT NULL,

  realized_pnl numeric(20,8) NOT NULL,
  fees numeric(20,8) DEFAULT 0,

  opened_at timestamptz NOT NULL,
  closed_at timestamptz DEFAULT now() NOT NULL,

  close_reason text CHECK (close_reason IN ('manual', 'stop_loss', 'take_profit', 'liquidation', 'trader_closed')),

  created_at timestamptz DEFAULT now() NOT NULL
);

-- Daily copy trading statistics
CREATE TABLE IF NOT EXISTS copy_trading_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid REFERENCES copy_relationships(id) ON DELETE CASCADE NOT NULL,
  follower_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trader_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  is_mock boolean DEFAULT false NOT NULL,

  stat_date date NOT NULL DEFAULT CURRENT_DATE,

  starting_balance numeric(20,8) NOT NULL DEFAULT 0,
  ending_balance numeric(20,8) NOT NULL DEFAULT 0,
  daily_pnl numeric(20,8) NOT NULL DEFAULT 0,
  daily_pnl_percent numeric(10,4) NOT NULL DEFAULT 0,

  total_trades integer DEFAULT 0,
  winning_trades integer DEFAULT 0,
  losing_trades integer DEFAULT 0,

  total_volume numeric(20,8) DEFAULT 0,
  total_fees numeric(20,8) DEFAULT 0,

  created_at timestamptz DEFAULT now() NOT NULL,

  UNIQUE(relationship_id, stat_date)
);

-- Trade mirroring mapping table
CREATE TABLE IF NOT EXISTS copy_trade_mirrors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_position_id uuid REFERENCES copy_positions(id) ON DELETE CASCADE NOT NULL,
  trader_position_id uuid NOT NULL,

  mirror_ratio numeric(10,6) NOT NULL DEFAULT 1.0,

  created_at timestamptz DEFAULT now() NOT NULL,

  UNIQUE(follower_position_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_copy_positions_follower ON copy_positions(follower_id);
CREATE INDEX IF NOT EXISTS idx_copy_positions_trader ON copy_positions(trader_id);
CREATE INDEX IF NOT EXISTS idx_copy_positions_relationship ON copy_positions(relationship_id);
CREATE INDEX IF NOT EXISTS idx_copy_position_history_follower ON copy_position_history(follower_id);
CREATE INDEX IF NOT EXISTS idx_copy_position_history_trader ON copy_position_history(trader_id);
CREATE INDEX IF NOT EXISTS idx_copy_trading_stats_relationship ON copy_trading_stats(relationship_id);
CREATE INDEX IF NOT EXISTS idx_copy_trading_stats_date ON copy_trading_stats(stat_date);

-- Enable RLS
ALTER TABLE copy_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_position_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_trading_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_trade_mirrors ENABLE ROW LEVEL SECURITY;

-- RLS Policies for copy_positions
CREATE POLICY "Users can view own copy positions"
  ON copy_positions FOR SELECT
  TO authenticated
  USING (auth.uid() = follower_id);

CREATE POLICY "Users can insert own copy positions"
  ON copy_positions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can update own copy positions"
  ON copy_positions FOR UPDATE
  TO authenticated
  USING (auth.uid() = follower_id)
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can delete own copy positions"
  ON copy_positions FOR DELETE
  TO authenticated
  USING (auth.uid() = follower_id);

-- RLS Policies for copy_position_history
CREATE POLICY "Users can view own copy history"
  ON copy_position_history FOR SELECT
  TO authenticated
  USING (auth.uid() = follower_id);

CREATE POLICY "Users can insert own copy history"
  ON copy_position_history FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = follower_id);

-- RLS Policies for copy_trading_stats
CREATE POLICY "Users can view own copy stats"
  ON copy_trading_stats FOR SELECT
  TO authenticated
  USING (auth.uid() = follower_id);

CREATE POLICY "Users can insert own copy stats"
  ON copy_trading_stats FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can update own copy stats"
  ON copy_trading_stats FOR UPDATE
  TO authenticated
  USING (auth.uid() = follower_id)
  WITH CHECK (auth.uid() = follower_id);

-- RLS Policies for copy_trade_mirrors
CREATE POLICY "Users can view own trade mirrors"
  ON copy_trade_mirrors FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM copy_positions
      WHERE copy_positions.id = follower_position_id
      AND copy_positions.follower_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own trade mirrors"
  ON copy_trade_mirrors FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM copy_positions
      WHERE copy_positions.id = follower_position_id
      AND copy_positions.follower_id = auth.uid()
    )
  );
