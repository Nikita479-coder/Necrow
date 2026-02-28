/*
  # Fix apply_pnl_to_locked_bonus to Deduct Remaining Loss from Wallet
  
  ## Problem
  When closing futures positions with negative PnL:
  1. The apply_pnl_to_locked_bonus function only deducts from locked bonuses
  2. If there's remaining loss after depleting locked bonuses (or if user has no locked bonuses),
     it does NOT deduct from the futures wallet
  3. This causes losses to not be reflected in the wallet balance
  
  ## Solution
  After deducting from locked bonuses, deduct any remaining loss from the futures_margin_wallets.
  
  ## Example
  - User closes position with -$200 loss and no locked bonuses
  - Before fix: Loss tracked in position but wallet stays at $50,000
  - After fix: Loss deducted from wallet, balance becomes $49,800
*/

CREATE OR REPLACE FUNCTION apply_pnl_to_locked_bonus(
  p_user_id uuid,
  p_pnl numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_locked_bonus record;
  v_remaining_loss numeric;
  v_deduction numeric;
  v_total_deducted numeric := 0;
BEGIN
  -- If PnL is positive (profit), no action needed on locked bonus
  -- Profits go to regular wallet, handled elsewhere
  IF p_pnl >= 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'action', 'profit_credited_to_wallet',
      'profit', p_pnl
    );
  END IF;

  -- For losses, deduct from locked bonuses first (oldest first)
  v_remaining_loss := ABS(p_pnl);

  FOR v_locked_bonus IN 
    SELECT id, current_amount
    FROM locked_bonuses
    WHERE user_id = p_user_id 
      AND status = 'active'
      AND current_amount > 0
      AND expires_at > now()
    ORDER BY created_at ASC
  LOOP
    IF v_remaining_loss <= 0 THEN
      EXIT;
    END IF;

    -- Calculate how much to deduct from this bonus
    v_deduction := LEAST(v_locked_bonus.current_amount, v_remaining_loss);

    -- Update the locked bonus
    UPDATE locked_bonuses
    SET 
      current_amount = current_amount - v_deduction,
      updated_at = now(),
      status = CASE WHEN current_amount - v_deduction <= 0 THEN 'depleted' ELSE status END
    WHERE id = v_locked_bonus.id;

    v_total_deducted := v_total_deducted + v_deduction;
    v_remaining_loss := v_remaining_loss - v_deduction;
  END LOOP;

  -- If there's still remaining loss after depleting locked bonuses,
  -- deduct it from the futures margin wallet
  IF v_remaining_loss > 0 THEN
    UPDATE futures_margin_wallets
    SET available_balance = available_balance - v_remaining_loss,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- If wallet doesn't exist, create it with negative balance
    -- (this shouldn't happen in normal operation but handle gracefully)
    IF NOT FOUND THEN
      INSERT INTO futures_margin_wallets (user_id, available_balance, locked_balance)
      VALUES (p_user_id, -v_remaining_loss, 0)
      ON CONFLICT (user_id) DO UPDATE SET
        available_balance = futures_margin_wallets.available_balance - v_remaining_loss,
        updated_at = now();
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'action', 'loss_applied',
    'total_loss', ABS(p_pnl),
    'deducted_from_locked_bonus', v_total_deducted,
    'deducted_from_wallet', v_remaining_loss
  );
END;
$$;
