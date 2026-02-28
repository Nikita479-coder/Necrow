/*
  # Create Promo Bonus Expiry Processing

  1. Functions
    - `process_expired_promo_bonuses` - Processes all expired promo bonuses
      - Auto-closes copy trading positions
      - Calculates and transfers profits to main wallet
      - Deducts bonus amount from copy wallet
      - Updates redemption status to 'expired'

  2. Changes
    - Handles bonus expiry gracefully
    - Sends notifications to users about expired bonuses
*/

-- Function to process a single expired promo bonus
CREATE OR REPLACE FUNCTION process_single_expired_promo_bonus(
  p_redemption_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_redemption RECORD;
  v_promo RECORD;
  v_copy_wallet RECORD;
  v_relationship RECORD;
  v_total_current_balance numeric := 0;
  v_profits numeric := 0;
  v_positions_closed integer := 0;
BEGIN
  -- Get redemption details
  SELECT * INTO v_redemption
  FROM promo_code_redemptions
  WHERE id = p_redemption_id
    AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Redemption not found or already processed');
  END IF;

  -- Get promo code details
  SELECT * INTO v_promo
  FROM promo_codes
  WHERE id = v_redemption.promo_code_id;

  -- Get user's copy wallet balance
  SELECT * INTO v_copy_wallet
  FROM wallets
  WHERE user_id = v_redemption.user_id
    AND wallet_type = 'copy'
    AND currency = 'USDT';

  IF NOT FOUND THEN
    -- No copy wallet, just mark as expired
    UPDATE promo_code_redemptions
    SET status = 'expired',
        profits_transferred = 0
    WHERE id = p_redemption_id;

    RETURN jsonb_build_object('success', true, 'message', 'No copy wallet found, marked as expired');
  END IF;

  -- Close all active copy trading relationships for this user
  FOR v_relationship IN
    SELECT cr.*, t.name as trader_name
    FROM copy_relationships cr
    LEFT JOIN traders t ON t.id = cr.trader_id
    WHERE cr.follower_id = v_redemption.user_id
      AND cr.is_active = true
      AND cr.is_mock = false
  LOOP
    v_total_current_balance := v_total_current_balance + COALESCE(v_relationship.current_balance, v_relationship.initial_balance);

    -- Close the relationship
    UPDATE copy_relationships
    SET is_active = false,
        status = 'stopped',
        updated_at = now()
    WHERE id = v_relationship.id;

    v_positions_closed := v_positions_closed + 1;
  END LOOP;

  -- Calculate profits (current balance - bonus amount)
  -- If no relationships, use the copy wallet balance
  IF v_total_current_balance = 0 THEN
    v_total_current_balance := COALESCE(v_copy_wallet.balance, 0);
  END IF;

  v_profits := GREATEST(0, v_total_current_balance - v_redemption.bonus_amount);

  -- Transfer profits to main wallet if any
  IF v_profits > 0 THEN
    -- Add to main wallet
    INSERT INTO wallets (user_id, wallet_type, currency, balance, updated_at)
    VALUES (v_redemption.user_id, 'main', 'USDT', v_profits, now())
    ON CONFLICT (user_id, wallet_type, currency)
    DO UPDATE SET
      balance = wallets.balance + v_profits,
      updated_at = now();

    -- Record transfer transaction
    INSERT INTO transactions (
      user_id,
      transaction_type,
      amount,
      currency,
      status,
      details
    ) VALUES (
      v_redemption.user_id,
      'transfer',
      v_profits,
      'USDT',
      'completed',
      jsonb_build_object(
        'type', 'promo_bonus_profit_transfer',
        'promo_code', v_promo.code,
        'description', 'Copy trading profits transferred from expired ' || v_promo.code || ' bonus',
        'from_wallet', 'copy',
        'to_wallet', 'main',
        'bonus_amount', v_redemption.bonus_amount,
        'positions_closed', v_positions_closed
      )
    );
  END IF;

  -- Deduct the bonus amount from copy wallet (it disappears)
  UPDATE wallets
  SET balance = GREATEST(0, balance - v_redemption.bonus_amount),
      updated_at = now()
  WHERE user_id = v_redemption.user_id
    AND wallet_type = 'copy'
    AND currency = 'USDT';

  -- Update redemption status
  UPDATE promo_code_redemptions
  SET status = 'expired',
      profits_transferred = v_profits
  WHERE id = p_redemption_id;

  -- Send notification to user
  INSERT INTO notifications (
    user_id,
    notification_type,
    title,
    message,
    read
  ) VALUES (
    v_redemption.user_id,
    'bonus',
    v_promo.code || ' Bonus Expired',
    'Your ' || v_promo.code || ' copy trading bonus has expired. ' ||
    CASE WHEN v_profits > 0 THEN
      '$' || ROUND(v_profits::numeric, 2) || ' in profits has been transferred to your main wallet.'
    ELSE
      'No profits were generated during the bonus period.'
    END ||
    CASE WHEN v_positions_closed > 0 THEN
      ' ' || v_positions_closed || ' copy trading position(s) were closed.'
    ELSE
      ''
    END,
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_redemption.user_id,
    'promo_code', v_promo.code,
    'bonus_amount', v_redemption.bonus_amount,
    'profits_transferred', v_profits,
    'positions_closed', v_positions_closed
  );
END;
$$;

-- Function to process all expired promo bonuses
CREATE OR REPLACE FUNCTION process_all_expired_promo_bonuses()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_redemption RECORD;
  v_results jsonb := '[]'::jsonb;
  v_result jsonb;
  v_processed integer := 0;
BEGIN
  -- Find all expired but still active redemptions
  FOR v_redemption IN
    SELECT id
    FROM promo_code_redemptions
    WHERE status = 'active'
      AND bonus_expires_at <= now()
  LOOP
    v_result := process_single_expired_promo_bonus(v_redemption.id);
    v_results := v_results || v_result;
    v_processed := v_processed + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'processed_count', v_processed,
    'results', v_results
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION process_single_expired_promo_bonus TO authenticated;
GRANT EXECUTE ON FUNCTION process_all_expired_promo_bonuses TO authenticated;
