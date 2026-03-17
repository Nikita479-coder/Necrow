/*
  # Revert exclusive affiliate withdrawal minimum to $10

  1. Changes
    - Updates the minimum withdrawal amount in `request_exclusive_affiliate_withdrawal`
      back to $10 from $100 for exclusive affiliate wallet to main wallet transfers
    - Makes it consistent with regular user withdrawal minimums

  2. Security
    - No changes to RLS or policies
*/

CREATE OR REPLACE FUNCTION public.request_exclusive_affiliate_withdrawal(
  p_user_id uuid,
  p_amount numeric,
  p_wallet_address text DEFAULT NULL,
  p_network text DEFAULT 'TRC20'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_balance exclusive_affiliate_balances;
  v_withdrawal_id uuid;
  v_wallet_id uuid;
BEGIN
  IF NOT is_exclusive_affiliate(p_user_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not enrolled in exclusive affiliate program');
  END IF;

  SELECT * INTO v_balance
  FROM exclusive_affiliate_balances
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND OR v_balance.available_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  IF p_amount < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Minimum withdrawal is $10');
  END IF;

  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id AND currency = 'USDT' AND wallet_type = 'main';

  IF NOT FOUND THEN
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (p_user_id, 'USDT', 0, 'main')
    RETURNING id INTO v_wallet_id;
  END IF;

  UPDATE exclusive_affiliate_balances
  SET
    available_balance = available_balance - p_amount,
    total_withdrawn = total_withdrawn + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id;

  UPDATE wallets
  SET
    balance = balance + p_amount,
    updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO transactions (
    user_id, transaction_type, amount, currency, status, details
  ) VALUES (
    p_user_id, 'affiliate_withdrawal', p_amount, 'USDT', 'completed',
    jsonb_build_object('source', 'exclusive_affiliate', 'destination', 'main_wallet', 'wallet_id', v_wallet_id)
  );

  INSERT INTO exclusive_affiliate_withdrawals (
    user_id, amount, currency, wallet_address, network, status, processed_at
  ) VALUES (
    p_user_id, p_amount, 'USDT',
    COALESCE(p_wallet_address, 'Main Wallet Transfer'),
    p_network, 'completed', now()
  )
  RETURNING id INTO v_withdrawal_id;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id, 'withdrawal_approved', 'Affiliate Earnings Transferred',
    'Your affiliate earnings of $' || p_amount || ' USDT have been transferred to your main wallet.',
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'withdrawal_id', v_withdrawal_id,
    'amount', p_amount,
    'destination', 'main_wallet'
  );
END;
$function$;
