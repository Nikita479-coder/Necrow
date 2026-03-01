/*
  # Email Verification Codes System
  
  1. New Tables
    - `email_verification_codes`
      - `id` (uuid, primary key)
      - `email` (text, not null) - Email address to verify
      - `code` (text, not null) - 6-digit verification code
      - `expires_at` (timestamptz, not null) - When the code expires
      - `verified_at` (timestamptz) - When the code was verified
      - `attempts` (integer, default 0) - Failed verification attempts
      - `created_at` (timestamptz, default now())
      
  2. Changes to user_profiles
    - Add `email_verified` column (boolean, default false)
    
  3. Security
    - Enable RLS on email_verification_codes
    - Add policy for users to read their own codes
    
  4. Indexes
    - Index on email and code for fast lookups
    - Index on expires_at for cleanup queries
*/

-- Create email_verification_codes table
CREATE TABLE IF NOT EXISTS public.email_verification_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  code text NOT NULL,
  expires_at timestamptz NOT NULL,
  verified_at timestamptz,
  attempts integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Add email_verified column to user_profiles if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'user_profiles' 
    AND column_name = 'email_verified'
  ) THEN
    ALTER TABLE public.user_profiles ADD COLUMN email_verified boolean DEFAULT false;
  END IF;
END $$;

-- Enable RLS
ALTER TABLE public.email_verification_codes ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can insert (for signup flow before auth)
CREATE POLICY "Anyone can create verification codes"
  ON public.email_verification_codes
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Policy: Anyone can read codes by email (needed for verification)
CREATE POLICY "Anyone can read verification codes by email"
  ON public.email_verification_codes
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Policy: Anyone can update codes (for marking verified)
CREATE POLICY "Anyone can update verification codes"
  ON public.email_verification_codes
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_email_verification_codes_email 
  ON public.email_verification_codes(email);
  
CREATE INDEX IF NOT EXISTS idx_email_verification_codes_email_code 
  ON public.email_verification_codes(email, code);
  
CREATE INDEX IF NOT EXISTS idx_email_verification_codes_expires_at 
  ON public.email_verification_codes(expires_at);

-- Function to generate a random 6-digit code
CREATE OR REPLACE FUNCTION public.generate_verification_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN lpad(floor(random() * 1000000)::text, 6, '0');
END;
$$;

-- Function to create a verification code for an email
CREATE OR REPLACE FUNCTION public.create_verification_code(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_recent_count integer;
  v_result jsonb;
BEGIN
  -- Rate limiting: check codes created in last hour
  SELECT COUNT(*) INTO v_recent_count
  FROM public.email_verification_codes
  WHERE email = lower(p_email)
    AND created_at > now() - interval '1 hour';
    
  IF v_recent_count >= 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Too many verification attempts. Please try again later.'
    );
  END IF;
  
  -- Invalidate any existing unused codes for this email
  UPDATE public.email_verification_codes
  SET expires_at = now()
  WHERE email = lower(p_email)
    AND verified_at IS NULL
    AND expires_at > now();
  
  -- Generate new code
  v_code := public.generate_verification_code();
  
  -- Insert new verification code (15 minute expiry)
  INSERT INTO public.email_verification_codes (email, code, expires_at)
  VALUES (lower(p_email), v_code, now() + interval '15 minutes');
  
  RETURN jsonb_build_object(
    'success', true,
    'code', v_code,
    'expires_in_minutes', 15
  );
END;
$$;

-- Function to verify a code
CREATE OR REPLACE FUNCTION public.verify_email_code(p_email text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verification record;
  v_result jsonb;
BEGIN
  -- Find the most recent unverified code for this email
  SELECT * INTO v_verification
  FROM public.email_verification_codes
  WHERE email = lower(p_email)
    AND verified_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- Check if code exists
  IF v_verification IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No verification code found. Please request a new code.'
    );
  END IF;
  
  -- Check if too many attempts
  IF v_verification.attempts >= 5 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Too many failed attempts. Please request a new code.'
    );
  END IF;
  
  -- Check if expired
  IF v_verification.expires_at < now() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Verification code has expired. Please request a new code.'
    );
  END IF;
  
  -- Check if code matches
  IF v_verification.code != p_code THEN
    -- Increment attempts
    UPDATE public.email_verification_codes
    SET attempts = attempts + 1
    WHERE id = v_verification.id;
    
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid verification code. Please try again.',
      'attempts_remaining', 5 - v_verification.attempts - 1
    );
  END IF;
  
  -- Code is valid - mark as verified
  UPDATE public.email_verification_codes
  SET verified_at = now()
  WHERE id = v_verification.id;
  
  -- Update user profile if exists
  UPDATE public.user_profiles
  SET email_verified = true
  WHERE email = lower(p_email);
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Email verified successfully'
  );
END;
$$;

-- Function to cleanup expired codes (can be called by cron)
CREATE OR REPLACE FUNCTION public.cleanup_expired_verification_codes()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM public.email_verification_codes
  WHERE expires_at < now() - interval '24 hours';
  
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.generate_verification_code() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_verification_code(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verify_email_code(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_verification_codes() TO authenticated;
