/*
  # Complete Referral System with Trading Fee Commission

  1. New Tables
    - `referral_stats`
      - Tracks referrer statistics (VIP level, earnings, referral count, volume)
    - `referral_commissions`
      - Individual commission records from each trade
    - `referral_rebates`
      - Fee rebates for new users (30-day benefit)

  2. Changes
    - Add VIP level calculation based on 30-day trading volume
    - Add commission distribution on every trade
    - Add rebate system for new referrals (30 days)
    - Track all earnings and statistics

  3. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Use SECURITY DEFINER for commission distribution

  4. Important Notes
    - Commissions are automatically calculated when trades occur
    - Rebates expire after 30 days
    - VIP levels update based on monthly volume
*/

-- Create referral_stats table
CREATE TABLE IF NOT EXISTS referral_stats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  vip_level integer DEFAULT 1 NOT NULL CHECK (vip_level >= 1 AND vip_level <= 6),
  total_referrals integer DEFAULT 0 NOT NULL,
  total_earnings numeric(20, 8) DEFAULT 0 NOT NULL,
  total_volume_30d numeric(20, 8) DEFAULT 0 NOT NULL,
  total_volume_all_time numeric(20, 8) DEFAULT 0 NOT NULL,
  this_month_earnings numeric(20, 8) DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create referral_commissions table (tracks individual commissions)
CREATE TABLE IF NOT EXISTS referral_commissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  referee_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  transaction_id uuid REFERENCES transactions(id) ON DELETE SET NULL,
  trade_amount numeric(20, 8) NOT NULL,
  fee_amount numeric(20, 8) NOT NULL,
  commission_rate numeric(5, 2) NOT NULL,
  commission_amount numeric(20, 8) NOT NULL,
  vip_level integer NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Create referral_rebates table (30-day fee rebates for new users)
CREATE TABLE IF NOT EXISTS referral_rebates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  transaction_id uuid REFERENCES transactions(id) ON DELETE SET NULL,
  original_fee numeric(20, 8) NOT NULL,
  rebate_rate numeric(5, 2) NOT NULL,
  rebate_amount numeric(20, 8) NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

-- Enable RLS
ALTER TABLE referral_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_rebates ENABLE ROW LEVEL SECURITY;

-- Policies for referral_stats
CREATE POLICY "Users can view own referral stats"
  ON referral_stats FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own referral stats"
  ON referral_stats FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own referral stats"
  ON referral_stats FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policies for referral_commissions
CREATE POLICY "Referrers can view their commissions"
  ON referral_commissions FOR SELECT
  TO authenticated
  USING (auth.uid() = referrer_id);

