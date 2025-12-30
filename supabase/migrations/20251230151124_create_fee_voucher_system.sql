/*
  # Fee Voucher System

  1. New Tables
    - `fee_vouchers` - User's fee voucher balances
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `campaign_id` (uuid, optional reference to giveaway campaign)
      - `source` (text) - giveaway/promotion/manual
      - `source_id` (uuid) - Reference to winner record or other source
      - `original_amount` (numeric) - Initial voucher value
      - `remaining_amount` (numeric) - Current balance
      - `expires_at` (timestamptz) - When voucher expires
      - `is_active` (boolean) - Whether voucher can be used
      - `created_at` (timestamptz)

    - `fee_voucher_usage` - Tracks each application of voucher
      - `id` (uuid, primary key)
      - `voucher_id` (uuid, references fee_vouchers)
      - `user_id` (uuid, references auth.users)
      - `transaction_id` (uuid, references transactions)
      - `position_id` (uuid, optional reference to futures_positions)
      - `fee_type` (text) - futures_open/futures_close/swap/funding
      - `original_fee` (numeric) - Fee before voucher
      - `voucher_amount_used` (numeric) - Amount deducted from voucher
      - `final_fee` (numeric) - Fee after voucher applied
      - `used_at` (timestamptz)

  2. Functions
    - `apply_fee_voucher()` - Applies voucher to a fee, returns details
    - `get_user_fee_voucher_balance()` - Gets total available voucher balance
    - `create_fee_voucher()` - Creates a new voucher for a user

  3. Security
    - Enable RLS
    - Users can view their own vouchers
    - Admins have full access
*/

-- Fee Vouchers Table
CREATE TABLE IF NOT EXISTS fee_vouchers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  campaign_id uuid REFERENCES giveaway_campaigns(id),
  source text NOT NULL CHECK (source IN ('giveaway', 'promotion', 'manual', 'referral')),
  source_id uuid,
  original_amount numeric(20,2) NOT NULL,
  remaining_amount numeric(20,2) NOT NULL,
  expires_at timestamptz NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT positive_amounts CHECK (original_amount > 0 AND remaining_amount >= 0)
);

