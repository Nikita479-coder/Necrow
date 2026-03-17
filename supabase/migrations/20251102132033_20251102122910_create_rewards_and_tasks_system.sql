/*
  # Create Rewards and Tasks System
  
  1. New Tables
    - `user_rewards`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `task_type` (text) - Type of task/bonus earned
      - `amount` (numeric) - Reward amount in USDT
      - `status` (text) - pending, claimed, expired
      - `trading_volume` (numeric) - Trading volume achieved
      - `created_at` (timestamp)
      - `claimed_at` (timestamp)
      
    - `user_tasks_progress`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `task_id` (text) - Unique task identifier
      - `current_progress` (numeric) - Current progress value
      - `target_progress` (numeric) - Target value to complete
      - `completed` (boolean) - Task completion status
      - `updated_at` (timestamp)
      
    - `referral_stats`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `vip_level` (integer) - Current VIP level (1-6)
      - `total_volume_30d` (numeric) - 30-day trading volume
      - `total_referrals` (integer) - Total number of referrals
      - `total_earnings` (numeric) - Total commission earned
      - `updated_at` (timestamp)
      
  2. Security
    - Enable RLS on all tables
    - Add policies for users to read/update their own data only
*/

CREATE TABLE IF NOT EXISTS user_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  task_type text NOT NULL,
  amount numeric(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  trading_volume numeric(15,2),
  created_at timestamptz DEFAULT now(),
  claimed_at timestamptz,
  CHECK (status IN ('pending', 'claimed', 'expired'))
);

CREATE TABLE IF NOT EXISTS user_tasks_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  task_id text NOT NULL,
  current_progress numeric(15,2) DEFAULT 0,
  target_progress numeric(15,2) NOT NULL,
  completed boolean DEFAULT false,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, task_id)
);

CREATE TABLE IF NOT EXISTS referral_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  vip_level integer DEFAULT 1,
  total_volume_30d numeric(15,2) DEFAULT 0,
  total_referrals integer DEFAULT 0,
  total_earnings numeric(10,2) DEFAULT 0,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id),
  CHECK (vip_level >= 1 AND vip_level <= 6)
);

ALTER TABLE user_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_tasks_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own rewards"
  ON user_rewards
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own rewards"
  ON user_rewards
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own rewards"
  ON user_rewards
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own task progress"
  ON user_tasks_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own task progress"
  ON user_tasks_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own task progress"
  ON user_tasks_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own referral stats"
  ON referral_stats
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own referral stats"
  ON referral_stats
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert own referral stats"
  ON referral_stats
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_user_rewards_user_id ON user_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_user_rewards_status ON user_rewards(status);
CREATE INDEX IF NOT EXISTS idx_user_tasks_progress_user_id ON user_tasks_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_stats_user_id ON referral_stats(user_id);