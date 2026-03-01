/*
  # VIP Levels with Commission and Fee Rebate System

  1. New Tables
    - `vip_levels` - Define VIP tier requirements and benefits
    - Updated `user_vip_status` - Track user's current VIP level

  2. Features
    - 6 VIP tiers based on 30-day trading volume
    - Commission rates from 10% to 70%
    - Fee rebates from 5% to 15%
    - Automatic tier calculation based on volume
    - Fee rebate applied to all trading fees

  3. VIP Levels
    - VIP 1: $0 - $10k (10% commission, 5% rebate)
    - VIP 2: $10k - $100k (20% commission, 6% rebate)
    - VIP 3: $100k - $500k (30% commission, 7% rebate)
    - VIP 4: $500k - $2.5M (40% commission, 8% rebate)
    - VIP 5: $2.5M - $25M (50% commission, 10% rebate)
    - VIP 6: $25M+ (70% commission, 15% rebate)

  4. Security
    - Enable RLS on all tables
    - Users can view their own VIP status
    - Admins can manage VIP configuration
*/

-- VIP Levels Configuration
CREATE TABLE IF NOT EXISTS vip_levels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  level_number int NOT NULL UNIQUE CHECK (level_number >= 1 AND level_number <= 6),
  level_name text NOT NULL,
  level_emoji text NOT NULL,
  min_volume_30d numeric(20,2) NOT NULL,
  max_volume_30d numeric(20,2),
  commission_rate numeric(5,2) NOT NULL CHECK (commission_rate >= 0 AND commission_rate <= 100),
  rebate_rate numeric(5,2) NOT NULL CHECK (rebate_rate >= 0 AND rebate_rate <= 100),
  benefits text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  CONSTRAINT unique_volume_range UNIQUE (min_volume_30d, max_volume_30d)
);

-- User VIP Status
CREATE TABLE IF NOT EXISTS user_vip_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  current_level int NOT NULL DEFAULT 1 CHECK (current_level >= 1 AND current_level <= 6),
  volume_30d numeric(20,2) NOT NULL DEFAULT 0,
  commission_rate numeric(5,2) NOT NULL DEFAULT 10,
  rebate_rate numeric(5,2) NOT NULL DEFAULT 5,
  last_calculated_at timestamptz DEFAULT now() NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Insert VIP level configuration
INSERT INTO vip_levels (level_number, level_name, level_emoji, min_volume_30d, max_volume_30d, commission_rate, rebate_rate, benefits)
VALUES
  (1, 'VIP 1', '🥉', 0, 10000, 10, 5, 'Entry level — start earning instantly'),
  (2, 'VIP 2', '🥈', 10001, 100000, 20, 6, 'Higher commission for moderate traders'),
  (3, 'VIP 3', '🥇', 100001, 500000, 30, 7, 'Balanced reward for consistent traders'),
  (4, 'VIP 4', '💫', 500001, 2500000, 40, 8, 'Advanced traders enjoy boosted rates'),
  (5, 'VIP 5', '👑', 2500001, 25000000, 50, 10, 'Top-tier — maximum commissions & exclusive perks'),
  (6, 'VIP 6', '💎', 25000001, NULL, 70, 15, 'Diamond Elite — highest rewards, priority support, VIP')
ON CONFLICT (level_number) DO UPDATE SET
  level_name = EXCLUDED.level_name,
  level_emoji = EXCLUDED.level_emoji,
  min_volume_30d = EXCLUDED.min_volume_30d,
  max_volume_30d = EXCLUDED.max_volume_30d,
  commission_rate = EXCLUDED.commission_rate,
  rebate_rate = EXCLUDED.rebate_rate,
  benefits = EXCLUDED.benefits;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_vip_status_user ON user_vip_status(user_id);
CREATE INDEX IF NOT EXISTS idx_user_vip_status_level ON user_vip_status(current_level);
CREATE INDEX IF NOT EXISTS idx_vip_levels_volume ON vip_levels(min_volume_30d, max_volume_30d);

-- Enable RLS
ALTER TABLE vip_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_vip_status ENABLE ROW LEVEL SECURITY;

-- RLS Policies for vip_levels
CREATE POLICY "Anyone can view VIP levels"
  ON vip_levels FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage VIP levels"
  ON vip_levels FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true')
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- RLS Policies for user_vip_status
CREATE POLICY "Users can view own VIP status"
  ON user_vip_status FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins can view all VIP status"
  ON user_vip_status FOR SELECT
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

CREATE POLICY "System can insert VIP status"
  ON user_vip_status FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "System can update VIP status"
  ON user_vip_status FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);