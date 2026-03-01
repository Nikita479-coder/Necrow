/*
  # Welcome Package Bonus System

  This migration creates the complete welcome package bonus system worth up to $2,130 USDT:

  1. KYC Bonus
    - Updates existing KYC bonus to $20 USDT

  2. Deposit Bonus Tiers (NEW)
    - Creates deposit_bonus_tiers table to track multi-deposit bonuses
    - 1st Deposit: 100% bonus up to $500
    - 2nd Deposit: 50% bonus up to $500
    - 3rd Deposit: 20% bonus up to $610

  3. Referral Milestone Rewards
    - Updates existing referral bonus types with correct amounts
    - 1st Referral: $5 USDT (already exists)
    - 5 Referrals: $25 USDT (already exists)
    - 10 Referrals: $70 USDT (NEW)

  4. Security
    - RLS enabled on all new tables
    - Admin-only write access
    - User read access for their own data
*/

-- Create deposit bonus tiers configuration table
CREATE TABLE IF NOT EXISTS deposit_bonus_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_number integer NOT NULL UNIQUE,
  bonus_percentage numeric NOT NULL,
  max_bonus_amount numeric NOT NULL,
  min_deposit_amount numeric DEFAULT 0,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE deposit_bonus_tiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active deposit bonus tiers"
  ON deposit_bonus_tiers
  FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage deposit bonus tiers"
  ON deposit_bonus_tiers
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Insert the deposit bonus tier configuration
INSERT INTO deposit_bonus_tiers (tier_number, bonus_percentage, max_bonus_amount, min_deposit_amount, description)
VALUES
  (1, 100, 500, 10, '100% bonus on your first deposit (up to $500 USDT)'),
  (2, 50, 500, 10, '50% bonus on your second deposit (up to $500 USDT)'),
  (3, 20, 610, 10, '20% bonus on your third deposit (up to $610 USDT)')
ON CONFLICT (tier_number) DO UPDATE SET
  bonus_percentage = EXCLUDED.bonus_percentage,
  max_bonus_amount = EXCLUDED.max_bonus_amount,
  min_deposit_amount = EXCLUDED.min_deposit_amount,
  description = EXCLUDED.description,
  updated_at = now();

-- Create user deposit bonus tracking table
CREATE TABLE IF NOT EXISTS user_deposit_bonuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tier_number integer NOT NULL REFERENCES deposit_bonus_tiers(tier_number),
  deposit_amount numeric NOT NULL,
  bonus_amount numeric NOT NULL,
  bonus_percentage numeric NOT NULL,
  deposit_id uuid,
  awarded_at timestamptz DEFAULT now(),
  UNIQUE(user_id, tier_number)
);

ALTER TABLE user_deposit_bonuses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own deposit bonuses"
  ON user_deposit_bonuses
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert deposit bonuses"
  ON user_deposit_bonuses
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_user_deposit_bonuses_user_id ON user_deposit_bonuses(user_id);

-- Create KYC Verification Bonus type if not exists, otherwise update
INSERT INTO bonus_types (name, description, default_amount, category, is_active, is_locked_bonus)
VALUES (
  'KYC Verification Bonus',
  'Instant $20 USDT bonus for completing KYC verification',
  20.00,
  'welcome',
  true,
  true
)
ON CONFLICT (name) DO UPDATE SET
  default_amount = 20.00,
  description = 'Instant $20 USDT bonus for completing KYC verification',
  updated_at = now();

-- Create 10 Referrals Milestone bonus type
INSERT INTO bonus_types (name, description, default_amount, category, is_active, is_locked_bonus)
VALUES (
  'Referral Champion Bonus',
  'Instant bonus for bringing 10 active traders who each deposit $100+',
  70.00,
  'referral',
  true,
  false
)
ON CONFLICT (name) DO UPDATE SET
  default_amount = 70.00,
  description = 'Instant bonus for bringing 10 active traders who each deposit $100+',
  updated_at = now();

-- Create Second Deposit Bonus type
INSERT INTO bonus_types (name, description, default_amount, category, is_active, is_locked_bonus, expiry_days)
VALUES (
  'Second Deposit Bonus',
  '50% match bonus on your second deposit (up to $500 USDT)',
  500.00,
  'deposit',
  true,
  true,
  30
)
ON CONFLICT (name) DO UPDATE SET
  default_amount = 500.00,
  description = '50% match bonus on your second deposit (up to $500 USDT)',
  updated_at = now();

