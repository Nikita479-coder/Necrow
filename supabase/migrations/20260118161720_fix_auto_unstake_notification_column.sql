/*
  # Fix Auto-Unstake Notification Column Name

  ## Summary
  The auto_unstake_expired_flexible_stakes function was using 'notification_type'
  instead of the correct column name 'type' for the notifications table.

  ## Changes
  - Fixes column name from 'notification_type' to 'type'
*/

CREATE OR REPLACE FUNCTION auto_unstake_expired_flexible_stakes()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stake RECORD;
  v_product RECORD;
  v_assets_wallet RECORD;
  v_main_wallet RECORD;
  v_total_amount numeric;
  v_unstaked_count int := 0;
  v_errors text[] := '{}';
BEGIN
  FOR v_stake IN 
    SELECT us.*, ep.coin, ep.product_type, ep.is_new_user_exclusive
    FROM user_stakes us
    JOIN earn_products ep ON us.product_id = ep.id
    WHERE us.status = 'active'
      AND us.end_date IS NOT NULL
      AND us.end_date <= now()
      AND ep.product_type = 'flexible'
      AND ep.is_new_user_exclusive = true
  LOOP
    BEGIN
      SELECT * INTO v_assets_wallet
      FROM wallets
      WHERE user_id = v_stake.user_id 
        AND currency = v_stake.coin 
        AND wallet_type = 'assets'
      FOR UPDATE;

      SELECT * INTO v_main_wallet
      FROM wallets
      WHERE user_id = v_stake.user_id 
        AND currency = v_stake.coin 
        AND wallet_type = 'main'
      FOR UPDATE;

      IF NOT FOUND THEN
        INSERT INTO wallets (user_id, currency, wallet_type, balance, locked_balance)
        VALUES (v_stake.user_id, v_stake.coin, 'main', 0, 0)
        RETURNING * INTO v_main_wallet;
      END IF;

      v_total_amount := v_stake.amount + v_stake.earned_rewards;

      UPDATE wallets
      SET balance = balance + v_total_amount,
          updated_at = now()
      WHERE id = v_main_wallet.id;

      UPDATE wallets
      SET locked_balance = GREATEST(0, locked_balance - v_stake.amount),
          updated_at = now()
      WHERE id = v_assets_wallet.id;

      UPDATE user_stakes
      SET status = 'completed',
          updated_at = now()
      WHERE id = v_stake.id;

      UPDATE earn_products
      SET invested_amount = GREATEST(0, invested_amount - v_stake.amount),
          updated_at = now()
      WHERE id = v_stake.product_id;

      INSERT INTO transactions (
        user_id,
        transaction_type,
        currency,
        amount,
        status,
        details
      ) VALUES (
        v_stake.user_id,
        'unstake',
        v_stake.coin,
        v_total_amount,
        'completed',
        'Auto-unstaked after 3-day promotional period. Principal: ' || v_stake.amount || ', Rewards: ' || v_stake.earned_rewards
      );

      INSERT INTO notifications (user_id, type, title, message, read)
      VALUES (
        v_stake.user_id,
        'system',
        'Staking Period Ended',
        'Your ' || v_stake.amount || ' ' || v_stake.coin || ' stake has completed after the 3-day promotional period. ' || v_total_amount || ' ' || v_stake.coin || ' has been returned to your wallet.',
        false
      );

      v_unstaked_count := v_unstaked_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := array_append(v_errors, 'Stake ' || v_stake.id || ': ' || SQLERRM);
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'unstaked_count', v_unstaked_count,
    'errors', v_errors
  );
END;
$$;
