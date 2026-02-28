/*
  # CRM Enhancement System
  
  This migration creates comprehensive CRM features for advanced user management.
  
  ## 1. New Tables
  
  ### `user_notes`
  - Internal admin notes and comments about users
  - `id` (uuid, primary key)
  - `user_id` (uuid, references auth.users)
  - `admin_id` (uuid, references auth.users)
  - `note_type` (text) - general, warning, important, follow_up
  - `content` (text) - the note content
  - `is_pinned` (boolean) - pinned notes show at top
  - `created_at`, `updated_at` (timestamptz)
  
  ### `user_segments`
  - Saved user segments for targeting
  - `id` (uuid, primary key)
  - `name` (text) - segment name
  - `description` (text)
  - `filter_criteria` (jsonb) - filter rules
  - `user_count` (integer) - cached count
  - `is_dynamic` (boolean) - auto-updates vs static
  - `created_by` (uuid)
  - `created_at`, `updated_at`
  
  ### `user_segment_members`
  - Static segment membership (for non-dynamic segments)
  - `segment_id` (uuid)
  - `user_id` (uuid)
  - `added_at` (timestamptz)
  
  ### `saved_filters`
  - Admin saved filter presets
  - `id` (uuid, primary key)
  - `admin_id` (uuid)
  - `name` (text)
  - `filter_config` (jsonb)
  - `is_shared` (boolean)
  - `created_at`
  
  ### `user_tags`
  - Custom tags for users
  - `id` (uuid, primary key)
  - `name` (text)
  - `color` (text)
  - `description` (text)
  - `created_by` (uuid)
  
  ### `user_tag_assignments`
  - Links tags to users
  - `user_id` (uuid)
  - `tag_id` (uuid)
  - `assigned_by` (uuid)
  - `assigned_at` (timestamptz)
  
  ### `bulk_action_logs`
  - Track bulk operations
  - `id` (uuid, primary key)
  - `admin_id` (uuid)
  - `action_type` (text)
  - `affected_users` (integer)
  - `details` (jsonb)
  - `created_at`
  
  ### `crm_analytics_snapshots`
  - Daily analytics snapshots for trends
  - `id` (uuid, primary key)
  - `snapshot_date` (date)
  - `metrics` (jsonb)
  - `created_at`
  
  ## 2. Security
  - RLS enabled on all tables
  - Admin-only access policies
*/

-- User Notes Table
CREATE TABLE IF NOT EXISTS user_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  admin_id uuid NOT NULL REFERENCES auth.users(id),
  note_type text NOT NULL DEFAULT 'general' CHECK (note_type IN ('general', 'warning', 'important', 'follow_up', 'support', 'compliance')),
  content text NOT NULL,
  is_pinned boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage user notes"
  ON user_notes FOR ALL
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

-- User Tags Table
CREATE TABLE IF NOT EXISTS user_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  color text NOT NULL DEFAULT '#3b82f6',
  description text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE user_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage user tags"
  ON user_tags FOR ALL
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

-- User Tag Assignments Table
CREATE TABLE IF NOT EXISTS user_tag_assignments (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES user_tags(id) ON DELETE CASCADE,
  assigned_by uuid REFERENCES auth.users(id),
  assigned_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, tag_id)
);

ALTER TABLE user_tag_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage tag assignments"
  ON user_tag_assignments FOR ALL
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

-- User Segments Table
CREATE TABLE IF NOT EXISTS user_segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  filter_criteria jsonb NOT NULL DEFAULT '{}',
  user_count integer DEFAULT 0,
  is_dynamic boolean DEFAULT true,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE user_segments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage segments"
  ON user_segments FOR ALL
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

-- Static Segment Members
CREATE TABLE IF NOT EXISTS user_segment_members (
  segment_id uuid NOT NULL REFERENCES user_segments(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at timestamptz DEFAULT now(),
  added_by uuid REFERENCES auth.users(id),
  PRIMARY KEY (segment_id, user_id)
);

ALTER TABLE user_segment_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage segment members"
  ON user_segment_members FOR ALL
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

-- Saved Filters Table
CREATE TABLE IF NOT EXISTS saved_filters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES auth.users(id),
  name text NOT NULL,
  filter_config jsonb NOT NULL DEFAULT '{}',
  filter_type text NOT NULL DEFAULT 'users' CHECK (filter_type IN ('users', 'transactions', 'trades', 'support')),
  is_shared boolean DEFAULT false,
  use_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE saved_filters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view shared filters or own filters"
  ON saved_filters FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
    AND (is_shared = true OR admin_id = auth.uid())
  );

CREATE POLICY "Admins can manage own filters"
  ON saved_filters FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
    AND admin_id = auth.uid()
  );

