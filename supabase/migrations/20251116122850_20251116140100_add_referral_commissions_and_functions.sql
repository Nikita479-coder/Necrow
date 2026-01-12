/*
  # Add Referral Commission Tracking and Distribution

  1. New Tables
    - `referral_commissions` - Individual commission records
    - `referral_rebates` - Fee rebates for new users

  2. New Functions
    - distribute_trading_fees() - Automatically distribute commissions and rebates
    - calculate_vip_level() - Calculate VIP level from volume
    - get_commission_rate() - Get commission rate for VIP level
    - get_rebate_rate() - Get rebate rate for VIP level

  3. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Create referral_commissions table
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

-- Create referral_rebates table
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
ALTER TABLE referral_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE referral_rebates ENABLE ROW LEVEL SECURITY;

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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION calculate_vip_level(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION get_commission_rate(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION get_rebate_rate(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION distribute_trading_fees(uuid, uuid, numeric, numeric) TO authenticated;
