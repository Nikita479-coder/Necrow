/*
  # Create VIP Tracking Support Function

  1. New Functions
    - `get_user_30d_volume` - Calculate 30-day trading volume for a user
    
  2. Purpose
    - Support automated VIP level tracking
    - Calculate trading volume from futures positions and swaps
    - Enable daily VIP tier monitoring

  3. Security
    - Function uses SECURITY DEFINER for consistent calculation
    - Returns numeric value for volume
*/

-- Function to calculate 30-day trading volume for a user
CREATE OR REPLACE FUNCTION get_user_30d_volume(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_futures_volume numeric;
  v_swap_volume numeric;
  v_total_volume numeric;
BEGIN
  -- Calculate futures volume (from positions opened in last 30 days)
  SELECT COALESCE(SUM(ABS(entry_price * quantity * leverage)), 0)
  INTO v_futures_volume
  FROM futures_positions
  WHERE user_id = p_user_id
    AND opened_at >= NOW() - INTERVAL '30 days';

  -- Calculate swap volume (from swaps in last 30 days)
  SELECT COALESCE(SUM(from_amount), 0)
  INTO v_swap_volume
  FROM swap_history
  WHERE user_id = p_user_id
    AND created_at >= NOW() - INTERVAL '30 days'
    AND status = 'completed';

  -- Total volume
  v_total_volume := v_futures_volume + v_swap_volume;

  RETURN v_total_volume;
END;
$$;