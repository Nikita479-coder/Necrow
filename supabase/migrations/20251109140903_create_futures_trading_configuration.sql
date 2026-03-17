/*
  # Futures Trading Configuration Tables

  ## Description
  This migration creates the configuration tables for the futures trading system,
  including trading pairs, fee structures, leverage tiers, and maintenance margin rates.

  ## New Tables

  ### 1. trading_pairs_config
  Configuration for each trading pair with fees and leverage limits
  - `pair` (text, primary key) - Trading pair symbol (e.g., BTCUSDT)
  - `max_leverage` (integer) - Maximum allowed leverage for this pair
  - `maker_fee` (numeric) - Fee for limit orders that add liquidity (0.0002 = 0.02%)
  - `taker_fee` (numeric) - Fee for market orders that take liquidity (0.0004 = 0.04%)
  - `liquidation_fee` (numeric) - Fee charged on liquidated positions (0.004 = 0.4%)
  - `min_order_size` (numeric) - Minimum position size in base currency
  - `max_position_size` (numeric) - Maximum position size in base currency
  - `pair_type` (text) - Category: major, altcoin, lowcap
  - `is_active` (boolean) - Whether pair is available for trading
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. leverage_tiers
  Maintenance margin requirements based on leverage level
  - `id` (uuid, primary key)
  - `tier_name` (text) - Human-readable tier name
  - `min_leverage` (integer) - Minimum leverage for this tier
  - `max_leverage` (integer) - Maximum leverage for this tier
  - `maintenance_margin_rate` (numeric) - MMR for this tier
  - `insurance_buffer` (numeric) - Safety buffer (typically 0.0005)
  - `created_at` (timestamptz)

  ### 3. user_leverage_limits
  Per-user leverage restrictions based on KYC level
  - `user_id` (uuid, primary key)
  - `max_allowed_leverage` (integer) - Maximum leverage based on verification
  - `updated_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Public read access for trading config
  - Only admin can modify configuration
  - Users can read own leverage limits

  ## Important Notes
  Fee values are decimal representations:
  - 0.0002 = 0.02% maker fee
  - 0.0004 = 0.04% taker fee
  - 0.004 = 0.4% liquidation fee

  Leverage tiers follow exchange standards:
  - 1-20x: 0.5% MMR
  - 21-50x: 1.0% MMR
  - 51-100x: 2.0% MMR
  - 101-125x: 4.0% MMR
*/

-- Trading Pairs Configuration Table
CREATE TABLE IF NOT EXISTS trading_pairs_config (
  pair text PRIMARY KEY,
  max_leverage integer NOT NULL DEFAULT 25,
  maker_fee numeric(10,6) NOT NULL DEFAULT 0.0002,
  taker_fee numeric(10,6) NOT NULL DEFAULT 0.0004,
  liquidation_fee numeric(10,6) NOT NULL DEFAULT 0.004,
  min_order_size numeric(20,8) NOT NULL DEFAULT 0.001,
  max_position_size numeric(20,8) NOT NULL DEFAULT 1000,
  pair_type text NOT NULL DEFAULT 'altcoin',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (pair_type IN ('major', 'altcoin', 'lowcap')),
  CHECK (max_leverage >= 1 AND max_leverage <= 125),
  CHECK (maker_fee >= 0),
  CHECK (taker_fee >= 0),
  CHECK (liquidation_fee >= 0)
);

-- Leverage Tiers Table
CREATE TABLE IF NOT EXISTS leverage_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_name text NOT NULL UNIQUE,
  min_leverage integer NOT NULL,
  max_leverage integer NOT NULL,
  maintenance_margin_rate numeric(10,6) NOT NULL,
  insurance_buffer numeric(10,6) NOT NULL DEFAULT 0.0005,
  created_at timestamptz DEFAULT now(),
  CHECK (min_leverage >= 1),
  CHECK (max_leverage >= min_leverage),
  CHECK (maintenance_margin_rate > 0 AND maintenance_margin_rate < 1),
  CHECK (insurance_buffer >= 0)
);

-- User Leverage Limits Table
CREATE TABLE IF NOT EXISTS user_leverage_limits (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  max_allowed_leverage integer NOT NULL DEFAULT 20,
  updated_at timestamptz DEFAULT now(),
  CHECK (max_allowed_leverage >= 1 AND max_allowed_leverage <= 125)
);

