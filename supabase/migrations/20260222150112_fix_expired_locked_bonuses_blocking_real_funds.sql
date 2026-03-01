/*
  # Fix expired locked bonuses blocking real funds

  1. Problem
    - 324 locked bonus records across 271 users have expired (expires_at < NOW())
      but are still marked status = 'active', blocking transfers and withdrawals
    - Three key functions (get_wallet_balances, get_futures_transferable_balance,
      check_withdrawal_allowed) query locked_bonuses with status = 'active' but
      do NOT check expires_at, so expired bonuses still count against users
    - The expire_locked_bonuses() function incorrectly tries to deduct bonus
      amounts from futures wallets, but since the double-credit fix (Feb 12),
      bonus funds only exist in the locked_bonuses table, not in the wallet

  2. Changes
    - Expire all 324 stale locked_bonuses records (status -> 'expired')
    - Fix get_wallet_balances to add expires_at filter
    - Fix get_futures_transferable_balance to add expires_at filter
    - Fix check_withdrawal_allowed to add expires_at filter
    - Fix expire_locked_bonuses to NOT deduct from futures wallets
      (bonus funds are virtual, not in the wallet)

  3. Impact
    - 271 users will immediately have correct transferable/withdrawable balances
    - Future expired bonuses will be ignored by balance calculations even if
      the expire job hasn't run yet (defense in depth)
*/

-- Step 1: Expire all stale locked_bonuses records
UPDATE locked_bonuses
SET status = 'expired', updated_at = now()
WHERE status = 'active'
  AND is_unlocked = false
  AND expires_at IS NOT NULL
  AND expires_at < now();

-- Also expire the matching user_bonuses records
UPDATE user_bonuses ub
SET status = 'expired'
FROM locked_bonuses lb
WHERE ub.locked_bonus_id = lb.id
  AND lb.status = 'expired'
  AND ub.status = 'active';


