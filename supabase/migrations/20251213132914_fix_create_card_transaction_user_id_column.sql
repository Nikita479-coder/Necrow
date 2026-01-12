/*
  # Fix create_card_transaction function

  1. Changes
    - Fix column reference from `user_id` to `id` when querying user_profiles table
    - The user_profiles table uses `id` as the primary key, not `user_id`
*/

CREATE OR REPLACE FUNCTION create_card_transaction(
  p_user_id uuid,
  p_description text,
  p_amount numeric,
  p_transaction_type text DEFAULT 'purchase',
  p_status text DEFAULT 'approved',
  p_merchant text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_card_id uuid;
  v_transaction_id uuid;
  v_is_admin boolean;
BEGIN
  -- Check if caller is admin (using 'id' column, not 'user_id')
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = auth.uid();

  IF NOT COALESCE(v_is_admin, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Get user's card ID
  SELECT card_id INTO v_card_id
  FROM shark_cards
  WHERE user_id = p_user_id
  AND status = 'active';

  IF v_card_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User does not have an active card');
  END IF;

  -- Insert transaction
  INSERT INTO shark_card_transactions (
    card_id,
    user_id,
    description,
    amount,
    transaction_type,
    status,
    merchant
  ) VALUES (
    v_card_id,
    p_user_id,
    p_description,
    p_amount,
    p_transaction_type,
    p_status,
    p_merchant
  ) RETURNING transaction_id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id
  );
END;
$$;