-- Enable RLS
ALTER TABLE trading_pairs_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE leverage_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_leverage_limits ENABLE ROW LEVEL SECURITY;

-- Policies for trading_pairs_config (public read)
CREATE POLICY "Anyone can view trading pairs config"
  ON trading_pairs_config FOR SELECT
  TO authenticated
  USING (true);

-- Policies for leverage_tiers (public read)
CREATE POLICY "Anyone can view leverage tiers"
  ON leverage_tiers FOR SELECT
  TO authenticated
  USING (true);

-- Policies for user_leverage_limits
CREATE POLICY "Users can view own leverage limits"
  ON user_leverage_limits FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trading_pairs_active ON trading_pairs_config(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_trading_pairs_type ON trading_pairs_config(pair_type);
CREATE INDEX IF NOT EXISTS idx_leverage_tiers_range ON leverage_tiers(min_leverage, max_leverage);

-- Insert default trading pairs configuration
INSERT INTO trading_pairs_config (pair, max_leverage, pair_type, min_order_size, max_position_size)
VALUES
  ('BTCUSDT', 125, 'major', 0.001, 100),
  ('ETHUSDT', 100, 'major', 0.01, 1000),
  ('BNBUSDT', 50, 'altcoin', 0.1, 10000),
  ('XRPUSDT', 50, 'altcoin', 10, 1000000),
  ('SOLUSDT', 50, 'altcoin', 0.1, 10000),
  ('ADAUSDT', 25, 'altcoin', 10, 1000000),
  ('DOGEUSDT', 25, 'altcoin', 100, 10000000),
  ('MATICUSDT', 25, 'altcoin', 10, 1000000),
  ('DOTUSDT', 25, 'altcoin', 1, 100000),
  ('LINKUSDT', 25, 'altcoin', 1, 100000),
  ('AVAXUSDT', 25, 'altcoin', 0.1, 10000),
  ('UNIUSDT', 25, 'altcoin', 1, 100000),
  ('ATOMUSDT', 25, 'altcoin', 1, 100000),
  ('LTCUSDT', 25, 'altcoin', 0.1, 10000),
  ('ETCUSDT', 25, 'altcoin', 0.1, 10000)
ON CONFLICT (pair) DO NOTHING;

-- Insert leverage tier configuration
INSERT INTO leverage_tiers (tier_name, min_leverage, max_leverage, maintenance_margin_rate)
VALUES
  ('Tier 1', 1, 20, 0.005),
  ('Tier 2', 21, 50, 0.01),
  ('Tier 3', 51, 100, 0.02),
  ('Tier 4', 101, 125, 0.04)
ON CONFLICT (tier_name) DO NOTHING;

-- Function to auto-create user leverage limits based on KYC level
CREATE OR REPLACE FUNCTION set_user_leverage_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_kyc_level integer;
  v_max_leverage integer;
BEGIN
  -- Get user's KYC level
  SELECT kyc_level INTO v_kyc_level
  FROM user_profiles
  WHERE id = NEW.id;

  -- Determine max leverage based on KYC level
  -- 0 (unverified): 20x, 1 (basic): 50x, 2 (verified): 125x
  v_max_leverage := CASE
    WHEN v_kyc_level >= 2 THEN 125
    WHEN v_kyc_level = 1 THEN 50
    ELSE 20
  END;

  -- Insert or update leverage limit
  INSERT INTO user_leverage_limits (user_id, max_allowed_leverage)
  VALUES (NEW.id, v_max_leverage)
  ON CONFLICT (user_id) DO UPDATE
  SET max_allowed_leverage = v_max_leverage,
      updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-set leverage limits for new users
CREATE TRIGGER on_user_profile_created
  AFTER INSERT ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION set_user_leverage_limit();

-- Trigger to update leverage limits when KYC level changes
CREATE TRIGGER on_kyc_level_updated
  AFTER UPDATE OF kyc_level ON user_profiles
  FOR EACH ROW
  WHEN (OLD.kyc_level IS DISTINCT FROM NEW.kyc_level)
  EXECUTE FUNCTION set_user_leverage_limit();