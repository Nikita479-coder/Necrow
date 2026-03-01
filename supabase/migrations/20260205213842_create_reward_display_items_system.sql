/*
  # Create Reward Display Items System

  1. New Tables
    - `reward_display_items`
      - `id` (uuid, primary key)
      - `title` (text) - display name shown to users
      - `description` (text) - user-facing description
      - `reward_amount` (numeric) - displayed USDT reward value
      - `reward_type` (text) - 'fee_rebate', 'balance', or 'locked_bonus'
      - `icon` (text) - emoji icon for display
      - `external_link` (text, nullable) - optional URL for external tasks
      - `sort_order` (integer) - controls display ordering
      - `is_active` (boolean) - toggle visibility without deleting
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `reward_display_items` table
    - Authenticated users can read active items
    - Admin-only insert, update, delete policies

  3. Seed Data
    - Pre-populated with current hardcoded reward tasks
*/

CREATE TABLE IF NOT EXISTS reward_display_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  reward_amount numeric NOT NULL DEFAULT 0,
  reward_type text NOT NULL DEFAULT 'locked_bonus',
  icon text NOT NULL DEFAULT '🎁',
  external_link text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reward_display_items_reward_type_check CHECK (reward_type IN ('fee_rebate', 'balance', 'locked_bonus'))
);

ALTER TABLE reward_display_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view active reward display items"
  ON reward_display_items
  FOR SELECT
  TO authenticated
  USING (is_active = true);

CREATE POLICY "Admins can insert reward display items"
  ON reward_display_items
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Admins can update reward display items"
  ON reward_display_items
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Admins can delete reward display items"
  ON reward_display_items
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

INSERT INTO reward_display_items (title, description, reward_amount, reward_type, icon, external_link, sort_order, is_active) VALUES
  ('KYC Verification Bonus', 'Complete identity verification to earn $20 USDT locked trading bonus', 20, 'locked_bonus', '🛡️', '/kyc', 1, true),
  ('TrustPilot Review Bonus', 'Leave a TrustPilot review and earn $5 USDT locked trading bonus', 5, 'locked_bonus', '⭐', '/review-bonus', 2, true),
  ('First Referral Bonus', 'Bring your first active trader onboard - requires $100+ deposit', 5, 'balance', '✨', NULL, 3, true),
  ('Growing Network Bonus', 'Invite 5 friends who each deposit $100+ to qualify', 25, 'balance', '🌱', NULL, 4, true),
  ('Network Champion Bonus', 'Invite 10 friends who each deposit $100+ to qualify', 70, 'balance', '🏆', NULL, 5, true),
  ('First Trade Welcome', 'Complete your first futures trade', 3, 'fee_rebate', '🎯', NULL, 6, true),
  ('Download Mobile App', 'Get the Shark Trades mobile app and trade on the go', 3, 'locked_bonus', '📱', 'https://play.google.com/store/apps/details?id=com.sharktrading.app', 7, true),
  ('Copy Trading Bonus', 'Start copy trading with 500+ USDT to get 100 USDT added on top. Keep everything after 30 days!', 100, 'locked_bonus', '🚀', NULL, 8, true),
  ('Million Dollar Club', 'Trade $10,000,000 in volume within 30 days', 500, 'fee_rebate', '🏆', NULL, 9, true);
