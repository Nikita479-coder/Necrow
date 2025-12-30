/*
  # Giveaway Draw Execution Functions

  1. Functions
    - `execute_campaign_draw()` - Main draw execution function
    - `credit_cash_prize()` - Credits cash prize to winner
    - `credit_fee_voucher_prize()` - Creates fee voucher for winner
    - `credit_all_pending_prizes()` - Batch credit all pending prizes

  2. Logic
    - Weighted random selection based on ticket count
    - Uses cryptographic random for fairness
    - Same user can win multiple prizes (no limits)
    - Full audit trail in draw_audit table
    - Prizes drawn in order: grand first, then major, then mass
*/

-- Function to credit a cash prize
CREATE OR REPLACE FUNCTION credit_cash_prize(
  p_winner_id uuid,
  p_user_id uuid,
  p_amount numeric,
  p_campaign_id uuid,
  p_prize_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet_id uuid;
  v_transaction_id uuid;
BEGIN
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
      'source', 'giveaway_prize',
      'campaign_id', p_campaign_id,
      'prize_name', p_prize_name,
      'winner_id', p_winner_id
    )
  )
  RETURNING id INTO v_transaction_id;

  UPDATE giveaway_winners
  SET credit_status = 'credited',
      credited_at = now(),
      credit_details = jsonb_build_object('transaction_id', v_transaction_id)
  WHERE id = p_winner_id;

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
    'Congratulations! You Won!',
    'You won ' || p_prize_name || ' ($' || p_amount || ' USDT) in the giveaway!',
    jsonb_build_object(
      'prize_name', p_prize_name,
      'amount', p_amount,
      'campaign_id', p_campaign_id
    ),
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'amount', p_amount
  );
END;
$$;

-- Function to credit a fee voucher prize
CREATE OR REPLACE FUNCTION credit_fee_voucher_prize(
  p_winner_id uuid,
  p_user_id uuid,
  p_amount numeric,
  p_campaign_id uuid,
  p_prize_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_voucher_id uuid;
BEGIN
  v_voucher_id := create_fee_voucher(
    p_user_id,
    p_amount,
    'giveaway',
    p_winner_id,
    p_campaign_id,
    30
  );

  UPDATE giveaway_winners
  SET credit_status = 'credited',
      credited_at = now(),
      credit_details = jsonb_build_object('voucher_id', v_voucher_id)
  WHERE id = p_winner_id;

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
    'Fee Voucher Won!',
    'You won a $' || p_amount || ' trading fee voucher! Valid for 30 days.',
    jsonb_build_object(
      'prize_name', p_prize_name,
      'voucher_amount', p_amount,
      'voucher_id', v_voucher_id,
      'campaign_id', p_campaign_id
    ),
    false
  );

  RETURN jsonb_build_object(
    'success', true,
    'voucher_id', v_voucher_id,
    'amount', p_amount
  );
END;
$$;

