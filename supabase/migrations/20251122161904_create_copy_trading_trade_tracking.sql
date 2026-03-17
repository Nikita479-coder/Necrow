/*
  # Copy Trading Trade Tracking System

  1. New Tables
    - `trader_trades` - Logs all trades executed by traders that are being copied
      - `id` (uuid, primary key)
      - `trader_id` (uuid, references user_profiles)
      - `position_id` (uuid, references futures_positions)
      - `pair` (text) - Trading pair (e.g., BTC/USDT)
      - `side` (text) - long or short
      - `entry_price` (numeric)
      - `exit_price` (numeric, nullable)
      - `quantity` (numeric)
      - `leverage` (integer)
      - `margin_used` (numeric)
      - `realized_pnl` (numeric, nullable)
      - `pnl_percentage` (numeric, nullable)
      - `status` (text) - open, closed
      - `opened_at` (timestamptz)
      - `closed_at` (timestamptz, nullable)
      
    - `copy_trade_allocations` - Tracks follower allocations for each trader trade
      - `id` (uuid, primary key)
      - `trader_trade_id` (uuid, references trader_trades)
      - `follower_id` (uuid, references user_profiles)
      - `copy_relationship_id` (uuid, references copy_relationships)
      - `allocated_amount` (numeric) - Amount follower allocated to this trade
      - `follower_leverage` (integer)
      - `entry_price` (numeric)
      - `exit_price` (numeric, nullable)
      - `realized_pnl` (numeric, nullable)
      - `pnl_percentage` (numeric, nullable)
      - `status` (text) - open, closed
      - `created_at` (timestamptz)
      - `closed_at` (timestamptz, nullable)

  2. Security
    - Enable RLS on all tables
    - Traders can view their own trades
    - Followers can view trades they're copying
    - Admins can view all
*/

-- Create trader_trades table
CREATE TABLE IF NOT EXISTS trader_trades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trader_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
  position_id uuid REFERENCES futures_positions(id) ON DELETE SET NULL,
  pair text NOT NULL,
  side text NOT NULL CHECK (side IN ('long', 'short')),
  entry_price numeric NOT NULL,
  exit_price numeric,
  quantity numeric NOT NULL,
  leverage integer NOT NULL,
  margin_used numeric NOT NULL,
  realized_pnl numeric DEFAULT 0,
  pnl_percentage numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  opened_at timestamptz DEFAULT now() NOT NULL,
  closed_at timestamptz,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create copy_trade_allocations table
CREATE TABLE IF NOT EXISTS copy_trade_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trader_trade_id uuid REFERENCES trader_trades(id) ON DELETE CASCADE NOT NULL,
  follower_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
  copy_relationship_id uuid REFERENCES copy_relationships(id) ON DELETE CASCADE NOT NULL,
  allocated_amount numeric NOT NULL,
  follower_leverage integer NOT NULL,
  entry_price numeric NOT NULL,
  exit_price numeric,
  realized_pnl numeric DEFAULT 0,
  pnl_percentage numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  created_at timestamptz DEFAULT now() NOT NULL,
  closed_at timestamptz,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_trader_trades_trader ON trader_trades(trader_id);
CREATE INDEX IF NOT EXISTS idx_trader_trades_status ON trader_trades(status);
CREATE INDEX IF NOT EXISTS idx_trader_trades_opened ON trader_trades(opened_at);
CREATE INDEX IF NOT EXISTS idx_copy_allocations_trader_trade ON copy_trade_allocations(trader_trade_id);
CREATE INDEX IF NOT EXISTS idx_copy_allocations_follower ON copy_trade_allocations(follower_id);
CREATE INDEX IF NOT EXISTS idx_copy_allocations_relationship ON copy_trade_allocations(copy_relationship_id);

-- Enable RLS
ALTER TABLE trader_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_trade_allocations ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trader_trades
CREATE POLICY "Traders can view own trades"
  ON trader_trades FOR SELECT
  TO authenticated
  USING (trader_id = auth.uid());

CREATE POLICY "System can insert trader trades"
  ON trader_trades FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update trader trades"
  ON trader_trades FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Admins can view all trader trades"
  ON trader_trades FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));

-- RLS Policies for copy_trade_allocations
CREATE POLICY "Followers can view own allocations"
  ON copy_trade_allocations FOR SELECT
  TO authenticated
  USING (follower_id = auth.uid());

CREATE POLICY "Traders can view their copiers allocations"
  ON copy_trade_allocations FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM trader_trades tt
      WHERE tt.id = copy_trade_allocations.trader_trade_id
      AND tt.trader_id = auth.uid()
    )
  );

CREATE POLICY "System can insert allocations"
  ON copy_trade_allocations FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update allocations"
  ON copy_trade_allocations FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Admins can view all allocations"
  ON copy_trade_allocations FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));