CREATE POLICY "Admins can update own filters"
  ON saved_filters FOR UPDATE
  TO authenticated
  USING (admin_id = auth.uid())
  WITH CHECK (admin_id = auth.uid());

CREATE POLICY "Admins can delete own filters"
  ON saved_filters FOR DELETE
  TO authenticated
  USING (admin_id = auth.uid());

-- Bulk Action Logs Table
CREATE TABLE IF NOT EXISTS bulk_action_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL REFERENCES auth.users(id),
  action_type text NOT NULL,
  affected_user_count integer NOT NULL DEFAULT 0,
  affected_user_ids uuid[] DEFAULT '{}',
  details jsonb DEFAULT '{}',
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'in_progress', 'completed', 'failed')),
  error_message text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE bulk_action_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view bulk action logs"
  ON bulk_action_logs FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

CREATE POLICY "Admins can create bulk action logs"
  ON bulk_action_logs FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
    AND admin_id = auth.uid()
  );

-- CRM Analytics Snapshots
CREATE TABLE IF NOT EXISTS crm_analytics_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL UNIQUE,
  total_users integer DEFAULT 0,
  active_users_24h integer DEFAULT 0,
  active_users_7d integer DEFAULT 0,
  new_users integer DEFAULT 0,
  total_deposits numeric(20, 8) DEFAULT 0,
  total_withdrawals numeric(20, 8) DEFAULT 0,
  total_trading_volume numeric(20, 8) DEFAULT 0,
  total_fees_collected numeric(20, 8) DEFAULT 0,
  kyc_pending_count integer DEFAULT 0,
  kyc_verified_count integer DEFAULT 0,
  support_tickets_open integer DEFAULT 0,
  avg_user_balance numeric(20, 8) DEFAULT 0,
  metrics jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

ALTER TABLE crm_analytics_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view analytics snapshots"
  ON crm_analytics_snapshots FOR ALL
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

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_notes_user_id ON user_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notes_admin_id ON user_notes(admin_id);
CREATE INDEX IF NOT EXISTS idx_user_notes_created_at ON user_notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_tag_assignments_user_id ON user_tag_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tag_assignments_tag_id ON user_tag_assignments(tag_id);
CREATE INDEX IF NOT EXISTS idx_user_segments_is_active ON user_segments(is_active);
CREATE INDEX IF NOT EXISTS idx_saved_filters_admin_id ON saved_filters(admin_id);
CREATE INDEX IF NOT EXISTS idx_saved_filters_is_shared ON saved_filters(is_shared);
CREATE INDEX IF NOT EXISTS idx_bulk_action_logs_admin_id ON bulk_action_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_bulk_action_logs_created_at ON bulk_action_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_crm_analytics_snapshots_date ON crm_analytics_snapshots(snapshot_date DESC);

-- Insert default tags
INSERT INTO user_tags (name, color, description) VALUES
  ('VIP', '#f0b90b', 'VIP customer requiring priority support'),
  ('High Value', '#10b981', 'High balance or high volume trader'),
  ('At Risk', '#ef4444', 'User showing signs of churn'),
  ('New User', '#3b82f6', 'Recently registered user'),
  ('Whale', '#8b5cf6', 'Very large balance holder'),
  ('Active Trader', '#06b6d4', 'Frequent trading activity'),
  ('Dormant', '#6b7280', 'Inactive for extended period'),
  ('KYC Pending', '#f59e0b', 'Awaiting KYC verification'),
  ('Compliance Review', '#dc2626', 'Under compliance review'),
  ('Referrer', '#22c55e', 'Has referred other users')
ON CONFLICT (name) DO NOTHING;

-- Insert default segments
INSERT INTO user_segments (name, description, filter_criteria, is_dynamic) VALUES
  ('High Balance Users', 'Users with total balance over $10,000', '{"minBalance": 10000}', true),
  ('New Users (7 Days)', 'Users registered in the last 7 days', '{"registeredWithinDays": 7}', true),
  ('Inactive Users', 'Users with no activity in 30 days', '{"inactiveDays": 30}', true),
  ('VIP Tier Users', 'Users in VIP tiers', '{"vipTiers": ["Bronze", "Silver", "Gold", "Platinum", "Diamond"]}', true),
  ('KYC Verified', 'Users with verified KYC', '{"kycStatus": "verified"}', true),
  ('Active Traders', 'Users with trades in last 7 days', '{"tradedWithinDays": 7}', true),
  ('Copy Trading Users', 'Users using copy trading', '{"hasCopyTrading": true}', true),
  ('High Volume Traders', 'Users with $100k+ monthly volume', '{"minMonthlyVolume": 100000}', true)
ON CONFLICT DO NOTHING;