-- Policies for referral_rebates
CREATE POLICY "Users can view their rebates"
  ON referral_rebates FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_referral_stats_user_id ON referral_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_commissions_referrer ON referral_commissions(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referral_commissions_referee ON referral_commissions(referee_id);
CREATE INDEX IF NOT EXISTS idx_referral_rebates_user_id ON referral_rebates(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_rebates_expires_at ON referral_rebates(expires_at);

-- Function to calculate VIP level based on 30-day volume
CREATE OR REPLACE FUNCTION calculate_vip_level(volume_30d numeric)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF volume_30d >= 25000001 THEN RETURN 6;
  ELSIF volume_30d >= 2500001 THEN RETURN 5;
  ELSIF volume_30d >= 500001 THEN RETURN 4;
  ELSIF volume_30d >= 100001 THEN RETURN 3;
  ELSIF volume_30d >= 10001 THEN RETURN 2;
  ELSE RETURN 1;
  END IF;
END;
$$;

-- Function to get commission rate for VIP level
CREATE OR REPLACE FUNCTION get_commission_rate(vip_level integer)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  CASE vip_level
    WHEN 6 THEN RETURN 70;
    WHEN 5 THEN RETURN 50;
    WHEN 4 THEN RETURN 40;
    WHEN 3 THEN RETURN 30;
    WHEN 2 THEN RETURN 20;
    ELSE RETURN 10;
  END CASE;
END;
$$;

-- Function to get rebate rate for VIP level
CREATE OR REPLACE FUNCTION get_rebate_rate(vip_level integer)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  CASE vip_level
    WHEN 6 THEN RETURN 15;
    WHEN 5 THEN RETURN 10;
    WHEN 4 THEN RETURN 8;
    WHEN 3 THEN RETURN 7;
    WHEN 2 THEN RETURN 6;
    ELSE RETURN 5;
  END CASE;
END;
$$;

-- Function to distribute trading fee commissions and rebates
CREATE OR REPLACE FUNCTION distribute_trading_fees(
  p_user_id uuid,
  p_transaction_id uuid,
  p_trade_amount numeric,
  p_fee_amount numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id uuid;
  v_referee_signup_date timestamptz;
  v_referrer_stats record;
  v_commission_rate numeric;
  v_rebate_rate numeric;
  v_commission_amount numeric;
  v_rebate_amount numeric;
  v_new_volume numeric;
  v_new_vip_level integer;
BEGIN
  -- Check if user was referred by someone
  SELECT referred_by, created_at INTO v_referrer_id, v_referee_signup_date
  FROM user_profiles
  WHERE id = p_user_id;

  -- If no referrer, nothing to distribute
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;

  -- Get referrer stats (or create if doesn't exist)
  SELECT * INTO v_referrer_stats
  FROM referral_stats
  WHERE user_id = v_referrer_id;

  IF v_referrer_stats IS NULL THEN
    -- Initialize referrer stats
    INSERT INTO referral_stats (user_id, total_referrals)
    VALUES (v_referrer_id, 1)
    RETURNING * INTO v_referrer_stats;
  END IF;

  -- Get commission and rebate rates based on VIP level
  v_commission_rate := get_commission_rate(v_referrer_stats.vip_level);
  v_rebate_rate := get_rebate_rate(v_referrer_stats.vip_level);

  -- Calculate commission amount (percentage of trading fee)
  v_commission_amount := (p_fee_amount * v_commission_rate) / 100;

  -- Record the commission
  INSERT INTO referral_commissions (
    referrer_id,
    referee_id,
    transaction_id,
    trade_amount,
    fee_amount,
    commission_rate,
    commission_amount,
    vip_level
  ) VALUES (
    v_referrer_id,
    p_user_id,
    p_transaction_id,
    p_trade_amount,
    p_fee_amount,
    v_commission_rate,
    v_commission_amount,
    v_referrer_stats.vip_level
  );

  -- Update referrer's earnings and volume
  v_new_volume := v_referrer_stats.total_volume_30d + p_trade_amount;
  v_new_vip_level := calculate_vip_level(v_new_volume);

  UPDATE referral_stats
  SET
    total_earnings = total_earnings + v_commission_amount,
    total_volume_30d = v_new_volume,
    total_volume_all_time = total_volume_all_time + p_trade_amount,
    this_month_earnings = this_month_earnings + v_commission_amount,
    vip_level = v_new_vip_level,
    updated_at = now()
  WHERE user_id = v_referrer_id;

  -- Add commission to referrer's wallet
  UPDATE wallets
  SET balance = balance + v_commission_amount,
      updated_at = now()
  WHERE user_id = v_referrer_id
    AND currency = 'USDT'
    AND wallet_type = 'spot';

  -- Record transaction for commission
  INSERT INTO transactions (
    user_id,
    type,
    currency,
    amount,
    status,
    created_at
  ) VALUES (
    v_referrer_id,
    'referral_commission',
    'USDT',
    v_commission_amount,
    'completed',
    now()
  );

  -- Handle rebate for referee (if within 30 days of signup)
  IF v_referee_signup_date + INTERVAL '30 days' > now() THEN
    v_rebate_amount := (p_fee_amount * v_rebate_rate) / 100;

    -- Record the rebate
    INSERT INTO referral_rebates (
      user_id,
      transaction_id,
      original_fee,
      rebate_rate,
      rebate_amount,
      expires_at
    ) VALUES (
      p_user_id,
      p_transaction_id,
      p_fee_amount,
      v_rebate_rate,
      v_rebate_amount,
      v_referee_signup_date + INTERVAL '30 days'
    );

    -- Add rebate to referee's wallet
    UPDATE wallets
    SET balance = balance + v_rebate_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND currency = 'USDT'
      AND wallet_type = 'spot';

    -- Record transaction for rebate
    INSERT INTO transactions (
      user_id,
      type,
      currency,
      amount,
      status,
      created_at
    ) VALUES (
      p_user_id,
      'fee_rebate',
      'USDT',
      v_rebate_amount,
      'completed',
      now()
    );
  END IF;

END;
$$;

-- Function to update referral count when a new referral signs up
CREATE OR REPLACE FUNCTION update_referral_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only run if referred_by was just set (not null and changed)
  IF NEW.referred_by IS NOT NULL AND (OLD.referred_by IS NULL OR OLD.referred_by != NEW.referred_by) THEN
    -- Initialize or update referrer stats
    INSERT INTO referral_stats (user_id, total_referrals)
    VALUES (NEW.referred_by, 1)
    ON CONFLICT (user_id) DO UPDATE
    SET total_referrals = referral_stats.total_referrals + 1,
        updated_at = now();
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger to update referral count when someone signs up with a code
CREATE TRIGGER update_referral_count_trigger
  AFTER UPDATE OF referred_by ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_referral_count();

-- Function to reset monthly stats (should be called by a cron job)
CREATE OR REPLACE FUNCTION reset_monthly_referral_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE referral_stats
  SET
    this_month_earnings = 0,
    total_volume_30d = 0,
    vip_level = calculate_vip_level(0),
    updated_at = now();
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION calculate_vip_level(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION get_commission_rate(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION get_rebate_rate(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_trading_fees(uuid, uuid, numeric, numeric) TO authenticated;