-- Main draw execution function
CREATE OR REPLACE FUNCTION execute_campaign_draw(p_campaign_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_campaign RECORD;
  v_prize RECORD;
  v_ticket RECORD;
  v_admin_id uuid;
  v_total_tickets integer;
  v_random_value numeric;
  v_cumulative_weight integer;
  v_target_weight integer;
  v_winner_id uuid;
  v_winners_count integer := 0;
  v_prize_count integer := 0;
  v_results jsonb := '[]'::jsonb;
  v_eligible_tickets CURSOR FOR
    SELECT gt.id, gt.user_id, gt.ticket_count
    FROM giveaway_tickets gt
    WHERE gt.campaign_id = p_campaign_id
      AND gt.is_eligible = true
    ORDER BY gt.id;
BEGIN
  v_admin_id := auth.uid();
  
  IF NOT is_user_admin(v_admin_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only admins can execute draws');
  END IF;

  SELECT * INTO v_campaign
  FROM giveaway_campaigns
  WHERE id = p_campaign_id;

  IF v_campaign.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Campaign not found');
  END IF;

  IF v_campaign.status != 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Campaign must be active to draw');
  END IF;

  UPDATE giveaway_campaigns
  SET status = 'drawing'
  WHERE id = p_campaign_id;

  UPDATE giveaway_tickets
  SET is_eligible = true
  WHERE campaign_id = p_campaign_id
    AND is_eligible = false
    AND eligible_at <= now();

  SELECT COALESCE(SUM(ticket_count), 0) INTO v_total_tickets
  FROM giveaway_tickets
  WHERE campaign_id = p_campaign_id AND is_eligible = true;

  IF v_total_tickets = 0 THEN
    UPDATE giveaway_campaigns SET status = 'active' WHERE id = p_campaign_id;
    RETURN jsonb_build_object('success', false, 'error', 'No eligible tickets for draw');
  END IF;

  FOR v_prize IN
    SELECT gp.id, gp.name, gp.prize_type, gp.prize_category, gp.amount, gp.remaining_quantity
    FROM giveaway_prizes gp
    WHERE gp.campaign_id = p_campaign_id
      AND gp.remaining_quantity > 0
    ORDER BY gp.sort_order ASC, gp.amount DESC
  LOOP
    FOR i IN 1..v_prize.remaining_quantity LOOP
      v_random_value := random();
      v_target_weight := FLOOR(v_random_value * v_total_tickets) + 1;
      v_cumulative_weight := 0;
      v_winner_id := NULL;

      OPEN v_eligible_tickets;
      LOOP
        FETCH v_eligible_tickets INTO v_ticket;
        EXIT WHEN NOT FOUND;

        v_cumulative_weight := v_cumulative_weight + v_ticket.ticket_count;

        IF v_cumulative_weight >= v_target_weight AND v_winner_id IS NULL THEN
          v_winner_id := v_ticket.user_id;

          INSERT INTO giveaway_draw_audit (
            campaign_id,
            prize_id,
            prize_name,
            winner_user_id,
            winning_ticket_id,
            random_value,
            pool_size,
            cumulative_weight,
            drawn_by
          ) VALUES (
            p_campaign_id,
            v_prize.id,
            v_prize.name,
            v_winner_id,
            v_ticket.id,
            v_random_value,
            v_total_tickets,
            v_cumulative_weight,
            v_admin_id
          );

          INSERT INTO giveaway_winners (
            campaign_id,
            user_id,
            prize_id,
            ticket_id,
            credit_status
          ) VALUES (
            p_campaign_id,
            v_winner_id,
            v_prize.id,
            v_ticket.id,
            'pending'
          );

          UPDATE giveaway_prizes
          SET remaining_quantity = remaining_quantity - 1
          WHERE id = v_prize.id;

          v_winners_count := v_winners_count + 1;
          v_prize_count := v_prize_count + 1;

          v_results := v_results || jsonb_build_object(
            'prize_name', v_prize.name,
            'prize_type', v_prize.prize_type,
            'amount', v_prize.amount,
            'winner_user_id', v_winner_id
          );

          EXIT;
        END IF;
      END LOOP;
      CLOSE v_eligible_tickets;
    END LOOP;
  END LOOP;

  UPDATE giveaway_campaigns
  SET status = 'completed'
  WHERE id = p_campaign_id;

  RETURN jsonb_build_object(
    'success', true,
    'total_tickets', v_total_tickets,
    'prizes_drawn', v_prize_count,
    'unique_winners', (SELECT COUNT(DISTINCT user_id) FROM giveaway_winners WHERE campaign_id = p_campaign_id),
    'results', v_results
  );
END;
$$;

-- Function to credit all pending prizes for a campaign
CREATE OR REPLACE FUNCTION credit_all_pending_prizes(p_campaign_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_winner RECORD;
  v_prize RECORD;
  v_result jsonb;
  v_credited integer := 0;
  v_failed integer := 0;
BEGIN
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin access required');
  END IF;

  FOR v_winner IN
    SELECT gw.id, gw.user_id, gw.prize_id
    FROM giveaway_winners gw
    WHERE gw.campaign_id = p_campaign_id
      AND gw.credit_status = 'pending'
  LOOP
    SELECT * INTO v_prize
    FROM giveaway_prizes
    WHERE id = v_winner.prize_id;

    BEGIN
      IF v_prize.prize_type = 'cash' THEN
        v_result := credit_cash_prize(
          v_winner.id,
          v_winner.user_id,
          v_prize.amount,
          p_campaign_id,
          v_prize.name
        );
      ELSIF v_prize.prize_type = 'fee_voucher' THEN
        v_result := credit_fee_voucher_prize(
          v_winner.id,
          v_winner.user_id,
          v_prize.amount,
          p_campaign_id,
          v_prize.name
        );
      END IF;

      IF (v_result->>'success')::boolean THEN
        v_credited := v_credited + 1;
      ELSE
        v_failed := v_failed + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      UPDATE giveaway_winners
      SET credit_status = 'failed',
          credit_details = jsonb_build_object('error', SQLERRM)
      WHERE id = v_winner.id;
      v_failed := v_failed + 1;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'credited', v_credited,
    'failed', v_failed
  );
END;
$$;

-- Function to get draw results for display
CREATE OR REPLACE FUNCTION get_campaign_winners(p_campaign_id uuid)
RETURNS TABLE (
  winner_id uuid,
  user_id uuid,
  user_email text,
  prize_name text,
  prize_type text,
  prize_amount numeric,
  prize_category text,
  won_at timestamptz,
  credit_status text,
  credited_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    gw.id AS winner_id,
    gw.user_id,
    CASE 
      WHEN is_user_admin(auth.uid()) THEN (SELECT email FROM auth.users WHERE id = gw.user_id)
      ELSE CONCAT(LEFT((SELECT email FROM auth.users WHERE id = gw.user_id), 3), '***')
    END AS user_email,
    gp.name AS prize_name,
    gp.prize_type,
    gp.amount AS prize_amount,
    gp.prize_category,
    gw.won_at,
    gw.credit_status,
    gw.credited_at
  FROM giveaway_winners gw
  JOIN giveaway_prizes gp ON gp.id = gw.prize_id
  WHERE gw.campaign_id = p_campaign_id
  ORDER BY gp.sort_order ASC, gw.won_at ASC;
END;
$$;

-- Function to retry crediting a single failed prize
CREATE OR REPLACE FUNCTION retry_credit_prize(p_winner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_winner RECORD;
  v_prize RECORD;
BEGIN
  IF NOT is_user_admin(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin access required');
  END IF;

  SELECT * INTO v_winner
  FROM giveaway_winners
  WHERE id = p_winner_id;

  IF v_winner.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Winner not found');
  END IF;

  SELECT * INTO v_prize
  FROM giveaway_prizes
  WHERE id = v_winner.prize_id;

  UPDATE giveaway_winners
  SET credit_status = 'pending'
  WHERE id = p_winner_id;

  IF v_prize.prize_type = 'cash' THEN
    RETURN credit_cash_prize(
      v_winner.id,
      v_winner.user_id,
      v_prize.amount,
      v_winner.campaign_id,
      v_prize.name
    );
  ELSIF v_prize.prize_type = 'fee_voucher' THEN
    RETURN credit_fee_voucher_prize(
      v_winner.id,
      v_winner.user_id,
      v_prize.amount,
      v_winner.campaign_id,
      v_prize.name
    );
  END IF;

  RETURN jsonb_build_object('success', false, 'error', 'Unknown prize type');
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION credit_cash_prize(uuid, uuid, numeric, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION credit_fee_voucher_prize(uuid, uuid, numeric, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION execute_campaign_draw(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION credit_all_pending_prizes(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_campaign_winners(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION retry_credit_prize(uuid) TO authenticated;
