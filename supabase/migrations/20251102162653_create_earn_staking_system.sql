/*
  # Create Earn/Staking System

  ## Summary
  This migration creates the comprehensive earn/staking system for the crypto platform.

  ## New Tables
  
  ### `earn_products`
  Stores available staking/earning products
  - `id` (uuid, primary key)
  - `coin` (text) - Cryptocurrency symbol
  - `product_type` (text) - Type: 'flexible' or 'fixed'
  - `apr` (numeric) - Annual percentage rate
  - `duration_days` (integer) - Lock period in days (0 for flexible)
  - `min_amount` (numeric) - Minimum investment amount
  - `max_amount` (numeric, nullable) - Maximum investment amount
  - `total_cap` (numeric) - Total pool capacity
  - `invested_amount` (numeric) - Currently invested amount
  - `is_active` (boolean) - Product availability status
  - `is_featured` (boolean) - Show in featured section
  - `badge` (text, nullable) - Special badge text
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `user_stakes`
  Tracks user investments in earn products
  - `id` (uuid, primary key)
  - `user_id` (uuid, foreign key)
  - `product_id` (uuid, foreign key)
  - `amount` (numeric) - Staked amount
  - `apr_locked` (numeric) - APR locked in at investment time
  - `start_date` (timestamptz)
  - `end_date` (timestamptz, nullable)
  - `status` (text) - 'active', 'completed', 'redeemed'
  - `earned_rewards` (numeric) - Total rewards earned
  - `last_reward_date` (timestamptz)
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `stake_rewards`
  Records daily reward distributions
  - `id` (uuid, primary key)
  - `stake_id` (uuid, foreign key)
  - `amount` (numeric) - Reward amount
  - `reward_date` (timestamptz)
  - `created_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Users can read all active earn products
  - Users can view and manage only their own stakes
  - Only system can create earn products and distribute rewards
*/

-- Create earn_products table
CREATE TABLE IF NOT EXISTS earn_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coin text NOT NULL,
  product_type text NOT NULL CHECK (product_type IN ('flexible', 'fixed')),
  apr numeric NOT NULL CHECK (apr >= 0),
  duration_days integer NOT NULL DEFAULT 0 CHECK (duration_days >= 0),
  min_amount numeric NOT NULL DEFAULT 0 CHECK (min_amount >= 0),
  max_amount numeric CHECK (max_amount IS NULL OR max_amount > min_amount),
  total_cap numeric NOT NULL CHECK (total_cap > 0),
  invested_amount numeric NOT NULL DEFAULT 0 CHECK (invested_amount >= 0),
  is_active boolean DEFAULT true,
  is_featured boolean DEFAULT false,
  badge text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create user_stakes table
CREATE TABLE IF NOT EXISTS user_stakes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES earn_products(id) ON DELETE RESTRICT,
  amount numeric NOT NULL CHECK (amount > 0),
  apr_locked numeric NOT NULL CHECK (apr_locked >= 0),
  start_date timestamptz NOT NULL DEFAULT now(),
  end_date timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'redeemed')),
  earned_rewards numeric NOT NULL DEFAULT 0 CHECK (earned_rewards >= 0),
  last_reward_date timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create stake_rewards table
CREATE TABLE IF NOT EXISTS stake_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stake_id uuid NOT NULL REFERENCES user_stakes(id) ON DELETE CASCADE,
  amount numeric NOT NULL CHECK (amount > 0),
  reward_date timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_earn_products_active ON earn_products(is_active, is_featured);
CREATE INDEX IF NOT EXISTS idx_user_stakes_user ON user_stakes(user_id, status);
CREATE INDEX IF NOT EXISTS idx_stake_rewards_stake ON stake_rewards(stake_id, reward_date);

-- Enable RLS
ALTER TABLE earn_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stakes ENABLE ROW LEVEL SECURITY;
ALTER TABLE stake_rewards ENABLE ROW LEVEL SECURITY;

-- RLS Policies for earn_products
CREATE POLICY "Anyone can view active earn products"
  ON earn_products
  FOR SELECT
  USING (is_active = true);

-- RLS Policies for user_stakes
CREATE POLICY "Users can view own stakes"
  ON user_stakes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stakes"
  ON user_stakes
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own stakes"
  ON user_stakes
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS Policies for stake_rewards
CREATE POLICY "Users can view own stake rewards"
  ON stake_rewards
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_stakes
      WHERE user_stakes.id = stake_rewards.stake_id
      AND user_stakes.user_id = auth.uid()
    )
  );

-- Insert sample earn products
INSERT INTO earn_products (coin, product_type, apr, duration_days, min_amount, total_cap, invested_amount, is_featured, badge) VALUES
('BTC', 'flexible', 2.30, 0, 0.0001, 1000, 0, false, NULL),
('BTC', 'fixed', 0.30, 30, 0.0001, 100, 0, false, NULL),
('ETH', 'flexible', 0.80, 0, 0.001, 5000, 0, false, NULL),
('USDT', 'flexible', 555.00, 0, 10, 300000, 31262.27, true, 'New Users: Earn 555% APR in MNT+BNB'),
('USDT', 'fixed', 555.00, 2, 10, 2000000, 173397.29, true, 'Earn New User Exclusive'),
('BNB', 'flexible', 8.50, 0, 0.01, 10000, 0, false, NULL),
('SOL', 'flexible', 5.20, 0, 0.01, 5000, 0, false, NULL),
('USDC', 'flexible', 6.80, 0, 10, 500000, 0, false, NULL),
('DAI', 'flexible', 5.00, 0, 10, 300000, 0, false, NULL),
('EAT', 'flexible', 100.00, 0, 1, 2400000, 319674.92, true, 'EAT Earnings Boost'),
('EAT', 'fixed', 450.00, 3, 1, 2700000, 69609.41, true, 'Earn New User Exclusive')
ON CONFLICT DO NOTHING;
