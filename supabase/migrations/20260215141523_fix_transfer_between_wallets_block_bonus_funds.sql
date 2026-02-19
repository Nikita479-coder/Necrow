/*
  # Fix transfer_between_wallets: Block locked bonus funds from futures transfers

  1. Changes
    - Recreates `transfer_between_wallets` function with locked bonus protection
    - When transferring FROM futures wallet, calculates total active locked bonus amount
    - Only allows transfer of (available_balance - active_locked_bonus_amount)
    - Prevents users from withdrawing bonus-derived funds via futures -> main transfers

  2. Security
    - Blocks the exploit path: bonus credited to futures -> transfer to main -> withdraw
    - Preserves all existing transfer logic for other wallet types
    - Uses SECURITY DEFINER with restricted search_path
*/

CREATE OR REPLACE FUNCTION public.transfer_between_wallets(
  p_user_id uuid,
  p_from_wallet_type text,
  p_to_wallet_type text,
  p_amount numeric,
  p_currency text DEFAULT 'USDT'
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
  v_locked_bonus_total numeric := 0;
  v_locked_margin_in_positions numeric := 0;
  v_transferable_balance numeric;
BEGIN
  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Amount must be positive');
  END IF;

  IF p_from_wallet_type NOT IN ('main', 'futures', 'copy', 'earn', 'card') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid source wallet type');
  END IF;

  IF p_to_wallet_type NOT IN ('main', 'futures', 'copy', 'earn', 'card') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid destination wallet type');
  END IF;

  IF p_from_wallet_type = p_to_wallet_type THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to the same wallet');
  END IF;

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

  IF p_from_wallet_type = 'futures' THEN
    SELECT available_balance INTO v_from_balance
    FROM futures_margin_wallets
    WHERE user_id = p_user_id;

    IF v_from_balance IS NULL OR v_from_balance < p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance in futures wallet');
    END IF;

    SELECT COALESCE(SUM(lb.current_amount), 0) INTO v_locked_bonus_total
    FROM locked_bonuses lb
    WHERE lb.user_id = p_user_id
      AND lb.status = 'active'
      AND lb.is_unlocked = false;

    SELECT COALESCE(SUM(fp.margin_from_locked_bonus), 0) INTO v_locked_margin_in_positions
    FROM futures_positions fp
    WHERE fp.user_id = p_user_id
      AND fp.status = 'open';

    v_locked_bonus_total := v_locked_bonus_total + v_locked_margin_in_positions;

    v_transferable_balance := GREATEST(v_from_balance - v_locked_bonus_total, 0);

    IF v_transferable_balance < p_amount THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', format(
          'Insufficient transferable balance. Available: $%.2f, Locked bonus: $%.2f, Transferable: $%.2f',
          v_from_balance, v_locked_bonus_total, v_transferable_balance
        )
      );
    END IF;

    UPDATE futures_margin_wallets
    SET available_balance = available_balance - p_amount,
        total_withdrawn = total_withdrawn + p_amount,
        updated_at = now()
    WHERE user_id = p_user_id;

  ELSIF p_from_wallet_type = 'copy' THEN
    SELECT COALESCE(balance, 0) INTO v_from_balance
    FROM wallets
    WHERE user_id = p_user_id
      AND wallet_type = 'copy'
      AND currency = p_currency;

    SELECT COALESCE(SUM(current_balance), 0) INTO v_active_allocations
    FROM copy_relationships
    WHERE follower_id = p_user_id
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

    UPDATE wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND wallet_type = 'copy'
      AND currency = p_currency;

  ELSE
    SELECT COALESCE(balance, 0) INTO v_from_balance
    FROM wallets
    WHERE user_id = p_user_id
      AND wallet_type = p_from_wallet_type
      AND currency = p_currency;

    IF v_from_balance IS NULL OR v_from_balance < p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;

    UPDATE wallets
    SET balance = balance - p_amount,
        updated_at = now()
    WHERE user_id = p_user_id
      AND wallet_type = p_from_wallet_type
      AND currency = p_currency;
  END IF;

  IF p_to_wallet_type = 'futures' THEN
    INSERT INTO futures_margin_wallets (user_id, available_balance, total_deposited, updated_at)
    VALUES (p_user_id, p_amount, p_amount, now())
    ON CONFLICT (user_id) DO UPDATE SET
      available_balance = futures_margin_wallets.available_balance + p_amount,
      total_deposited = futures_margin_wallets.total_deposited + p_amount,
      updated_at = now();
  ELSE
    INSERT INTO wallets (user_id, wallet_type, currency, balance, updated_at)
    VALUES (p_user_id, p_to_wallet_type, p_currency, p_amount, now())
    ON CONFLICT (user_id, wallet_type, currency) DO UPDATE SET
      balance = wallets.balance + p_amount,
      updated_at = now();
  END IF;

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