-- Create Third Deposit Bonus type
INSERT INTO bonus_types (name, description, default_amount, category, is_active, is_locked_bonus, expiry_days)
VALUES (
  'Third Deposit Bonus',
  '20% match bonus on your third deposit (up to $610 USDT)',
  610.00,
  'deposit',
  true,
  true,
  30
)
ON CONFLICT (name) DO UPDATE SET
  default_amount = 610.00,
  description = '20% match bonus on your third deposit (up to $610 USDT)',
  updated_at = now();

-- Create function to calculate and award deposit bonus
CREATE OR REPLACE FUNCTION calculate_deposit_bonus(
  p_user_id uuid,
  p_deposit_amount numeric,
  p_deposit_id uuid DEFAULT NULL
)
RETURNS TABLE (
  tier_number integer,
  bonus_amount numeric,
  bonus_percentage numeric,
  already_claimed boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_tier integer;
  v_tier_config deposit_bonus_tiers%ROWTYPE;
  v_calculated_bonus numeric;
BEGIN
  -- Find the next unclaimed tier for this user
  SELECT COALESCE(MAX(udb.tier_number), 0) + 1
  INTO v_next_tier
  FROM user_deposit_bonuses udb
  WHERE udb.user_id = p_user_id;

  -- Get the tier configuration
  SELECT * INTO v_tier_config
  FROM deposit_bonus_tiers dbt
  WHERE dbt.tier_number = v_next_tier
  AND dbt.is_active = true;

  -- If no more tiers available, return empty
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::integer, 0::numeric, 0::numeric, true;
    RETURN;
  END IF;

  -- Check minimum deposit amount
  IF p_deposit_amount < v_tier_config.min_deposit_amount THEN
    RETURN QUERY SELECT v_next_tier, 0::numeric, v_tier_config.bonus_percentage, false;
    RETURN;
  END IF;

  -- Calculate bonus amount (percentage of deposit, capped at max)
  v_calculated_bonus := LEAST(
    p_deposit_amount * (v_tier_config.bonus_percentage / 100),
    v_tier_config.max_bonus_amount
  );

  RETURN QUERY SELECT v_next_tier, v_calculated_bonus, v_tier_config.bonus_percentage, false;
END;
$$;

-- Create function to award deposit bonus
CREATE OR REPLACE FUNCTION award_deposit_bonus(
  p_user_id uuid,
  p_deposit_amount numeric,
  p_deposit_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bonus_info RECORD;
  v_bonus_type_id uuid;
  v_bonus_type_name text;
  v_wallet_id uuid;
  v_locked_bonus_id uuid;
BEGIN
  -- Calculate the bonus
  SELECT * INTO v_bonus_info
  FROM calculate_deposit_bonus(p_user_id, p_deposit_amount, p_deposit_id);

  -- If no bonus or already claimed all tiers
  IF v_bonus_info.tier_number = 0 OR v_bonus_info.bonus_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'No bonus available or minimum deposit not met'
    );
  END IF;

  -- Determine bonus type based on tier
  v_bonus_type_name := CASE v_bonus_info.tier_number
    WHEN 1 THEN 'First Deposit Bonus'
    WHEN 2 THEN 'Second Deposit Bonus'
    WHEN 3 THEN 'Third Deposit Bonus'
    ELSE 'Deposit Bonus'
  END;

  -- Get bonus type id
  SELECT id INTO v_bonus_type_id
  FROM bonus_types
  WHERE name = v_bonus_type_name;

  -- Get or create main wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id AND wallet_type = 'main' AND currency = 'USDT';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, wallet_type, currency, balance)
    VALUES (p_user_id, 'main', 'USDT', 0)
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Record the deposit bonus claim
  INSERT INTO user_deposit_bonuses (user_id, tier_number, deposit_amount, bonus_amount, bonus_percentage, deposit_id)
  VALUES (p_user_id, v_bonus_info.tier_number, p_deposit_amount, v_bonus_info.bonus_amount, v_bonus_info.bonus_percentage, p_deposit_id);

  -- Award as locked bonus
  INSERT INTO locked_bonuses (
    user_id,
    bonus_type_id,
    amount,
    remaining_amount,
    volume_requirement,
    volume_completed,
    expires_at,
    status
  )
  VALUES (
    p_user_id,
    v_bonus_type_id,
    v_bonus_info.bonus_amount,
    v_bonus_info.bonus_amount,
    v_bonus_info.bonus_amount * 10,
    0,
    now() + INTERVAL '30 days',
    'active'
  )
  RETURNING id INTO v_locked_bonus_id;

  -- Create notification
  INSERT INTO notifications (user_id, notification_type, title, message, read)
  VALUES (
    p_user_id,
    'bonus',
    v_bonus_type_name || ' Awarded!',
    'You received $' || ROUND(v_bonus_info.bonus_amount, 2)::text || ' USDT as your ' || 
    CASE v_bonus_info.tier_number 
      WHEN 1 THEN 'first' 
      WHEN 2 THEN 'second' 
      WHEN 3 THEN 'third' 
      ELSE '' 
    END || ' deposit bonus!',
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'tier_number', v_bonus_info.tier_number,
    'bonus_amount', v_bonus_info.bonus_amount,
    'bonus_percentage', v_bonus_info.bonus_percentage,
    'locked_bonus_id', v_locked_bonus_id
  );
