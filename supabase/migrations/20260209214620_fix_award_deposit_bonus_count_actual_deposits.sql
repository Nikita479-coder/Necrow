/*
  # Fix Deposit Bonus Tier Counting Logic

  1. Changes
    - Rewrites `award_deposit_bonus` to determine the tier by counting actual
      completed deposit transactions instead of counting previous bonus records
    - Previously, users who deposited before the bonus system was configured
      would incorrectly receive tier 1 (First Deposit Bonus) on later deposits
    - Now counts rows in `transactions` where `transaction_type = 'deposit'`
      and `status = 'completed'` to determine the correct deposit number
    - Still checks `user_deposit_bonuses` to prevent duplicate tier awards

  2. Security
    - SECURITY DEFINER with explicit search_path (unchanged)

  3. Important Notes
    - The deposit transaction is already inserted before this function runs,
      so the count naturally includes the current deposit
    - Example: 3rd completed deposit → count = 3 → tier 3 → Third Deposit Bonus
*/

CREATE OR REPLACE FUNCTION award_deposit_bonus(
  p_user_id uuid,
  p_deposit_amount numeric,
  p_deposit_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deposit_count integer;
  v_next_tier integer;
  v_trigger_event text;
  v_bonus_type record;
  v_tier_config record;
  v_bonus_percentage numeric;
  v_max_amount numeric;
  v_min_deposit numeric;
  v_calculated_bonus numeric;
  v_locked_bonus_id uuid;
BEGIN
  SELECT COUNT(*)
  INTO v_deposit_count
  FROM transactions t
  WHERE t.user_id = p_user_id
    AND t.transaction_type = 'deposit'
    AND t.status = 'completed';

  v_next_tier := v_deposit_count;

  IF v_next_tier > 3 THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'All deposit bonus tiers already claimed'
    );
  END IF;

  IF v_next_tier < 1 THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'No completed deposits found'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM user_deposit_bonuses
    WHERE user_id = p_user_id AND tier_number = v_next_tier
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'Bonus for deposit tier ' || v_next_tier || ' already claimed'
    );
  END IF;

  v_trigger_event := CASE v_next_tier
    WHEN 1 THEN 'first_deposit'
    WHEN 2 THEN 'second_deposit'
    WHEN 3 THEN 'third_deposit'
  END;

  SELECT * INTO v_bonus_type
  FROM bonus_types
  WHERE auto_trigger_event = v_trigger_event
    AND auto_trigger_enabled = true
    AND is_active = true
  LIMIT 1;

  IF v_bonus_type IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'No active auto-triggered bonus type for tier ' || v_next_tier
    );
  END IF;

  IF v_bonus_type.auto_trigger_config IS NOT NULL THEN
    v_bonus_percentage := COALESCE((v_bonus_type.auto_trigger_config->>'bonus_percentage')::numeric, 100);
    v_max_amount := COALESCE((v_bonus_type.auto_trigger_config->>'max_amount')::numeric, v_bonus_type.default_amount);
    v_min_deposit := COALESCE((v_bonus_type.auto_trigger_config->>'min_deposit')::numeric, 10);
  ELSE
    SELECT * INTO v_tier_config
    FROM deposit_bonus_tiers dbt
    WHERE dbt.tier_number = v_next_tier
      AND dbt.is_active = true;

    IF v_tier_config IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'reason', 'No tier configuration found for tier ' || v_next_tier
      );
    END IF;

    v_bonus_percentage := v_tier_config.bonus_percentage;
    v_max_amount := v_tier_config.max_bonus_amount;
    v_min_deposit := v_tier_config.min_deposit_amount;
  END IF;

  IF p_deposit_amount < v_min_deposit THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'Deposit amount below minimum of ' || v_min_deposit || ' for tier ' || v_next_tier
    );
  END IF;

  v_calculated_bonus := LEAST(
    p_deposit_amount * (v_bonus_percentage / 100),
    v_max_amount
  );

  IF v_calculated_bonus <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'Calculated bonus is zero'
    );
  END IF;

  INSERT INTO user_deposit_bonuses (user_id, tier_number, deposit_amount, bonus_amount, bonus_percentage, deposit_id)
  VALUES (p_user_id, v_next_tier, p_deposit_amount, v_calculated_bonus, v_bonus_percentage, p_deposit_id);

  v_locked_bonus_id := (award_locked_bonus(
    p_user_id := p_user_id,
    p_bonus_type_id := v_bonus_type.id,
    p_amount := v_calculated_bonus,
    p_awarded_by := NULL,
    p_notes := v_bonus_type.name || ' - ' || v_bonus_percentage || '% match on deposit of $' || ROUND(p_deposit_amount, 2),
    p_expiry_days := COALESCE(v_bonus_type.expiry_days, 7)
  ) ->> 'locked_bonus_id')::uuid;

  INSERT INTO notifications (user_id, type, title, message, read)
  VALUES (
    p_user_id,
    'bonus',
    v_bonus_type.name || ' Awarded!',
    'You received $' || ROUND(v_calculated_bonus, 2) || ' USDT as your ' ||
    CASE v_next_tier
      WHEN 1 THEN 'first'
      WHEN 2 THEN 'second'
      WHEN 3 THEN 'third'
    END || ' deposit bonus (' || v_bonus_percentage || '% match)! Use it for futures trading - profits are yours to keep.',
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'tier_number', v_next_tier,
    'bonus_amount', v_calculated_bonus,
    'bonus_percentage', v_bonus_percentage,
    'locked_bonus_id', v_locked_bonus_id,
    'bonus_type', v_bonus_type.name
  );
END;
$$;
