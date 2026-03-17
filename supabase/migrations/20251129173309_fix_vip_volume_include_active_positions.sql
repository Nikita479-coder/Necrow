/*
  # Fix VIP Volume Calculation - Include Active Positions

  1. Changes
    - Count positions opened in last 30 days (regardless of status)
    - Count positions that are currently ACTIVE (even if opened 60+ days ago)
    - Don't count positions closed more than 30 days ago
*/

CREATE OR REPLACE FUNCTION calculate_user_30d_volume(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_volume numeric := 0;
  v_futures_volume numeric := 0;
  v_swap_volume numeric := 0;
  v_active_positions_volume numeric := 0;
BEGIN
  -- Calculate futures trading volume from last 30 days (open and close transactions)
  SELECT COALESCE(SUM(ABS(amount)), 0)
  INTO v_futures_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND transaction_type IN ('open_position', 'close_position');

  -- Add volume from ACTIVE positions (even if opened more than 30 days ago)
  -- These are positions that were opened but not yet closed
  SELECT COALESCE(SUM(ABS(t.amount)), 0)
  INTO v_active_positions_volume
  FROM transactions t
  INNER JOIN futures_positions fp ON fp.user_id = t.user_id
  WHERE t.user_id = p_user_id
    AND t.transaction_type = 'open_position'
    AND t.created_at < NOW() - INTERVAL '30 days'
    AND fp.status = 'open'
    AND fp.created_at = t.created_at;

  -- Calculate swap trading volume (last 30 days)
  SELECT COALESCE(SUM(ABS(amount)), 0)
  INTO v_swap_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND transaction_type = 'swap';

  -- Total volume = recent trades + active positions
  v_total_volume := v_futures_volume + v_active_positions_volume + v_swap_volume;

  RETURN v_total_volume;
END;
$$;