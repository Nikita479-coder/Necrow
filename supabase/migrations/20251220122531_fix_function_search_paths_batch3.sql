/*
  # Fix Function Search Paths - Batch 3

  ## Description
  Final batch of search_path fixes for remaining SECURITY DEFINER functions.
*/

-- Drop and recreate functions that have signature issues
DROP FUNCTION IF EXISTS initialize_mock_trading(uuid);
DROP FUNCTION IF EXISTS initialize_referral_stats(uuid);
DROP FUNCTION IF EXISTS insert_kyc_document(uuid, text, bytea, text, text);
DROP FUNCTION IF EXISTS record_trading_fee(uuid, text, numeric, text, uuid);
DROP FUNCTION IF EXISTS setup_demo_user(uuid);
DROP FUNCTION IF EXISTS update_user_vip_level(uuid);

-- Recreate initialize_mock_trading
CREATE FUNCTION initialize_mock_trading(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id uuid;
BEGIN
  INSERT INTO mock_trading_accounts (user_id, balance, initial_balance, is_active)
  VALUES (p_user_id, 100000, 100000, true)
  ON CONFLICT (user_id) DO UPDATE SET is_active = true
  RETURNING id INTO v_account_id;
  RETURN jsonb_build_object('success', true, 'account_id', v_account_id, 'balance', 100000);
END;
$$;

-- Recreate initialize_referral_stats
CREATE FUNCTION initialize_referral_stats(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO referral_stats (user_id, total_referrals, active_referrals, total_earnings, monthly_earnings, vip_level)
  VALUES (p_user_id, 0, 0, 0, 0, 1)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;

-- Recreate insert_kyc_document
CREATE FUNCTION insert_kyc_document(
  p_user_id uuid,
  p_document_type text,
  p_file_data bytea,
  p_mime_type text,
  p_file_name text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_id uuid;
BEGIN
  INSERT INTO kyc_documents (user_id, document_type, file_data, mime_type, file_name, status)
  VALUES (p_user_id, p_document_type, p_file_data, p_mime_type, p_file_name, 'pending')
  RETURNING id INTO v_doc_id;
  RETURN v_doc_id;
END;
$$;

-- Recreate record_trading_fee
CREATE FUNCTION record_trading_fee(
  p_user_id uuid,
  p_pair text,
  p_fee_amount numeric,
  p_fee_type text,
  p_position_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fee_id uuid;
BEGIN
  INSERT INTO fee_collections (user_id, pair, fee_amount, fee_type, position_id, created_at)
  VALUES (p_user_id, p_pair, p_fee_amount, p_fee_type, p_position_id, now())
  RETURNING id INTO v_fee_id;
  RETURN v_fee_id;
END;
$$;

-- Recreate update_user_vip_level
CREATE FUNCTION update_user_vip_level(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_volume numeric;
  v_new_level integer;
BEGIN
  v_volume := calculate_user_30d_volume(p_user_id);
  SELECT vip_level INTO v_new_level FROM vip_levels
  WHERE v_volume >= volume_required ORDER BY vip_level DESC LIMIT 1;
  IF v_new_level IS NULL THEN v_new_level := 1; END IF;
  UPDATE referral_stats SET vip_level = v_new_level WHERE user_id = p_user_id;
  INSERT INTO user_vip_status (user_id, vip_level, volume_30d)
  VALUES (p_user_id, v_new_level, v_volume)
  ON CONFLICT (user_id) DO UPDATE SET vip_level = v_new_level, volume_30d = v_volume, updated_at = now();
END;
$$;
