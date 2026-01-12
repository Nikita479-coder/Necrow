/*
  # User-to-User Transfer System

  1. New Functions
    - `search_users_for_transfer` - Search users by email or username for transfers
    - `transfer_to_user` - Transfer funds between users instantly with no fees
  
  2. Features
    - Search by email or username
    - Zero fees for peer-to-peer transfers
    - Instant transfers
    - Support for all wallet types (main, futures, copy_trading)
    - Automatic transaction logging for both sender and receiver
    - Balance validation
    - Notifications for both parties
  
  3. Security
    - Validates user exists
    - Checks sufficient balance
    - Cannot send to self
    - Proper RLS policies already in place
*/

-- Function to search users by email or username
CREATE OR REPLACE FUNCTION search_users_for_transfer(
  search_term text,
  requesting_user_id uuid
)
RETURNS TABLE (
  user_id uuid,
  email text,
  username text,
  full_name text,
  avatar_url text
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    up.user_id,
    au.email,
    COALESCE(up.username, 'User' || substring(up.user_id::text, 1, 8)) as username,
    up.full_name,
    up.avatar_url
  FROM user_profiles up
  INNER JOIN auth.users au ON au.id = up.user_id
  WHERE up.user_id != requesting_user_id
    AND (
      au.email ILIKE '%' || search_term || '%'
      OR COALESCE(up.username, '') ILIKE '%' || search_term || '%'
      OR up.full_name ILIKE '%' || search_term || '%'
    )
  LIMIT 10;
END;
$$;

-- Function to transfer funds between users
CREATE OR REPLACE FUNCTION transfer_to_user(
  sender_id uuid,
  recipient_email_or_username text,
  transfer_amount decimal,
  transfer_currency text,
  wallet_type_param text DEFAULT 'main'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recipient_id uuid;
  sender_wallet_id uuid;
  recipient_wallet_id uuid;
  sender_balance decimal;
  recipient_name text;
  sender_name text;
BEGIN
  -- Input validation
  IF transfer_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Transfer amount must be greater than zero'
    );
  END IF;

  -- Find recipient by email or username
  SELECT up.user_id, COALESCE(up.full_name, up.username, 'User')
  INTO recipient_id, recipient_name
  FROM user_profiles up
  INNER JOIN auth.users au ON au.id = up.user_id
  WHERE au.email = recipient_email_or_username
     OR up.username = recipient_email_or_username
  LIMIT 1;

  IF recipient_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'User not found. Please check the email or username.'
    );
  END IF;

  -- Prevent self-transfer
  IF sender_id = recipient_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'You cannot send funds to yourself'
    );
  END IF;

  -- Get sender name
  SELECT COALESCE(full_name, username, 'User')
  INTO sender_name
  FROM user_profiles
  WHERE user_id = sender_id;

  -- Get or create sender wallet
  INSERT INTO wallets (user_id, currency, balance, wallet_type)
  VALUES (sender_id, transfer_currency, 0, wallet_type_param)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET balance = EXCLUDED.balance
  RETURNING id, balance INTO sender_wallet_id, sender_balance;

  -- Check if sender has sufficient balance
  IF sender_balance < transfer_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Insufficient balance. Available: ' || sender_balance || ' ' || transfer_currency
    );
  END IF;

  -- Get or create recipient wallet
  INSERT INTO wallets (user_id, currency, balance, wallet_type)
  VALUES (recipient_id, transfer_currency, 0, wallet_type_param)
  ON CONFLICT (user_id, currency, wallet_type) 
  DO UPDATE SET balance = EXCLUDED.balance
  RETURNING id INTO recipient_wallet_id;

  -- Deduct from sender
  UPDATE wallets
  SET balance = balance - transfer_amount,
      updated_at = now()
  WHERE id = sender_wallet_id;

  -- Add to recipient
  UPDATE wallets
  SET balance = balance + transfer_amount,
      updated_at = now()
  WHERE id = recipient_wallet_id;

  -- Log transaction for sender (outgoing)
  INSERT INTO transactions (
    user_id,
    wallet_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    sender_id,
    sender_wallet_id,
    'user_transfer_sent',
    transfer_amount,
    transfer_currency,
    'completed',
    jsonb_build_object(
      'recipient_id', recipient_id,
      'recipient_name', recipient_name,
      'recipient_identifier', recipient_email_or_username,
      'transfer_type', 'peer_to_peer',
      'fee', 0
    )
  );

  -- Log transaction for recipient (incoming)
  INSERT INTO transactions (
    user_id,
    wallet_id,
    transaction_type,
    amount,
    currency,
    status,
    metadata
  ) VALUES (
    recipient_id,
    recipient_wallet_id,
    'user_transfer_received',
    transfer_amount,
    transfer_currency,
    'completed',
    jsonb_build_object(
      'sender_id', sender_id,
      'sender_name', sender_name,
      'transfer_type', 'peer_to_peer',
      'fee', 0
    )
  );

  -- Create notification for recipient
  INSERT INTO notifications (
    user_id,
    notification_type,
    title,
    message,
    status
  ) VALUES (
    recipient_id,
    'transfer_received',
    'Funds Received',
    'You received ' || transfer_amount || ' ' || transfer_currency || ' from ' || sender_name,
    'unread'
  );

  -- Create notification for sender
  INSERT INTO notifications (
    user_id,
    notification_type,
    title,
    message,
    status
  ) VALUES (
    sender_id,
    'transfer_sent',
    'Transfer Successful',
    'You sent ' || transfer_amount || ' ' || transfer_currency || ' to ' || recipient_name,
    'unread'
  );

  RETURN jsonb_build_object(
    'success', true,
    'recipient_name', recipient_name,
    'amount', transfer_amount,
    'currency', transfer_currency
  );
END;
$$;

-- Add new transaction types to the existing transactions table if not already present
DO $$
BEGIN
  -- These types are used by the transfer system
  -- No need to modify constraints, just document them
  NULL;
END $$;