-- Fee Voucher Usage Table
CREATE TABLE IF NOT EXISTS fee_voucher_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id uuid NOT NULL REFERENCES fee_vouchers(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  transaction_id uuid REFERENCES transactions(id),
  position_id uuid,
  fee_type text NOT NULL CHECK (fee_type IN ('futures_open', 'futures_close', 'swap', 'funding', 'other')),
  original_fee numeric(20,8) NOT NULL,
  voucher_amount_used numeric(20,8) NOT NULL,
  final_fee numeric(20,8) NOT NULL,
  used_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_fee_vouchers_user ON fee_vouchers(user_id);
CREATE INDEX IF NOT EXISTS idx_fee_vouchers_active ON fee_vouchers(user_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_fee_vouchers_expires ON fee_vouchers(expires_at);
CREATE INDEX IF NOT EXISTS idx_fee_voucher_usage_voucher ON fee_voucher_usage(voucher_id);
CREATE INDEX IF NOT EXISTS idx_fee_voucher_usage_user ON fee_voucher_usage(user_id);

-- Enable RLS
ALTER TABLE fee_vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE fee_voucher_usage ENABLE ROW LEVEL SECURITY;

-- RLS Policies for fee_vouchers
CREATE POLICY "Users can view their own vouchers"
  ON fee_vouchers
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all vouchers"
  ON fee_vouchers
  FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

-- RLS Policies for fee_voucher_usage
CREATE POLICY "Users can view their own voucher usage"
  ON fee_voucher_usage
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all voucher usage"
  ON fee_voucher_usage
  FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

-- Function to create a fee voucher
CREATE OR REPLACE FUNCTION create_fee_voucher(
  p_user_id uuid,
  p_amount numeric,
  p_source text,
  p_source_id uuid DEFAULT NULL,
  p_campaign_id uuid DEFAULT NULL,
  p_expires_days integer DEFAULT 30
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_voucher_id uuid;
BEGIN
  INSERT INTO fee_vouchers (
    user_id,
    campaign_id,
    source,
    source_id,
    original_amount,
    remaining_amount,
    expires_at
  ) VALUES (
    p_user_id,
    p_campaign_id,
    p_source,
    p_source_id,
    p_amount,
    p_amount,
    now() + (p_expires_days || ' days')::interval
  )
  RETURNING id INTO v_voucher_id;

  RETURN v_voucher_id;
END;
$$;

-- Function to get user's total available voucher balance
CREATE OR REPLACE FUNCTION get_user_fee_voucher_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance numeric;
BEGIN
  SELECT COALESCE(SUM(remaining_amount), 0)
  INTO v_balance
  FROM fee_vouchers
  WHERE user_id = p_user_id
    AND is_active = true
    AND remaining_amount > 0
    AND expires_at > now();

  RETURN v_balance;
END;
$$;

-- Function to apply fee voucher to a fee
CREATE OR REPLACE FUNCTION apply_fee_voucher(
  p_user_id uuid,
  p_fee_amount numeric,
  p_fee_type text,
  p_transaction_id uuid DEFAULT NULL,
  p_position_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_voucher RECORD;
  v_remaining_fee numeric := p_fee_amount;
  v_total_voucher_used numeric := 0;
  v_amount_to_use numeric;
BEGIN
  IF p_fee_amount <= 0 THEN
    RETURN jsonb_build_object(
      'original_fee', p_fee_amount,
      'voucher_used', 0,
      'final_fee', p_fee_amount,
      'vouchers_applied', 0
    );
  END IF;

  FOR v_voucher IN
    SELECT id, remaining_amount
    FROM fee_vouchers
    WHERE user_id = p_user_id
      AND is_active = true
      AND remaining_amount > 0
      AND expires_at > now()
    ORDER BY expires_at ASC
  LOOP
    EXIT WHEN v_remaining_fee <= 0;

    v_amount_to_use := LEAST(v_voucher.remaining_amount, v_remaining_fee);

    UPDATE fee_vouchers
    SET remaining_amount = remaining_amount - v_amount_to_use,
        is_active = CASE WHEN remaining_amount - v_amount_to_use <= 0 THEN false ELSE true END
    WHERE id = v_voucher.id;

    INSERT INTO fee_voucher_usage (
      voucher_id,
      user_id,
      transaction_id,
      position_id,
      fee_type,
      original_fee,
      voucher_amount_used,
      final_fee
    ) VALUES (
      v_voucher.id,
      p_user_id,
      p_transaction_id,
      p_position_id,
      p_fee_type,
      p_fee_amount,
      v_amount_to_use,
      v_remaining_fee - v_amount_to_use
    );

    v_remaining_fee := v_remaining_fee - v_amount_to_use;
    v_total_voucher_used := v_total_voucher_used + v_amount_to_use;
  END LOOP;

  RETURN jsonb_build_object(
    'original_fee', p_fee_amount,
    'voucher_used', v_total_voucher_used,
    'final_fee', v_remaining_fee,
    'vouchers_applied', CASE WHEN v_total_voucher_used > 0 THEN 1 ELSE 0 END
  );
END;
$$;

-- Function to get user's voucher details
CREATE OR REPLACE FUNCTION get_user_fee_vouchers(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  source text,
  original_amount numeric,
  remaining_amount numeric,
  expires_at timestamptz,
  is_active boolean,
  is_expired boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    fv.id,
    fv.source,
    fv.original_amount,
    fv.remaining_amount,
    fv.expires_at,
    fv.is_active,
    fv.expires_at <= now() AS is_expired,
    fv.created_at
  FROM fee_vouchers fv
  WHERE fv.user_id = p_user_id
  ORDER BY fv.expires_at ASC;
END;
$$;

-- Function to expire old vouchers
CREATE OR REPLACE FUNCTION expire_old_fee_vouchers()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE fee_vouchers
  SET is_active = false
  WHERE is_active = true
    AND expires_at <= now();
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_fee_voucher(uuid, numeric, text, uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_fee_voucher_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION apply_fee_voucher(uuid, numeric, text, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_fee_vouchers(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION expire_old_fee_vouchers() TO authenticated;