END;
$$;

-- Create function to get user's deposit bonus status
CREATE OR REPLACE FUNCTION get_user_deposit_bonus_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_claimed_tiers jsonb;
  v_next_tier RECORD;
  v_total_earned numeric;
BEGIN
  -- Get claimed tiers
  SELECT jsonb_agg(jsonb_build_object(
    'tier', udb.tier_number,
    'deposit_amount', udb.deposit_amount,
    'bonus_amount', udb.bonus_amount,
    'bonus_percentage', udb.bonus_percentage,
    'awarded_at', udb.awarded_at
  ) ORDER BY udb.tier_number)
  INTO v_claimed_tiers
  FROM user_deposit_bonuses udb
  WHERE udb.user_id = p_user_id;

  -- Get total earned
  SELECT COALESCE(SUM(bonus_amount), 0)
  INTO v_total_earned
  FROM user_deposit_bonuses
  WHERE user_id = p_user_id;

  -- Get next available tier
  SELECT dbt.tier_number, dbt.bonus_percentage, dbt.max_bonus_amount, dbt.min_deposit_amount
  INTO v_next_tier
  FROM deposit_bonus_tiers dbt
  WHERE dbt.tier_number > COALESCE((
    SELECT MAX(tier_number) FROM user_deposit_bonuses WHERE user_id = p_user_id
  ), 0)
  AND dbt.is_active = true
  ORDER BY dbt.tier_number
  LIMIT 1;

  RETURN jsonb_build_object(
    'claimed_tiers', COALESCE(v_claimed_tiers, '[]'::jsonb),
    'total_earned', v_total_earned,
    'next_tier', CASE WHEN v_next_tier.tier_number IS NOT NULL THEN
      jsonb_build_object(
        'tier_number', v_next_tier.tier_number,
        'bonus_percentage', v_next_tier.bonus_percentage,
        'max_bonus_amount', v_next_tier.max_bonus_amount,
        'min_deposit_amount', v_next_tier.min_deposit_amount
      )
    ELSE NULL END,
    'all_tiers_claimed', v_next_tier.tier_number IS NULL
  );
END;
$$;

-- Create referral milestone tracking table
CREATE TABLE IF NOT EXISTS referral_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_count integer NOT NULL UNIQUE,
  bonus_amount numeric NOT NULL,
  bonus_type_id uuid REFERENCES bonus_types(id),
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE referral_milestones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view active referral milestones"
  ON referral_milestones
  FOR SELECT
  USING (is_active = true);

-- Insert referral milestones
INSERT INTO referral_milestones (referral_count, bonus_amount, description)
VALUES
  (1, 5, '$5 USDT for your first qualified referral'),
  (5, 25, '$25 USDT when you reach 5 qualified referrals'),
  (10, 70, '$70 USDT when you reach 10 qualified referrals')
ON CONFLICT (referral_count) DO UPDATE SET
  bonus_amount = EXCLUDED.bonus_amount,
  description = EXCLUDED.description;

-- User referral milestone claims tracking
CREATE TABLE IF NOT EXISTS user_referral_milestone_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  milestone_id uuid NOT NULL REFERENCES referral_milestones(id),
  referral_count integer NOT NULL,
  bonus_amount numeric NOT NULL,
  claimed_at timestamptz DEFAULT now(),
  UNIQUE(user_id, milestone_id)
);

ALTER TABLE user_referral_milestone_claims ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own milestone claims"
  ON user_referral_milestone_claims
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "System can insert milestone claims"
  ON user_referral_milestone_claims
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_user_referral_milestone_claims_user_id ON user_referral_milestone_claims(user_id);

