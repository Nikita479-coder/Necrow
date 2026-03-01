/*
  # Fix get_whitelisted_wallets Function

  Fixes SQL error where created_at was being used incorrectly with GROUP BY.
  The function should use json_agg with ORDER BY, not GROUP BY.
*/

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

  SELECT json_agg(w ORDER BY w.created_at DESC)
  INTO v_wallets
  FROM (
    SELECT 
      id,
      wallet_address,
      label,
      currency,
      network,
      created_at,
      last_used_at
    FROM whitelisted_wallets
    WHERE user_id = v_user_id
    AND (p_currency IS NULL OR currency = p_currency)
  ) w;

  RETURN json_build_object('success', true, 'wallets', COALESCE(v_wallets, '[]'::json));
END;
$$;
