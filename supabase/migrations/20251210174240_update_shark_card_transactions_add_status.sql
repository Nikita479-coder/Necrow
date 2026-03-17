/*
  # Update Shark Card Transactions - Add Status Column

  1. Changes
    - Add `status` column if it doesn't exist
    - Add `processed_at` column if it doesn't exist
    - Update create_card_transaction function to support status

  2. Notes
    - Existing transactions will have status set to 'approved' by default
*/

-- Add status column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_card_transactions' AND column_name = 'status'
  ) THEN
    ALTER TABLE shark_card_transactions ADD COLUMN status text DEFAULT 'approved';
    ALTER TABLE shark_card_transactions ADD CONSTRAINT valid_status CHECK (status IN ('approved', 'declined', 'pending'));
  END IF;
END $$;

-- Add processed_at column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'shark_card_transactions' AND column_name = 'processed_at'
  ) THEN
    ALTER TABLE shark_card_transactions ADD COLUMN processed_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Drop and recreate the function with status support
DROP FUNCTION IF EXISTS create_card_transaction(uuid, text, numeric, text, text, text);

CREATE OR REPLACE FUNCTION create_card_transaction(
  p_user_id uuid,
  p_description text,
  p_amount numeric,
  p_transaction_type text DEFAULT 'card',
  p_status text DEFAULT 'approved',
  p_merchant text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_card_id uuid;
  v_transaction_id uuid;
  v_is_admin boolean;
BEGIN
  -- Check if caller is admin
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE user_id = auth.uid();

  IF NOT COALESCE(v_is_admin, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Get user's card ID
  SELECT id INTO v_card_id
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
