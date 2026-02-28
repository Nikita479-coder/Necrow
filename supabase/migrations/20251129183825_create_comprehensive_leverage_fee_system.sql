/*
  # Comprehensive Leverage Trading Fee System

  1. New Tables
    - `trading_fee_tiers` - Maker/taker fees by VIP level
    - `funding_rates` - Historical funding rates per pair (8-hour intervals)
    - `spread_config` - Spread markup configuration per pair
    - `liquidation_config` - Liquidation fee configuration
    - `fee_collections` - Track all fees collected by type

  2. Fee Types
    - Spread markup: 0.01%-0.05% (optional artificial markup)
    - Funding fees: -0.05% to +0.05% every 8 hours (paid between traders)
    - Trading fees: Maker (-0.02% to 0%) and Taker (0.02%-0.06%)
    - Liquidation fees: 0.50% (80% insurance fund, 20% exchange revenue)

  3. Features
    - VIP-based fee discounts
    - Automated funding rate calculations
    - Partial liquidation support
    - Insurance fund tracking
    - Comprehensive fee history

  4. Security
    - Enable RLS on all tables
    - Appropriate policies for users and admin
*/

-- Trading fee tiers by VIP level
CREATE TABLE IF NOT EXISTS trading_fee_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vip_level integer NOT NULL UNIQUE CHECK (vip_level >= 1 AND vip_level <= 6),
  maker_fee_rate numeric(10,6) NOT NULL DEFAULT 0.0002,
  taker_fee_rate numeric(10,6) NOT NULL DEFAULT 0.0006,
  description text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Funding rates (calculated every 8 hours for perpetual futures)
CREATE TABLE IF NOT EXISTS funding_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pair text NOT NULL,
  funding_rate numeric(10,6) NOT NULL CHECK (funding_rate >= -0.05 AND funding_rate <= 0.05),
  mark_price numeric(20,8) NOT NULL,
  index_price numeric(20,8) NOT NULL,
  funding_timestamp timestamptz NOT NULL,
  next_funding_time timestamptz NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Spread configuration (artificial markup)
CREATE TABLE IF NOT EXISTS spread_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pair text NOT NULL UNIQUE,
  spread_markup_percent numeric(10,6) NOT NULL DEFAULT 0.0001 CHECK (spread_markup_percent >= 0 AND spread_markup_percent <= 0.001),
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Liquidation configuration
CREATE TABLE IF NOT EXISTS liquidation_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  liquidation_fee_rate numeric(10,6) NOT NULL DEFAULT 0.005,
  insurance_fund_split numeric(10,6) NOT NULL DEFAULT 0.80,
  exchange_revenue_split numeric(10,6) NOT NULL DEFAULT 0.20,
  partial_liquidation_enabled boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Fee collections tracker
CREATE TABLE IF NOT EXISTS fee_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  position_id uuid REFERENCES futures_positions(position_id) ON DELETE SET NULL,
  fee_type text NOT NULL CHECK (fee_type IN ('spread', 'funding', 'maker', 'taker', 'liquidation')),
  pair text NOT NULL,
  notional_size numeric(20,8) NOT NULL,
  fee_rate numeric(10,6) NOT NULL,
  fee_amount numeric(20,8) NOT NULL,
  currency text DEFAULT 'USDT' NOT NULL,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Insurance fund tracking
CREATE TABLE IF NOT EXISTS insurance_fund (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  balance numeric(20,8) DEFAULT 0 NOT NULL,
  currency text DEFAULT 'USDT' NOT NULL,
  last_updated timestamptz DEFAULT now() NOT NULL
);