-- Step 2: Fix get_wallet_balances - add expires_at filter
CREATE OR REPLACE FUNCTION get_wallet_balances(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_main_balance numeric := 0;
  v_main_locked numeric := 0;
  v_copy_balance numeric := 0;
  v_copy_locked numeric := 0;
  v_allocated_to_traders numeric := 0;
  v_futures_available numeric := 0;
  v_futures_locked numeric := 0;
  v_locked_bonus_balance numeric := 0;
  v_locked_bonus_profits numeric := 0;
  v_margin_in_positions numeric := 0;
  v_total_locked_bonus numeric := 0;
  v_futures_transferable numeric := 0;
BEGIN
  SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
  INTO v_main_balance, v_main_locked
  FROM wallets
  WHERE user_id = p_user_id
    AND currency = 'USDT'
    AND wallet_type = 'main';

  SELECT COALESCE(balance, 0), COALESCE(locked_balance, 0)
  INTO v_copy_balance, v_copy_locked
  FROM wallets
  WHERE user_id = p_user_id
    AND currency = 'USDT'
    AND wallet_type = 'copy';

  SELECT COALESCE(SUM(
    COALESCE(initial_balance::numeric, 0) + COALESCE(cumulative_pnl::numeric, 0)
  ), 0)
  INTO v_allocated_to_traders
  FROM copy_relationships
  WHERE follower_id = p_user_id
    AND is_active = true
    AND is_mock = false;

  SELECT COALESCE(available_balance, 0), COALESCE(locked_balance, 0)
  INTO v_futures_available, v_futures_locked
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  SELECT
    COALESCE(SUM(current_amount), 0),
    COALESCE(SUM(realized_profits), 0)
  INTO v_locked_bonus_balance, v_locked_bonus_profits
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status = 'active'
    AND is_unlocked = false
    AND (expires_at IS NULL OR expires_at > now());

  v_total_locked_bonus := v_locked_bonus_balance + v_locked_bonus_profits;
  v_futures_transferable := GREATEST(v_futures_available - v_total_locked_bonus, 0);

  SELECT COALESCE(SUM(margin_allocated), 0)
  INTO v_margin_in_positions
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'open';

  RETURN jsonb_build_object(
    'main_wallet', v_main_balance,
    'main_locked', v_main_locked,
    'main_available', GREATEST(v_main_balance - v_main_locked, 0),
    'copy_wallet', v_copy_balance,
    'copy_locked', v_copy_locked,
    'copy_allocated', v_allocated_to_traders,
    'copy_available', GREATEST(v_copy_balance - v_copy_locked - v_allocated_to_traders, 0),
    'futures_available', v_futures_available,
    'futures_locked', v_futures_locked,
    'futures_transferable', v_futures_transferable,
    'futures_locked_bonus', v_total_locked_bonus,
    'futures', jsonb_build_object(
      'available_balance', v_futures_available,
      'locked_balance', v_futures_locked,
      'total_equity', v_futures_available + v_futures_locked,
      'margin_in_positions', v_margin_in_positions,
      'transferable', v_futures_transferable,
      'locked_bonus', v_total_locked_bonus
    ),
    'locked_bonus', jsonb_build_object(
      'balance', v_locked_bonus_balance
    ),
    'total_trading_available', v_futures_available + v_locked_bonus_balance
  );
END;
$$;


-- Step 3: Fix get_futures_transferable_balance - add expires_at filter
CREATE OR REPLACE FUNCTION get_futures_transferable_balance(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_available_balance numeric := 0;
  v_locked_bonus_amount numeric := 0;
  v_locked_profits numeric := 0;
  v_total_locked numeric := 0;
  v_transferable numeric := 0;
BEGIN
  SELECT COALESCE(available_balance, 0) INTO v_available_balance
  FROM futures_margin_wallets
  WHERE user_id = p_user_id;

  SELECT
    COALESCE(SUM(current_amount), 0),
    COALESCE(SUM(realized_profits), 0)
  INTO v_locked_bonus_amount, v_locked_profits
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND is_unlocked = false
    AND status = 'active'
    AND (expires_at IS NULL OR expires_at > now());

  v_total_locked := v_locked_bonus_amount + v_locked_profits;
  v_transferable := GREATEST(v_available_balance - v_total_locked, 0);

  RETURN jsonb_build_object(
    'total_balance', v_available_balance,
    'locked_bonus', v_locked_bonus_amount,
    'locked_profits', v_locked_profits,
    'total_locked', v_total_locked,
    'transferable', v_transferable,
    'has_locked_bonus', v_total_locked > 0
  );
END;
$$;


-- Step 4: Fix check_withdrawal_allowed - add expires_at filter
CREATE OR REPLACE FUNCTION check_withdrawal_allowed(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked boolean;
  v_reason text;
  v_blocked_at timestamptz;
  v_active_bonus_count integer := 0;
  v_active_bonus_total numeric := 0;
  v_unlocked_bonus_count integer := 0;
  v_volume_required numeric := 0;
  v_volume_completed numeric := 0;
  v_suspended boolean := false;
  v_total_real_deposits numeric := 0;
BEGIN
  SELECT COALESCE(is_suspended, false) INTO v_suspended
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_suspended THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'Your account is suspended. Please contact support.'
    );
  END IF;

  SELECT withdrawal_blocked, withdrawal_block_reason, withdrawal_blocked_at
  INTO v_blocked, v_reason, v_blocked_at
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_blocked THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', COALESCE(v_reason, 'Withdrawals are temporarily blocked. Please contact support.')
    );
  END IF;

  SELECT COALESCE(SUM(amount), 0) INTO v_total_real_deposits
  FROM transactions
  WHERE user_id = p_user_id
    AND transaction_type = 'deposit'
    AND status = 'completed';

  IF v_total_real_deposits > 0 THEN
    RETURN jsonb_build_object(
      'allowed', true,
      'requires_manual_review', false
    );
  END IF;

  SELECT
    COUNT(*),
    COALESCE(SUM(current_amount), 0),
    COALESCE(SUM(bonus_trading_volume_required), 0),
    COALESCE(SUM(bonus_trading_volume_completed), 0)
  INTO v_active_bonus_count, v_active_bonus_total, v_volume_required, v_volume_completed
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND status = 'active'
    AND is_unlocked = false
    AND (expires_at IS NULL OR expires_at > now());

  IF v_active_bonus_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'Withdrawals are not available while you have active trading bonuses. Complete the required trading volume ($' || ROUND(GREATEST(v_volume_required - v_volume_completed, 0), 2) || ' remaining) to unlock your bonus first.',
      'bonus_block', true,
      'active_bonuses', v_active_bonus_count,
      'volume_required', v_volume_required,
      'volume_completed', v_volume_completed,
      'volume_remaining', GREATEST(v_volume_required - v_volume_completed, 0)
    );
  END IF;

  SELECT COUNT(*)
  INTO v_unlocked_bonus_count
  FROM locked_bonuses
  WHERE user_id = p_user_id
    AND is_unlocked = true
    AND unlocked_at >= now() - interval '90 days';

  IF v_unlocked_bonus_count > 0 THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'Your trading bonus has been unlocked. To withdraw funds, please contact our support team who will assist you with the process.',
      'bonus_block', true,
      'contact_support', true,
      'unlocked_bonuses', v_unlocked_bonus_count
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed', true,
    'requires_manual_review', false
  );
END;
$$;


-- Step 5: Fix expire_locked_bonuses - do NOT deduct from futures wallet
-- Since the double-credit fix, bonus funds only exist in locked_bonuses table
CREATE OR REPLACE FUNCTION expire_locked_bonuses()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer := 0;
  v_forfeited_total numeric := 0;
  v_expired_bonus record;
  v_forfeit_amount numeric;
BEGIN
  FOR v_expired_bonus IN
    SELECT id, user_id, original_amount, current_amount, realized_profits, bonus_type_name
    FROM locked_bonuses
    WHERE status = 'active'
      AND expires_at <= now()
      AND is_unlocked = false
  LOOP
    v_forfeit_amount := v_expired_bonus.current_amount + v_expired_bonus.realized_profits;
    v_forfeited_total := v_forfeited_total + v_forfeit_amount;

    UPDATE locked_bonuses
    SET status = 'expired', updated_at = now()
    WHERE id = v_expired_bonus.id;

    UPDATE user_bonuses
    SET status = 'expired'
    WHERE locked_bonus_id = v_expired_bonus.id;

    INSERT INTO notifications (user_id, type, title, message, read, data)
    VALUES (
      v_expired_bonus.user_id,
      'account_update',
      'Locked Bonus Expired',
      'Your locked bonus of $' || ROUND(v_expired_bonus.original_amount, 2) || ' (' || v_expired_bonus.bonus_type_name || ') has expired without meeting unlock requirements.',
      false,
      jsonb_build_object(
        'locked_bonus_id', v_expired_bonus.id,
        'original_amount', v_expired_bonus.original_amount,
        'forfeited_amount', v_forfeit_amount
      )
    );

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'expired_count', v_expired_count,
    'total_forfeited', v_forfeited_total
  );
END;
$$;
