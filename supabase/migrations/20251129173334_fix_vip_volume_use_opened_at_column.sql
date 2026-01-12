/*
  # Fix VIP Volume Calculation - Use Correct Column Names

  1. Changes
    - Use `opened_at` instead of `created_at` for futures_positions
    - Better join logic to match positions with transactions
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

  -- Add volume from ACTIVE positions opened more than 30 days ago
  -- Calculate position size (quantity * entry_price) for active old positions
  SELECT COALESCE(SUM(ABS(quantity * entry_price)), 0)
  INTO v_active_positions_volume
  FROM futures_positions
  WHERE user_id = p_user_id
    AND status = 'open'
    AND opened_at < NOW() - INTERVAL '30 days';

  -- Calculate swap trading volume (last 30 days)
  SELECT COALESCE(SUM(ABS(amount)), 0)
  INTO v_swap_volume
  FROM transactions
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND transaction_type = 'swap';

  -- Total volume = recent trades + active old positions + swaps
  v_total_volume := v_futures_volume + v_active_positions_volume + v_swap_volume;

  RETURN v_total_volume;
END;
$$;