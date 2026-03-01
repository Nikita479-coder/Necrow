/*
  # Giveaway Ticket Allocation Functions

  1. Functions
    - `get_ticket_tier_for_amount()` - Determines which tier a deposit falls into
    - `award_giveaway_tickets()` - Awards tickets for a deposit
    - `award_guaranteed_bonus()` - Awards instant bonus for platinum tier

  2. Triggers
    - Trigger on crypto_deposits to auto-award tickets when deposit is finished

  3. Logic
    - Tickets awarded per-deposit (not cumulative)
    - Holding period calculated from deposit completion
    - Guaranteed $20 bonus for $1000+ deposits awarded immediately
*/

-- Function to get the tier for a deposit amount
CREATE OR REPLACE FUNCTION get_ticket_tier_for_amount(
  p_campaign_id uuid,
  p_amount numeric
)
RETURNS TABLE (
  tier_id uuid,
  tier_name text,
  base_tickets integer,
  bonus_percentage numeric,
  guaranteed_bonus_amount numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    gt.id,
    gt.tier_name,
    gt.base_tickets,
    gt.bonus_percentage,
    gt.guaranteed_bonus_amount
  FROM giveaway_ticket_tiers gt
  WHERE gt.campaign_id = p_campaign_id
    AND gt.min_deposit <= p_amount
    AND (gt.max_deposit IS NULL OR gt.max_deposit >= p_amount)
  ORDER BY gt.min_deposit DESC
  LIMIT 1;
END;
$$;

-- Function to award guaranteed bonus (credits to main wallet)
CREATE OR REPLACE FUNCTION award_guaranteed_bonus(
  p_user_id uuid,
  p_amount numeric,
  p_campaign_id uuid,
  p_deposit_payment_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_transaction_id uuid;
  v_wallet_id uuid;
BEGIN
  IF p_amount <= 0 THEN
    RETURN NULL;
  END IF;

  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = p_user_id AND wallet_type = 'main' AND currency = 'USDT';

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, wallet_type, currency, balance)
    VALUES (p_user_id, 'main', 'USDT', 0)
    RETURNING id INTO v_wallet_id;
  END IF;

  UPDATE wallets
  SET balance = balance + p_amount,
      updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO transactions (
    user_id,
    wallet_id,
    transaction_type,
    amount,
    currency,
    status,
    details
  ) VALUES (
    p_user_id,
    v_wallet_id,
    'reward',
    p_amount,
    'USDT',
    'completed',
    jsonb_build_object(
      'source', 'giveaway_guaranteed_bonus',
      'campaign_id', p_campaign_id,
      'deposit_payment_id', p_deposit_payment_id
    )
  )
  RETURNING id INTO v_transaction_id;

  INSERT INTO notifications (
    user_id,
    notification_type,
    title,
    message,
    data,
    read
  ) VALUES (
    p_user_id,
    'reward',
    'Guaranteed Bonus Received!',
    'You received a $' || p_amount || ' USDT bonus for your deposit!',
    jsonb_build_object('amount', p_amount, 'campaign_id', p_campaign_id),
    false
  );

  RETURN v_transaction_id;
END;
$$;

-- Main function to award giveaway tickets for a deposit
CREATE OR REPLACE FUNCTION award_giveaway_tickets(
  p_user_id uuid,
  p_deposit_payment_id uuid,
  p_deposit_amount numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_campaign RECORD;
  v_tier RECORD;
  v_ticket_count integer;
  v_ticket_id uuid;
  v_bonus_txn_id uuid;
  v_holding_period interval;
  v_eligible_at timestamptz;
BEGIN
  SELECT * INTO v_campaign
  FROM giveaway_campaigns
  WHERE status = 'active'
    AND start_date <= now()
    AND end_date >= now()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_campaign.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'no_active_campaign');
  END IF;

  IF EXISTS (
    SELECT 1 FROM giveaway_tickets
    WHERE campaign_id = v_campaign.id
      AND deposit_payment_id = p_deposit_payment_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'reason', 'already_awarded');
  END IF;

  SELECT * INTO v_tier
  FROM get_ticket_tier_for_amount(v_campaign.id, p_deposit_amount);

  IF v_tier.tier_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'below_minimum_deposit');
  END IF;

  v_ticket_count := v_tier.base_tickets + FLOOR(v_tier.base_tickets * v_tier.bonus_percentage / 100);

  v_holding_period := (v_campaign.holding_period_days || ' days')::interval;
  v_eligible_at := now() + v_holding_period;

  INSERT INTO giveaway_tickets (
    campaign_id,
    user_id,
    deposit_payment_id,
    ticket_count,
    deposit_amount,
    tier_name,
    guaranteed_bonus_awarded,
    eligible_at,
    is_eligible
  ) VALUES (
    v_campaign.id,
    p_user_id,
    p_deposit_payment_id,
    v_ticket_count,
    p_deposit_amount,
    v_tier.tier_name,
    COALESCE(v_tier.guaranteed_bonus_amount, 0),
    v_eligible_at,
    false
  )
  RETURNING id INTO v_ticket_id;

  IF COALESCE(v_tier.guaranteed_bonus_amount, 0) > 0 THEN
    v_bonus_txn_id := award_guaranteed_bonus(
      p_user_id,
      v_tier.guaranteed_bonus_amount,
      v_campaign.id,
      p_deposit_payment_id
    );
  END IF;

  INSERT INTO notifications (
    user_id,
    notification_type,
    title,
    message,
    data,
    read
  ) VALUES (
    p_user_id,
    'reward',
    'Giveaway Tickets Earned!',
    'You earned ' || v_ticket_count || ' tickets for the ' || v_campaign.name || '!',
    jsonb_build_object(
      'campaign_id', v_campaign.id,
      'ticket_count', v_ticket_count,
      'tier', v_tier.tier_name,
      'eligible_at', v_eligible_at
    ),
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'campaign_id', v_campaign.id,
    'campaign_name', v_campaign.name,
    'ticket_id', v_ticket_id,
    'tickets_awarded', v_ticket_count,
    'tier_name', v_tier.tier_name,
    'guaranteed_bonus', COALESCE(v_tier.guaranteed_bonus_amount, 0),
    'eligible_at', v_eligible_at
  );