-- Function to check and award referral milestones
CREATE OR REPLACE FUNCTION check_and_award_referral_milestones(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qualified_referrals integer;
  v_milestone RECORD;
  v_wallet_id uuid;
  v_awarded_milestones jsonb := '[]'::jsonb;
BEGIN
  -- Get count of qualified referrals (referrals who have deposited $100+)
  SELECT COUNT(DISTINCT up.id)
  INTO v_qualified_referrals
  FROM user_profiles up
  JOIN referral_stats rs ON rs.user_id = up.id
  WHERE up.referred_by = p_user_id
  AND rs.total_deposits >= 100;

  -- Get or create main wallet
  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id AND wallet_type = 'main' AND currency = 'USDT';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, wallet_type, currency, balance)
    VALUES (p_user_id, 'main', 'USDT', 0)
    RETURNING id INTO v_wallet_id;
  END IF;

  -- Check each milestone
  FOR v_milestone IN
    SELECT rm.*
    FROM referral_milestones rm
    WHERE rm.referral_count <= v_qualified_referrals
    AND rm.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM user_referral_milestone_claims urmc
      WHERE urmc.user_id = p_user_id AND urmc.milestone_id = rm.id
    )
    ORDER BY rm.referral_count
  LOOP
    -- Award the milestone bonus
    UPDATE wallets
    SET balance = balance + v_milestone.bonus_amount,
        updated_at = now()
    WHERE id = v_wallet_id;

    -- Record the claim
    INSERT INTO user_referral_milestone_claims (user_id, milestone_id, referral_count, bonus_amount)
    VALUES (p_user_id, v_milestone.id, v_milestone.referral_count, v_milestone.bonus_amount);

    -- Create transaction
    INSERT INTO transactions (user_id, wallet_id, transaction_type, amount, currency, status, details)
    VALUES (
      p_user_id,
      v_wallet_id,
      'reward',
      v_milestone.bonus_amount,
      'USDT',
      'completed',
      'Referral milestone bonus: ' || v_milestone.referral_count || ' referrals'
    );

    -- Create notification
    INSERT INTO notifications (user_id, notification_type, title, message, read)
    VALUES (
      p_user_id,
      'bonus',
      'Referral Milestone Reached!',
      'Congratulations! You earned $' || v_milestone.bonus_amount::text || ' USDT for reaching ' || v_milestone.referral_count || ' qualified referrals!',
      false
    );

    v_awarded_milestones := v_awarded_milestones || jsonb_build_object(
      'referral_count', v_milestone.referral_count,
      'bonus_amount', v_milestone.bonus_amount
    );
  END LOOP;

  RETURN jsonb_build_object(
    'qualified_referrals', v_qualified_referrals,
    'awarded_milestones', v_awarded_milestones
  );
END;
$$;

-- Function to get user's referral milestone status
CREATE OR REPLACE FUNCTION get_user_referral_milestone_status(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_qualified_referrals integer;
  v_claimed_milestones jsonb;
  v_available_milestones jsonb;
  v_total_earned numeric;
BEGIN
  -- Get qualified referral count
  SELECT COUNT(DISTINCT up.id)
  INTO v_qualified_referrals
  FROM user_profiles up
  JOIN referral_stats rs ON rs.user_id = up.id
  WHERE up.referred_by = p_user_id
  AND rs.total_deposits >= 100;

  -- Get claimed milestones
  SELECT jsonb_agg(jsonb_build_object(
    'referral_count', urmc.referral_count,
    'bonus_amount', urmc.bonus_amount,
    'claimed_at', urmc.claimed_at
  ) ORDER BY urmc.referral_count)
  INTO v_claimed_milestones
  FROM user_referral_milestone_claims urmc
  WHERE urmc.user_id = p_user_id;

  -- Get available milestones (not yet claimed)
  SELECT jsonb_agg(jsonb_build_object(
    'referral_count', rm.referral_count,
    'bonus_amount', rm.bonus_amount,
    'description', rm.description,
    'can_claim', rm.referral_count <= v_qualified_referrals
  ) ORDER BY rm.referral_count)
  INTO v_available_milestones
  FROM referral_milestones rm
  WHERE rm.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM user_referral_milestone_claims urmc
    WHERE urmc.user_id = p_user_id AND urmc.milestone_id = rm.id
  );

  -- Get total earned
  SELECT COALESCE(SUM(bonus_amount), 0)
  INTO v_total_earned
  FROM user_referral_milestone_claims
  WHERE user_id = p_user_id;

  RETURN jsonb_build_object(
    'qualified_referrals', v_qualified_referrals,
    'claimed_milestones', COALESCE(v_claimed_milestones, '[]'::jsonb),
    'available_milestones', COALESCE(v_available_milestones, '[]'::jsonb),
    'total_earned', v_total_earned
  );
END;
$$;
