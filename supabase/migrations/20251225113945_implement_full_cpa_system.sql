/*
  # Implement Full CPA System

  ## Overview
  Creates a complete CPA (Cost Per Action) system with triggers
  that automatically award CPA bonuses when users reach milestones.

  ## CPA Milestones
  - KYC Verified: $10
  - First Deposit: $25
  - First Trade: $50
  - Volume Threshold ($10,000): $100

  ## Changes
  1. Add tracking columns to cpa_payouts
  2. Create trigger functions for each milestone
  3. Ensure only affiliate program users with CPA/Hybrid plans get CPA

  ## Security
  All triggers use SECURITY DEFINER
*/

-- Ensure cpa_payouts has proper structure
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'cpa_payouts' AND column_name = 'kyc_paid'
  ) THEN
    ALTER TABLE cpa_payouts ADD COLUMN kyc_paid BOOLEAN DEFAULT false;
    ALTER TABLE cpa_payouts ADD COLUMN deposit_paid BOOLEAN DEFAULT false;
    ALTER TABLE cpa_payouts ADD COLUMN trade_paid BOOLEAN DEFAULT false;
    ALTER TABLE cpa_payouts ADD COLUMN volume_paid BOOLEAN DEFAULT false;
    ALTER TABLE cpa_payouts ADD COLUMN total_cpa_earned NUMERIC DEFAULT 0;
  END IF;
END $$;

-- Function to check if user qualifies for CPA payouts
CREATE OR REPLACE FUNCTION check_cpa_eligibility(p_referrer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_active_program TEXT;
  v_plan_type TEXT;
BEGIN
  SELECT active_program INTO v_active_program
  FROM user_profiles
  WHERE id = p_referrer_id;

  IF v_active_program != 'affiliate' THEN
    RETURN false;
  END IF;

  SELECT plan_type INTO v_plan_type
  FROM affiliate_compensation_plans
  WHERE user_id = p_referrer_id;

  RETURN v_plan_type IN ('cpa', 'hybrid');
END;
$$;

-- Function to award CPA bonus
CREATE OR REPLACE FUNCTION award_cpa_bonus(
  p_referrer_id UUID,
  p_referred_user_id UUID,
  p_milestone TEXT,
  p_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO wallets (user_id, currency, wallet_type, balance)
  VALUES (p_referrer_id, 'USDT', 'main', p_amount)
  ON CONFLICT (user_id, currency, wallet_type)
  DO UPDATE SET balance = wallets.balance + p_amount, updated_at = now();

  INSERT INTO transactions (user_id, transaction_type, currency, amount, status, details)
  VALUES (
    p_referrer_id,
    'referral_commission',
    'USDT',
    p_amount,
    'completed',
    jsonb_build_object('type', 'cpa', 'milestone', p_milestone, 'referred_user', p_referred_user_id)
  );

  UPDATE referral_stats
  SET 
    cpa_earnings = COALESCE(cpa_earnings, 0) + p_amount,
    lifetime_earnings = COALESCE(lifetime_earnings, 0) + p_amount,
    this_month_earnings = COALESCE(this_month_earnings, 0) + p_amount,
    updated_at = now()
  WHERE user_id = p_referrer_id;

  INSERT INTO notifications (user_id, type, title, message, data)
  VALUES (
    p_referrer_id,
    'referral_payout',
    'CPA Bonus Earned!',
    'You earned $' || p_amount::TEXT || ' USDT for referral milestone: ' || p_milestone,
    jsonb_build_object('amount', p_amount, 'milestone', p_milestone, 'referred_user', p_referred_user_id)
  );
END;
$$;

-- Trigger function for KYC verification CPA
CREATE OR REPLACE FUNCTION trigger_cpa_kyc_verified()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_cpa_record RECORD;
BEGIN
  IF NEW.kyc_status = 'approved' AND (OLD.kyc_status IS NULL OR OLD.kyc_status != 'approved') THEN
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = NEW.id;

    IF v_referrer_id IS NOT NULL AND check_cpa_eligibility(v_referrer_id) THEN
      SELECT * INTO v_cpa_record
      FROM cpa_payouts
      WHERE affiliate_id = v_referrer_id AND referred_user_id = NEW.id;

      IF v_cpa_record.id IS NULL THEN
        INSERT INTO cpa_payouts (
          affiliate_id, referred_user_id, kyc_paid, total_cpa_earned, status
        ) VALUES (
          v_referrer_id, NEW.id, true, 10, 'qualified'
        );
        PERFORM award_cpa_bonus(v_referrer_id, NEW.id, 'KYC Verified', 10);
      ELSIF NOT COALESCE(v_cpa_record.kyc_paid, false) THEN
        UPDATE cpa_payouts
        SET kyc_paid = true, total_cpa_earned = COALESCE(total_cpa_earned, 0) + 10
        WHERE id = v_cpa_record.id;
        PERFORM award_cpa_bonus(v_referrer_id, NEW.id, 'KYC Verified', 10);
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger for KYC CPA
DROP TRIGGER IF EXISTS trigger_cpa_on_kyc ON user_profiles;
CREATE TRIGGER trigger_cpa_on_kyc
  AFTER UPDATE OF kyc_status ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION trigger_cpa_kyc_verified();

-- Trigger function for first deposit CPA
CREATE OR REPLACE FUNCTION trigger_cpa_first_deposit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_cpa_record RECORD;
  v_is_first_deposit BOOLEAN;
BEGIN
  IF NEW.transaction_type = 'deposit' AND NEW.status = 'completed' THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM transactions
      WHERE user_id = NEW.user_id
        AND transaction_type = 'deposit'
        AND status = 'completed'
        AND id != NEW.id
    ) INTO v_is_first_deposit;

    IF v_is_first_deposit THEN
      SELECT referred_by INTO v_referrer_id
      FROM user_profiles
      WHERE id = NEW.user_id;

      IF v_referrer_id IS NOT NULL AND check_cpa_eligibility(v_referrer_id) THEN
        SELECT * INTO v_cpa_record
        FROM cpa_payouts
        WHERE affiliate_id = v_referrer_id AND referred_user_id = NEW.user_id;

        IF v_cpa_record.id IS NULL THEN
          INSERT INTO cpa_payouts (
            affiliate_id, referred_user_id, deposit_paid, total_cpa_earned, status
          ) VALUES (
            v_referrer_id, NEW.user_id, true, 25, 'qualified'
          );
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Deposit', 25);
        ELSIF NOT COALESCE(v_cpa_record.deposit_paid, false) THEN
          UPDATE cpa_payouts
          SET deposit_paid = true, total_cpa_earned = COALESCE(total_cpa_earned, 0) + 25
          WHERE id = v_cpa_record.id;
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Deposit', 25);
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger for deposit CPA
DROP TRIGGER IF EXISTS trigger_cpa_on_deposit ON transactions;
CREATE TRIGGER trigger_cpa_on_deposit
  AFTER INSERT ON transactions
  FOR EACH ROW
  WHEN (NEW.transaction_type = 'deposit')
  EXECUTE FUNCTION trigger_cpa_first_deposit();

-- Trigger function for first trade CPA
CREATE OR REPLACE FUNCTION trigger_cpa_first_trade()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_cpa_record RECORD;
  v_is_first_trade BOOLEAN;
BEGIN
  IF NEW.status = 'open' THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM futures_positions
      WHERE user_id = NEW.user_id AND id != NEW.id
    ) INTO v_is_first_trade;

    IF v_is_first_trade THEN
      SELECT referred_by INTO v_referrer_id
      FROM user_profiles
      WHERE id = NEW.user_id;

      IF v_referrer_id IS NOT NULL AND check_cpa_eligibility(v_referrer_id) THEN
        SELECT * INTO v_cpa_record
        FROM cpa_payouts
        WHERE affiliate_id = v_referrer_id AND referred_user_id = NEW.user_id;

        IF v_cpa_record.id IS NULL THEN
          INSERT INTO cpa_payouts (
            affiliate_id, referred_user_id, trade_paid, total_cpa_earned, status
          ) VALUES (
            v_referrer_id, NEW.user_id, true, 50, 'qualified'
          );
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Trade', 50);
        ELSIF NOT COALESCE(v_cpa_record.trade_paid, false) THEN
          UPDATE cpa_payouts
          SET trade_paid = true, total_cpa_earned = COALESCE(total_cpa_earned, 0) + 50
          WHERE id = v_cpa_record.id;
          PERFORM award_cpa_bonus(v_referrer_id, NEW.user_id, 'First Trade', 50);
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger for trade CPA
DROP TRIGGER IF EXISTS trigger_cpa_on_trade ON futures_positions;
CREATE TRIGGER trigger_cpa_on_trade
  AFTER INSERT ON futures_positions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_cpa_first_trade();

