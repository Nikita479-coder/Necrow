/*
  # Signup Bonus Tracking System
  
  1. New Tables
    - `signup_bonus_tracking`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `kyc_bonus_awarded` (boolean, default false)
      - `kyc_bonus_awarded_at` (timestamptz)
      - `kyc_bonus_amount` (numeric)
      - `first_deposit_bonus_awarded` (boolean, default false)
      - `first_deposit_bonus_awarded_at` (timestamptz)
      - `first_deposit_amount` (numeric)
      - `first_deposit_bonus_amount` (numeric)
      - `created_at` (timestamptz)
      
  2. New Bonus Types
    - "KYC Verification Bonus" - $20 locked bonus
    - "First Deposit Match Bonus" - 100% match up to $100
    
  3. Triggers
    - Auto-create tracking record on user signup
    - Auto-award KYC bonus on KYC approval
    - Auto-award first deposit bonus on first deposit
    
  4. Security
    - Enable RLS on signup_bonus_tracking
    - Users can only read their own tracking data
*/

-- Create signup_bonus_tracking table
CREATE TABLE IF NOT EXISTS public.signup_bonus_tracking (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kyc_bonus_awarded boolean DEFAULT false,
  kyc_bonus_awarded_at timestamptz,
  kyc_bonus_amount numeric(20, 8),
  first_deposit_bonus_awarded boolean DEFAULT false,
  first_deposit_bonus_awarded_at timestamptz,
  first_deposit_amount numeric(20, 8),
  first_deposit_bonus_amount numeric(20, 8),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.signup_bonus_tracking ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own tracking data
CREATE POLICY "Users can read own signup bonus tracking"
  ON public.signup_bonus_tracking
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Policy: System can insert/update (via security definer functions)
CREATE POLICY "System can manage signup bonus tracking"
  ON public.signup_bonus_tracking
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Create index
CREATE INDEX IF NOT EXISTS idx_signup_bonus_tracking_user_id 
  ON public.signup_bonus_tracking(user_id);

-- Insert KYC Verification Bonus type if not exists
INSERT INTO public.bonus_types (name, description, default_amount, category, expiry_days, is_locked_bonus, is_active)
SELECT 
  'KYC Verification Bonus',
  'Complete KYC verification and receive $20 free locked trading credit. Valid for 7 days. Only profits can be withdrawn.',
  20,
  'promotion',
  7,
  true,
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.bonus_types WHERE name = 'KYC Verification Bonus'
);

-- Insert First Deposit Match Bonus type if not exists
INSERT INTO public.bonus_types (name, description, default_amount, category, expiry_days, is_locked_bonus, is_active)
SELECT 
  'First Deposit Match Bonus',
  '100% match on your first deposit, up to $100. Valid for 7 days. Only profits can be withdrawn.',
  100,
  'deposit',
  7,
  true,
  true
WHERE NOT EXISTS (
  SELECT 1 FROM public.bonus_types WHERE name = 'First Deposit Match Bonus'
);

