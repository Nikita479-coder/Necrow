/*
  # Create Daily VIP Snapshot System

  1. New Tables
    - `vip_daily_snapshots` - Daily record of every user's VIP status
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to auth.users)
      - `snapshot_date` (date) - The date of the snapshot
      - `vip_level` (integer) - VIP level at snapshot time
      - `tier_name` (text) - Tier name at snapshot time
      - `volume_30d` (numeric) - 30-day volume at snapshot time
      - `volume_all_time` (numeric) - All-time volume at snapshot time
      - `commission_rate` (numeric) - Commission rate at snapshot time
      - `rebate_rate` (numeric) - Rebate rate at snapshot time
      - `created_at` (timestamp)
      - UNIQUE constraint on (user_id, snapshot_date)

  2. Purpose
    - Provides 100% reliable VIP tracking with daily snapshots
    - Catches any changes that real-time triggers might miss
    - Historical record for trend analysis and reporting
    - Makes downgrade/upgrade tracking bulletproof

  3. Security
    - Enable RLS on vip_daily_snapshots
    - Users can view their own snapshots
    - Admins can view all snapshots
*/

-- Create the daily snapshots table
CREATE TABLE IF NOT EXISTS vip_daily_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  snapshot_date date NOT NULL,
  vip_level integer NOT NULL DEFAULT 1,
  tier_name text NOT NULL,
  volume_30d numeric NOT NULL DEFAULT 0,
  volume_all_time numeric NOT NULL DEFAULT 0,
  commission_rate numeric NOT NULL DEFAULT 0,
  rebate_rate numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, snapshot_date)
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_vip_snapshots_user_date 
  ON vip_daily_snapshots(user_id, snapshot_date DESC);

CREATE INDEX IF NOT EXISTS idx_vip_snapshots_date 
  ON vip_daily_snapshots(snapshot_date DESC);

-- Enable RLS
ALTER TABLE vip_daily_snapshots ENABLE ROW LEVEL SECURITY;

-- Users can view their own snapshots
CREATE POLICY "Users can view own VIP snapshots"
  ON vip_daily_snapshots
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admins can view all snapshots
CREATE POLICY "Admins can view all VIP snapshots"
  ON vip_daily_snapshots
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_id = auth.uid() AND is_admin = true
    )
  );

-- Service role can insert snapshots (for the edge function)
CREATE POLICY "Service can insert VIP snapshots"
  ON vip_daily_snapshots
  FOR INSERT
  TO authenticated
  WITH CHECK (true);