-- Function to check and award volume threshold CPA
CREATE OR REPLACE FUNCTION check_volume_threshold_cpa(
  p_user_id UUID,
  p_new_volume NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_cpa_record RECORD;
  v_threshold NUMERIC := 10000;
BEGIN
  IF p_new_volume >= v_threshold THEN
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = p_user_id;

    IF v_referrer_id IS NOT NULL AND check_cpa_eligibility(v_referrer_id) THEN
      SELECT * INTO v_cpa_record
      FROM cpa_payouts
      WHERE affiliate_id = v_referrer_id AND referred_user_id = p_user_id;

      IF v_cpa_record.id IS NOT NULL AND NOT COALESCE(v_cpa_record.volume_paid, false) THEN
        UPDATE cpa_payouts
        SET volume_paid = true, total_cpa_earned = COALESCE(total_cpa_earned, 0) + 100
        WHERE id = v_cpa_record.id;
        PERFORM award_cpa_bonus(v_referrer_id, p_user_id, 'Volume Threshold ($10,000)', 100);
      ELSIF v_cpa_record.id IS NULL THEN
        INSERT INTO cpa_payouts (
          affiliate_id, referred_user_id, volume_paid, total_cpa_earned, status
        ) VALUES (
          v_referrer_id, p_user_id, true, 100, 'qualified'
        );
        PERFORM award_cpa_bonus(v_referrer_id, p_user_id, 'Volume Threshold ($10,000)', 100);
      END IF;
    END IF;
  END IF;
END;
$$;