-- Function to initialize signup bonus tracking for new users
CREATE OR REPLACE FUNCTION public.initialize_signup_bonus_tracking()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.signup_bonus_tracking (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$;

-- Trigger to auto-create tracking record on user profile creation
DROP TRIGGER IF EXISTS tr_initialize_signup_bonus_tracking ON public.user_profiles;
CREATE TRIGGER tr_initialize_signup_bonus_tracking
  AFTER INSERT ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.initialize_signup_bonus_tracking();

-- Function to award KYC bonus
CREATE OR REPLACE FUNCTION public.award_kyc_bonus(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tracking record;
  v_bonus_type record;
  v_locked_bonus_id uuid;
  v_user_profile record;
BEGIN
  -- Check if already awarded
  SELECT * INTO v_tracking
  FROM public.signup_bonus_tracking
  WHERE user_id = p_user_id;
  
  IF v_tracking IS NULL THEN
    -- Create tracking record if missing
    INSERT INTO public.signup_bonus_tracking (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_tracking;
  END IF;
  
  IF v_tracking.kyc_bonus_awarded THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'KYC bonus has already been awarded'
    );
  END IF;
  
  -- Get bonus type
  SELECT * INTO v_bonus_type
  FROM public.bonus_types
  WHERE name = 'KYC Verification Bonus'
    AND is_active = true;
    
  IF v_bonus_type IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'KYC bonus type not found or inactive'
    );
  END IF;
  
  -- Get user profile for name
  SELECT * INTO v_user_profile
  FROM public.user_profiles
  WHERE id = p_user_id;
  
  -- Create locked bonus
  INSERT INTO public.user_locked_bonuses (
    user_id,
    bonus_type_id,
    original_amount,
    current_amount,
    expires_at
  ) VALUES (
    p_user_id,
    v_bonus_type.id,
    v_bonus_type.default_amount,
    v_bonus_type.default_amount,
    now() + (v_bonus_type.expiry_days || ' days')::interval
  )
  RETURNING id INTO v_locked_bonus_id;
  
  -- Update tracking
  UPDATE public.signup_bonus_tracking
  SET 
    kyc_bonus_awarded = true,
    kyc_bonus_awarded_at = now(),
    kyc_bonus_amount = v_bonus_type.default_amount
  WHERE user_id = p_user_id;
  
  -- Create notification
  INSERT INTO public.notifications (user_id, notification_type, title, message)
  VALUES (
    p_user_id,
    'bonus',
    'KYC Verification Bonus Awarded!',
    'Congratulations! You have received $' || v_bonus_type.default_amount || ' in locked trading credit. This bonus is valid for 7 days and can be used for futures trading. Only profits can be withdrawn.'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'bonus_amount', v_bonus_type.default_amount,
    'locked_bonus_id', v_locked_bonus_id,
    'expires_at', now() + (v_bonus_type.expiry_days || ' days')::interval
  );
END;
$$;

-- Function to award first deposit bonus
CREATE OR REPLACE FUNCTION public.award_first_deposit_bonus(p_user_id uuid, p_deposit_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tracking record;
  v_bonus_type record;
  v_bonus_amount numeric;
  v_locked_bonus_id uuid;
BEGIN
  -- Check if already awarded
  SELECT * INTO v_tracking
  FROM public.signup_bonus_tracking
  WHERE user_id = p_user_id;
  
  IF v_tracking IS NULL THEN
    -- Create tracking record if missing
    INSERT INTO public.signup_bonus_tracking (user_id)
    VALUES (p_user_id)
    RETURNING * INTO v_tracking;
  END IF;
  
  IF v_tracking.first_deposit_bonus_awarded THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'First deposit bonus has already been awarded'
    );
  END IF;
  
  -- Get bonus type
  SELECT * INTO v_bonus_type
  FROM public.bonus_types
  WHERE name = 'First Deposit Match Bonus'
    AND is_active = true;
    
  IF v_bonus_type IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'First deposit bonus type not found or inactive'
    );
  END IF;
  
  -- Calculate bonus amount (100% match, capped at $100)
  v_bonus_amount := LEAST(p_deposit_amount, v_bonus_type.default_amount);
  
  -- Create locked bonus
  INSERT INTO public.user_locked_bonuses (
    user_id,
    bonus_type_id,
    original_amount,
    current_amount,
    expires_at
  ) VALUES (
    p_user_id,
    v_bonus_type.id,
    v_bonus_amount,
    v_bonus_amount,
    now() + (v_bonus_type.expiry_days || ' days')::interval
  )
  RETURNING id INTO v_locked_bonus_id;
  
  -- Update tracking
  UPDATE public.signup_bonus_tracking
  SET 
    first_deposit_bonus_awarded = true,
    first_deposit_bonus_awarded_at = now(),
    first_deposit_amount = p_deposit_amount,
    first_deposit_bonus_amount = v_bonus_amount
  WHERE user_id = p_user_id;
  
  -- Create notification
  INSERT INTO public.notifications (user_id, notification_type, title, message)
  VALUES (
    p_user_id,
    'bonus',
    'First Deposit Bonus Awarded!',
    'Congratulations! You have received $' || v_bonus_amount || ' (100% match on your $' || p_deposit_amount || ' deposit) in locked trading credit. This bonus is valid for 7 days and can be used for futures trading. Only profits can be withdrawn.'
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'deposit_amount', p_deposit_amount,
    'bonus_amount', v_bonus_amount,
    'locked_bonus_id', v_locked_bonus_id,
    'expires_at', now() + (v_bonus_type.expiry_days || ' days')::interval
  );
END;
$$;

-- Trigger function to auto-award KYC bonus on approval
CREATE OR REPLACE FUNCTION public.tr_award_kyc_bonus_on_approval()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Check if KYC status changed to approved
  IF NEW.kyc_status = 'approved' AND (OLD.kyc_status IS NULL OR OLD.kyc_status != 'approved') THEN
    -- Award the KYC bonus
    v_result := public.award_kyc_bonus(NEW.id);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for KYC approval
DROP TRIGGER IF EXISTS tr_kyc_bonus_on_approval ON public.user_profiles;
CREATE TRIGGER tr_kyc_bonus_on_approval
  AFTER UPDATE OF kyc_status ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_award_kyc_bonus_on_approval();

-- Trigger function to auto-award first deposit bonus
CREATE OR REPLACE FUNCTION public.tr_award_first_deposit_bonus()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tracking record;
  v_result jsonb;
  v_deposit_amount numeric;
BEGIN
  -- Only process completed deposits
  IF NEW.status = 'completed' AND NEW.transaction_type = 'deposit' THEN
    -- Check if first deposit bonus already awarded
    SELECT * INTO v_tracking
    FROM public.signup_bonus_tracking
    WHERE user_id = NEW.user_id;
    
    IF v_tracking IS NULL OR NOT v_tracking.first_deposit_bonus_awarded THEN
      -- This is their first deposit - award bonus
      v_deposit_amount := COALESCE(NEW.amount_usd, NEW.amount);
      v_result := public.award_first_deposit_bonus(NEW.user_id, v_deposit_amount);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for first deposit
DROP TRIGGER IF EXISTS tr_first_deposit_bonus ON public.transactions;
CREATE TRIGGER tr_first_deposit_bonus
  AFTER INSERT OR UPDATE OF status ON public.transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.tr_award_first_deposit_bonus();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.award_kyc_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.award_first_deposit_bonus(uuid, numeric) TO authenticated;

-- Initialize tracking for existing users who don't have it
INSERT INTO public.signup_bonus_tracking (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.signup_bonus_tracking)
ON CONFLICT (user_id) DO NOTHING;