END;
$$;

-- Trigger function to auto-award tickets when deposit is completed
CREATE OR REPLACE FUNCTION trigger_award_giveaway_tickets()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NEW.status = 'finished' AND (OLD.status IS NULL OR OLD.status != 'finished') THEN
    v_result := award_giveaway_tickets(
      NEW.user_id,
      NEW.payment_id,
      COALESCE(NEW.outcome_amount, NEW.actually_paid, NEW.price_amount)
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger on crypto_deposits
DROP TRIGGER IF EXISTS trigger_giveaway_on_deposit ON crypto_deposits;
CREATE TRIGGER trigger_giveaway_on_deposit
  AFTER INSERT OR UPDATE ON crypto_deposits
  FOR EACH ROW
  EXECUTE FUNCTION trigger_award_giveaway_tickets();

-- Function to get user's tickets for a campaign
CREATE OR REPLACE FUNCTION get_user_giveaway_tickets(
  p_user_id uuid,
  p_campaign_id uuid DEFAULT NULL
)
RETURNS TABLE (
  ticket_id uuid,
  campaign_id uuid,
  campaign_name text,
  ticket_count integer,
  deposit_amount numeric,
  tier_name text,
  guaranteed_bonus_awarded numeric,
  awarded_at timestamptz,
  eligible_at timestamptz,
  is_eligible boolean,
  days_until_eligible integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    gt.id AS ticket_id,
    gt.campaign_id,
    gc.name AS campaign_name,
    gt.ticket_count,
    gt.deposit_amount,
    gt.tier_name,
    gt.guaranteed_bonus_awarded,
    gt.awarded_at,
    gt.eligible_at,
    gt.is_eligible,
    GREATEST(0, EXTRACT(DAY FROM gt.eligible_at - now())::integer) AS days_until_eligible
  FROM giveaway_tickets gt
  JOIN giveaway_campaigns gc ON gc.id = gt.campaign_id
  WHERE gt.user_id = p_user_id
    AND (p_campaign_id IS NULL OR gt.campaign_id = p_campaign_id)
  ORDER BY gt.awarded_at DESC;
END;
$$;

-- Function to get user's total tickets summary for a campaign
CREATE OR REPLACE FUNCTION get_user_giveaway_summary(
  p_user_id uuid,
  p_campaign_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_summary jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_tickets', COALESCE(SUM(ticket_count), 0),
    'eligible_tickets', COALESCE(SUM(CASE WHEN is_eligible THEN ticket_count ELSE 0 END), 0),
    'pending_tickets', COALESCE(SUM(CASE WHEN NOT is_eligible THEN ticket_count ELSE 0 END), 0),
    'total_deposits', COUNT(*),
    'total_deposited', COALESCE(SUM(deposit_amount), 0),
    'guaranteed_bonuses', COALESCE(SUM(guaranteed_bonus_awarded), 0),
    'next_eligible_at', MIN(CASE WHEN NOT is_eligible THEN eligible_at END)
  )
  INTO v_summary
  FROM giveaway_tickets
  WHERE user_id = p_user_id
    AND campaign_id = p_campaign_id;

  RETURN v_summary;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_ticket_tier_for_amount(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION award_guaranteed_bonus(uuid, numeric, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION award_giveaway_tickets(uuid, uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_giveaway_tickets(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_giveaway_summary(uuid, uuid) TO authenticated;
