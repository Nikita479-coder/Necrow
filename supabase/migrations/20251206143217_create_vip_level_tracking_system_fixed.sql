/*
  # VIP Level Tracking System

  ## Description
  Comprehensive VIP tier change tracking system that monitors daily VIP level changes,
  detects downgrades, and enables targeted retention campaigns.

  ## Tables Created
  1. vip_level_history - Complete history of all VIP level changes
  2. vip_tier_downgrades - Tracks downgrades requiring action
  3. vip_retention_campaigns - Campaign tracking for retention bonuses

  ## Features
  - Automatic VIP change detection
  - Downgrade alerts
  - Campaign management
  - Bonus and email tracking
*/

-- Table to track complete VIP level history
CREATE TABLE IF NOT EXISTS vip_level_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
  previous_level integer NOT NULL,
  new_level integer NOT NULL,
  previous_tier_name text,
  new_tier_name text,
  change_type text CHECK (change_type IN ('upgrade', 'downgrade', 'maintained')) NOT NULL,
  volume_30d numeric DEFAULT 0,
  reason text,
  changed_at timestamptz DEFAULT NOW(),
  created_at timestamptz DEFAULT NOW()
);

-- Table to track VIP downgrades that need action
CREATE TABLE IF NOT EXISTS vip_tier_downgrades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
  previous_level integer NOT NULL,
  new_level integer NOT NULL,
  previous_tier_name text NOT NULL,
  new_tier_name text NOT NULL,
  tier_difference integer NOT NULL,
  volume_30d numeric DEFAULT 0,
  status text CHECK (status IN ('pending', 'bonus_sent', 'email_sent', 'completed', 'ignored')) DEFAULT 'pending',
  bonus_amount numeric,
  bonus_currency text DEFAULT 'USDT',
  email_sent boolean DEFAULT false,
  email_sent_at timestamptz,
  bonus_sent boolean DEFAULT false,
  bonus_sent_at timestamptz,
  admin_notes text,
  detected_at timestamptz DEFAULT NOW(),
  actioned_at timestamptz,
  actioned_by uuid REFERENCES user_profiles(id),
  created_at timestamptz DEFAULT NOW(),
  updated_at timestamptz DEFAULT NOW()
);

-- Table to track VIP retention campaigns
CREATE TABLE IF NOT EXISTS vip_retention_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_name text NOT NULL,
  description text,
  tier_drop_from integer,
  tier_drop_to integer,
  bonus_amount numeric NOT NULL,
  bonus_currency text DEFAULT 'USDT',
  email_template_id uuid REFERENCES email_templates(id),
  is_active boolean DEFAULT true,
  auto_send_bonus boolean DEFAULT false,
  auto_send_email boolean DEFAULT false,
  users_eligible integer DEFAULT 0,
  bonuses_sent integer DEFAULT 0,
  emails_sent integer DEFAULT 0,
  total_bonus_value numeric DEFAULT 0,
  created_by uuid REFERENCES user_profiles(id),
  created_at timestamptz DEFAULT NOW(),
  updated_at timestamptz DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_vip_history_user_id ON vip_level_history(user_id);
CREATE INDEX IF NOT EXISTS idx_vip_history_changed_at ON vip_level_history(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_vip_history_change_type ON vip_level_history(change_type);

CREATE INDEX IF NOT EXISTS idx_vip_downgrades_user_id ON vip_tier_downgrades(user_id);
CREATE INDEX IF NOT EXISTS idx_vip_downgrades_status ON vip_tier_downgrades(status);
CREATE INDEX IF NOT EXISTS idx_vip_downgrades_detected_at ON vip_tier_downgrades(detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_vip_campaigns_active ON vip_retention_campaigns(is_active);

-- RLS Policies
ALTER TABLE vip_level_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE vip_tier_downgrades ENABLE ROW LEVEL SECURITY;
ALTER TABLE vip_retention_campaigns ENABLE ROW LEVEL SECURITY;

-- Admin read policies
CREATE POLICY "Admins can view VIP history"
  ON vip_level_history FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND (auth.jwt()->>'user_metadata')::jsonb->>'is_admin' = 'true'
    )
  );

