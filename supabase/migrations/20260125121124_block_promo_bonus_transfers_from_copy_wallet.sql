/*
  # Block Promo Bonus Transfers from Copy Wallet

  1. Changes
    - Update transfer_between_wallets function to check for active promo code redemptions
    - If user has active copy_trading_only promo bonus, block transfers FROM copy wallet
    - Users can still receive transfers TO copy wallet
    - This protects promo bonus funds from being moved to other wallets

  2. Security
    - Prevents promo code abuse by transferring bonus to futures/main wallet
*/

CREATE OR REPLACE FUNCTION transfer_between_wallets(
  p_user_id uuid,
  p_from_wallet_type text,
  p_to_wallet_type text,
  p_currency text,
  p_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_balance numeric;
  v_available_balance numeric;
  v_active_allocations numeric;
  v_active_promo_bonus numeric := 0;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  -- Validate wallet types
  IF p_from_wallet_type NOT IN ('main', 'futures', 'copy', 'earn', 'card') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF p_to_wallet_type NOT IN ('main', 'futures', 'copy', 'earn', 'card') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  IF p_from_wallet_type = p_to_wallet_type THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to the same wallet');
  END IF;

  -- Check for active promo bonus if transferring FROM copy wallet
  IF p_from_wallet_type = 'copy' THEN
    SELECT COALESCE(SUM(pcr.bonus_amount), 0) INTO v_active_promo_bonus
    FROM promo_code_redemptions pcr
    JOIN promo_codes pc ON pc.id = pcr.promo_code_id
    WHERE pcr.user_id = p_user_id
    AND pcr.status = 'active'
    AND pcr.bonus_expires_at > now()
    AND pc.bonus_type = 'copy_trading_only';

    IF v_active_promo_bonus > 0 THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', 'Cannot transfer promo bonus funds. The $' || ROUND(v_active_promo_bonus, 2) || ' copy trading bonus can only be used for copy trading. You can withdraw any profits you make, but not the bonus itself.'
      );
    END IF;
  END IF;

  -- Handle transfers FROM futures wallet
  IF p_from_wallet_type = 'futures' THEN
    SELECT available_balance INTO v_from_balance
    FROM futures_margin_wallets
    WHERE user_id = p_user_id;

    IF v_from_balance IS NULL OR v_from_balance < p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance in futures wallet');
    END IF;

    -- Deduct from futures wallet
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - p_amount,
        total_withdrawn = total_withdrawn + p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

  -- Handle transfers FROM copy wallet
  ELSIF p_from_wallet_type = 'copy' THEN
    SELECT COALESCE(balance, 0) INTO v_from_balance
    FROM wallets
    WHERE user_id = p_user_id
    AND wallet_type = 'copy'
    AND currency = p_currency;

    -- Calculate active allocations (funds in use by copy trading)
    SELECT COALESCE(SUM(current_balance), 0) INTO v_active_allocations
    FROM copy_relationships
    WHERE user_id = p_user_id
    AND is_active = true
    AND status IN ('active', 'pending');

    v_available_balance := COALESCE(v_from_balance, 0) - v_active_allocations;

    IF v_available_balance < p_amount THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', format('Insufficient available balance. Available: $%.2f (Total: $%.2f, Allocated: $%.2f)', 
          v_available_balance, v_from_balance, v_active_allocations)
      );
    END IF;

    -- Deduct from copy wallet
    UPDATE wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id
    AND wallet_type = 'copy'
    AND currency = p_currency;

  -- Handle transfers FROM main wallet
  ELSE
    SELECT COALESCE(balance, 0) INTO v_from_balance
    FROM wallets
    WHERE user_id = p_user_id
    AND wallet_type = p_from_wallet_type
    AND currency = p_currency;

    IF v_from_balance IS NULL OR v_from_balance < p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;

    -- Deduct from source wallet
    UPDATE wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id
    AND wallet_type = p_from_wallet_type
    AND currency = p_currency;
  END IF;

  -- Handle transfers TO futures wallet
  IF p_to_wallet_type = 'futures' THEN
    INSERT INTO futures_margin_wallets (user_id, available_balance, total_deposited, updated_at)
    VALUES (p_user_id, p_amount, p_amount, now())
    ON CONFLICT (user_id) DO UPDATE SET
      available_balance = futures_margin_wallets.available_balance + p_amount,
      total_deposited = futures_margin_wallets.total_deposited + p_amount,
      updated_at = now();

  -- Handle transfers TO other wallets
  ELSE
    INSERT INTO wallets (user_id, wallet_type, currency, balance, updated_at)
    VALUES (p_user_id, p_to_wallet_type, p_currency, p_amount, now())
    ON CONFLICT (user_id, wallet_type, currency) DO UPDATE SET
      balance = wallets.balance + p_amount,
      updated_at = now();
  END IF;

  -- Log the transfer
  INSERT INTO transactions (
    user_id,
    transaction_type,
    amount,
    currency,
    status,
    details
  ) VALUES (
    p_user_id,
    'transfer',
    p_amount,
    p_currency,
    'completed',
    jsonb_build_object(
      'from_wallet', p_from_wallet_type,
      'to_wallet', p_to_wallet_type,
      'description', 'Internal transfer from ' || p_from_wallet_type || ' to ' || p_to_wallet_type
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Transfer completed successfully',
    'amount', p_amount,
    'from', p_from_wallet_type,
    'to', p_to_wallet_type
  );
END;
$$;