-- Funding payments between traders
CREATE TABLE IF NOT EXISTS funding_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  position_id uuid REFERENCES futures_positions(position_id) ON DELETE SET NULL,
  pair text NOT NULL,
  funding_rate numeric(10,6) NOT NULL,
  position_size numeric(20,8) NOT NULL,
  payment_amount numeric(20,8) NOT NULL,
  is_paid boolean DEFAULT false NOT NULL,
  funding_timestamp timestamptz NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_funding_rates_pair_time ON funding_rates(pair, funding_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_fee_collections_user ON fee_collections(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fee_collections_type ON fee_collections(fee_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_funding_payments_user ON funding_payments(user_id, funding_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_funding_payments_position ON funding_payments(position_id);

-- Enable RLS
ALTER TABLE trading_fee_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE funding_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE spread_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE liquidation_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE insurance_fund ENABLE ROW LEVEL SECURITY;
ALTER TABLE funding_payments ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- trading_fee_tiers: Everyone can read
CREATE POLICY "Anyone can view fee tiers"
  ON trading_fee_tiers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage fee tiers"
  ON trading_fee_tiers FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true')
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- funding_rates: Everyone can read
CREATE POLICY "Anyone can view funding rates"
  ON funding_rates FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can insert funding rates"
  ON funding_rates FOR INSERT
  TO authenticated
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- spread_config: Everyone can read
CREATE POLICY "Anyone can view spread config"
  ON spread_config FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage spread config"
  ON spread_config FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true')
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- liquidation_config: Everyone can read
CREATE POLICY "Anyone can view liquidation config"
  ON liquidation_config FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage liquidation config"
  ON liquidation_config FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true')
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- fee_collections: Users can view their own
CREATE POLICY "Users can view own fee collections"
  ON fee_collections FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view all fee collections"
  ON fee_collections FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

CREATE POLICY "System can insert fee collections"
  ON fee_collections FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- insurance_fund: Everyone can read
CREATE POLICY "Anyone can view insurance fund"
  ON insurance_fund FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "System can update insurance fund"
  ON insurance_fund FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true')
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- funding_payments: Users can view their own
CREATE POLICY "Users can view own funding payments"
  ON funding_payments FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view all funding payments"
  ON funding_payments FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

CREATE POLICY "System can insert funding payments"
  ON funding_payments FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Insert default fee tiers
INSERT INTO trading_fee_tiers (vip_level, maker_fee_rate, taker_fee_rate, description) VALUES
  (1, 0.0002, 0.0006, 'Entry - Standard fees'),
  (2, 0.00015, 0.00055, 'Moderate - 10K+ volume'),
  (3, 0.0001, 0.0005, 'Balanced - 100K+ volume'),
  (4, 0.00005, 0.00045, 'Advanced - 500K+ volume'),
  (5, 0.00000, 0.0004, 'Top-tier - 2.5M+ volume'),
  (6, -0.00002, 0.00035, 'Diamond Elite - 25M+ volume (maker rebate)')
ON CONFLICT (vip_level) DO UPDATE SET
  maker_fee_rate = EXCLUDED.maker_fee_rate,
  taker_fee_rate = EXCLUDED.taker_fee_rate,
  description = EXCLUDED.description,
  updated_at = now();

-- Insert default spread config for major pairs
INSERT INTO spread_config (pair, spread_markup_percent, is_active) VALUES
  ('BTCUSDT', 0.0001, true),
  ('ETHUSDT', 0.0001, true),
  ('BNBUSDT', 0.0002, true),
  ('SOLUSDT', 0.0002, true),
  ('XRPUSDT', 0.0002, true),
  ('ADAUSDT', 0.0003, true),
  ('DOGEUSDT', 0.0003, true),
  ('MATICUSDT', 0.0003, true),
  ('DOTUSDT', 0.0003, true),
  ('AVAXUSDT', 0.0003, true)
ON CONFLICT (pair) DO NOTHING;

-- Insert default liquidation config
INSERT INTO liquidation_config (
  liquidation_fee_rate,
  insurance_fund_split,
  exchange_revenue_split,
  partial_liquidation_enabled
) VALUES (
  0.005,
  0.80,
  0.20,
  true
)
ON CONFLICT DO NOTHING;

-- Initialize insurance fund
INSERT INTO insurance_fund (balance, currency, last_updated)
VALUES (10000.00, 'USDT', now())
ON CONFLICT DO NOTHING;