CREATE POLICY "Admins can view VIP downgrades"
  ON vip_tier_downgrades FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND (auth.jwt()->>'user_metadata')::jsonb->>'is_admin' = 'true'
    )
  );

CREATE POLICY "Admins can manage VIP downgrades"
  ON vip_tier_downgrades FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND (auth.jwt()->>'user_metadata')::jsonb->>'is_admin' = 'true'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND (auth.jwt()->>'user_metadata')::jsonb->>'is_admin' = 'true'
    )
  );

CREATE POLICY "Admins can view campaigns"
  ON vip_retention_campaigns FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND (auth.jwt()->>'user_metadata')::jsonb->>'is_admin' = 'true'
    )
  );

CREATE POLICY "Admins can manage campaigns"
  ON vip_retention_campaigns FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND (auth.jwt()->>'user_metadata')::jsonb->>'is_admin' = 'true'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND (auth.jwt()->>'user_metadata')::jsonb->>'is_admin' = 'true'
    )
  );

-- Function to get VIP tier name
CREATE OR REPLACE FUNCTION get_vip_tier_name(vip_level integer)
RETURNS text AS $$
BEGIN
  RETURN CASE
    WHEN vip_level = 0 THEN 'Regular'
    WHEN vip_level = 1 THEN 'Bronze'
    WHEN vip_level = 2 THEN 'Silver'
    WHEN vip_level = 3 THEN 'Gold'
    WHEN vip_level = 4 THEN 'Platinum'
    WHEN vip_level = 5 THEN 'Diamond'
    ELSE 'Unknown'
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to track VIP level changes
CREATE OR REPLACE FUNCTION track_vip_level_change()
RETURNS TRIGGER AS $$
DECLARE
  v_previous_level integer;
  v_change_type text;
  v_volume_30d numeric;
BEGIN
  -- Get previous level
  v_previous_level := OLD.current_level;
  
  -- Determine change type
  IF NEW.current_level > OLD.current_level THEN
    v_change_type := 'upgrade';
  ELSIF NEW.current_level < OLD.current_level THEN
    v_change_type := 'downgrade';
  ELSE
    v_change_type := 'maintained';
  END IF;

  -- Get current 30-day volume
  v_volume_30d := COALESCE(NEW.volume_30d, 0);

  -- Insert into history
  INSERT INTO vip_level_history (
    user_id,
    previous_level,
    new_level,
    previous_tier_name,
    new_tier_name,
    change_type,
    volume_30d
  ) VALUES (
    NEW.user_id,
    v_previous_level,
    NEW.current_level,
    get_vip_tier_name(v_previous_level),
    get_vip_tier_name(NEW.current_level),
    v_change_type,
    v_volume_30d
  );

  -- If it's a downgrade, create a downgrade record
  IF v_change_type = 'downgrade' THEN
    INSERT INTO vip_tier_downgrades (
      user_id,
      previous_level,
      new_level,
      previous_tier_name,
      new_tier_name,
      tier_difference,
      volume_30d,
      status
    ) VALUES (
      NEW.user_id,
      v_previous_level,
      NEW.current_level,
      get_vip_tier_name(v_previous_level),
      get_vip_tier_name(NEW.current_level),
      v_previous_level - NEW.current_level,
      v_volume_30d,
      'pending'
    );

    -- Create notification for user
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      is_read
    ) VALUES (
      NEW.user_id,
      'vip_downgrade',
      'VIP Tier Change',
      'Your VIP level has changed from ' || get_vip_tier_name(v_previous_level) || ' to ' || get_vip_tier_name(NEW.current_level) || '. Contact support for exclusive retention offers!',
      false
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Create trigger on user_vip_status
DROP TRIGGER IF EXISTS track_vip_changes ON user_vip_status;
CREATE TRIGGER track_vip_changes
  AFTER UPDATE OF current_level ON user_vip_status
  FOR EACH ROW
  WHEN (OLD.current_level IS DISTINCT FROM NEW.current_level)
  EXECUTE FUNCTION track_vip_level_change();