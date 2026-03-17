/*
  # Create Whitelist Management Functions

  1. Functions
    - `add_whitelisted_wallet` - Add a wallet to the whitelist (requires MFA)
    - `remove_whitelisted_wallet` - Remove a wallet from the whitelist
    - `get_whitelisted_wallets` - Get all whitelisted wallets for a user
    - `is_wallet_whitelisted` - Check if a wallet is whitelisted
    - `update_wallet_last_used` - Update the last used timestamp

  2. Security
    - All functions check authentication
    - add_whitelisted_wallet checks MFA status
*/

-- Add a wallet to the whitelist (requires MFA)
CREATE OR REPLACE FUNCTION add_whitelisted_wallet(
  p_wallet_address text,
  p_label text,
  p_currency text,
  p_network text
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_mfa_enabled boolean;
  v_wallet_id uuid;
BEGIN
  -- Get authenticated user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Check if user has MFA enabled
  SELECT EXISTS (
    SELECT 1 FROM auth.mfa_factors
    WHERE user_id = v_user_id
    AND status = 'verified'
  ) INTO v_mfa_enabled;

  IF NOT v_mfa_enabled THEN
    RETURN json_build_object('success', false, 'error', 'MFA_REQUIRED', 'message', 'Two-factor authentication is required to add whitelisted wallets');
  END IF;

  -- Validate inputs
  IF p_wallet_address IS NULL OR p_wallet_address = '' THEN
    RETURN json_build_object('success', false, 'error', 'Wallet address is required');
  END IF;

  IF p_label IS NULL OR p_label = '' THEN
    RETURN json_build_object('success', false, 'error', 'Label is required');
  END IF;

  -- Add wallet to whitelist
  INSERT INTO whitelisted_wallets (user_id, wallet_address, label, currency, network)
  VALUES (v_user_id, p_wallet_address, p_label, p_currency, p_network)
  ON CONFLICT (user_id, wallet_address, currency, network) DO UPDATE
  SET label = EXCLUDED.label
  RETURNING id INTO v_wallet_id;

  RETURN json_build_object(
    'success', true,
    'wallet_id', v_wallet_id,
    'message', 'Wallet added to whitelist successfully'
  );
END;
$$;

-- Remove a wallet from the whitelist
CREATE OR REPLACE FUNCTION remove_whitelisted_wallet(
  p_wallet_id uuid
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  DELETE FROM whitelisted_wallets
  WHERE id = p_wallet_id
  AND user_id = v_user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  RETURN json_build_object('success', true, 'message', 'Wallet removed from whitelist');
END;
$$;

-- Get all whitelisted wallets for the authenticated user
CREATE OR REPLACE FUNCTION get_whitelisted_wallets(
  p_currency text DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_wallets json;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT json_agg(
    json_build_object(
      'id', id,
      'wallet_address', wallet_address,
      'label', label,
      'currency', currency,
      'network', network,
      'created_at', created_at,
      'last_used_at', last_used_at
    )
  )
  INTO v_wallets
  FROM whitelisted_wallets
  WHERE user_id = v_user_id
  AND (p_currency IS NULL OR currency = p_currency)
  ORDER BY created_at DESC;

  RETURN json_build_object('success', true, 'wallets', COALESCE(v_wallets, '[]'::json));
END;
$$;

-- Check if a wallet is whitelisted
CREATE OR REPLACE FUNCTION is_wallet_whitelisted(
  p_wallet_address text,
  p_currency text,
  p_network text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_exists boolean;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM whitelisted_wallets
    WHERE user_id = v_user_id
    AND wallet_address = p_wallet_address
    AND currency = p_currency
    AND network = p_network
  ) INTO v_exists;

  RETURN v_exists;
END;
$$;

-- Update the last used timestamp for a wallet
CREATE OR REPLACE FUNCTION update_wallet_last_used(
  p_wallet_address text,
  p_currency text,
  p_network text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE whitelisted_wallets
  SET last_used_at = now()
  WHERE user_id = v_user_id
  AND wallet_address = p_wallet_address
  AND currency = p_currency
  AND network = p_network;
END;
$$;