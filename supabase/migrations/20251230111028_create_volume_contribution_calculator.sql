/*
  # Create Volume Contribution Calculator

  ## Summary
  Creates helper functions to calculate trading volume contributions based on fund source.
  This separates locked bonus trading volume from real wallet trading volume.

  ## Key Functions
  1. calculate_volume_contribution() - Calculates how much of a position's volume counts toward:
     - bonus_volume: For locked bonus unlock requirements (requires 60+ min duration)
     - real_volume: For VIP status and affiliate programs (no duration requirement)
  
  2. Helper to determine if position qualifies based on duration

  ## Logic
  - If position uses locked bonus margin:
    - Check if duration >= 60 minutes
    - If yes: count proportional amount toward bonus_volume
    - If no: do not count toward bonus_volume
  - If position uses real wallet margin:
    - Always count toward real_volume (no duration restriction)
  - Mixed positions: split proportionally

  ## Security
  - SECURITY DEFINER for system access
  - Immutable functions for performance
*/

-- Function to check if position meets minimum duration requirement for bonus volume
CREATE OR REPLACE FUNCTION position_meets_duration_requirement(
  p_opened_at timestamptz,
  p_closed_at timestamptz,
  p_minimum_minutes integer
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_opened_at IS NULL OR p_closed_at IS NULL THEN
    RETURN false;
  END IF;
  
  RETURN EXTRACT(EPOCH FROM (p_closed_at - p_opened_at)) / 60 >= p_minimum_minutes;
END;
$$;

-- Function to calculate volume contribution from a closed position
CREATE OR REPLACE FUNCTION calculate_volume_contribution(
  p_position_size numeric,
  p_entry_price numeric,
  p_margin_amount numeric,
  p_margin_from_locked_bonus numeric,
  p_opened_at timestamptz,
  p_closed_at timestamptz,
  p_minimum_duration_minutes integer DEFAULT 60
)
RETURNS TABLE (
  bonus_volume numeric,
  real_volume numeric,
  total_notional_value numeric,
  bonus_margin_percentage numeric,
  real_margin_percentage numeric,
  duration_met boolean
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_notional_value numeric;
  v_bonus_percentage numeric;
  v_real_percentage numeric;
  v_duration_met boolean;
  v_bonus_vol numeric;
  v_real_vol numeric;
BEGIN
  -- Calculate total notional value of the position
  v_notional_value := ABS(p_position_size * p_entry_price);
  
  -- Check if position meets duration requirement
  v_duration_met := position_meets_duration_requirement(
    p_opened_at,
    p_closed_at,
    p_minimum_duration_minutes
  );
  
  -- Calculate what percentage of margin came from each source
  IF p_margin_amount > 0 THEN
    v_bonus_percentage := LEAST(1.0, p_margin_from_locked_bonus / p_margin_amount);
    v_real_percentage := 1.0 - v_bonus_percentage;
  ELSE
    v_bonus_percentage := 0;
    v_real_percentage := 1.0;
  END IF;
  
  -- Calculate bonus volume (only if duration requirement met)
  IF v_duration_met AND v_bonus_percentage > 0 THEN
    v_bonus_vol := v_notional_value * v_bonus_percentage;
  ELSE
    v_bonus_vol := 0;
  END IF;
  
  -- Calculate real volume (always counts, no duration requirement)
  IF v_real_percentage > 0 THEN
    v_real_vol := v_notional_value * v_real_percentage;
  ELSE
    v_real_vol := 0;
  END IF;
  
  -- Return the calculated values
  RETURN QUERY SELECT
    v_bonus_vol,
    v_real_vol,
    v_notional_value,
    v_bonus_percentage * 100,
    v_real_percentage * 100,
    v_duration_met;
END;
$$;

-- Function to get volume breakdown for a specific position
CREATE OR REPLACE FUNCTION get_position_volume_breakdown(p_position_id uuid)
RETURNS TABLE (
  position_id uuid,
  notional_value numeric,
  bonus_volume numeric,
  real_volume numeric,
  bonus_margin_pct numeric,
  real_margin_pct numeric,
  duration_minutes numeric,
  duration_requirement_met boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_position record;
  v_contribution record;
BEGIN
  -- Get position details
  SELECT
    fp.id,
    fp.position_size,
    fp.entry_price,
    fp.margin_amount,
    COALESCE(fp.margin_from_locked_bonus, 0) as margin_from_locked_bonus,
    fp.opened_at,
    fp.closed_at
  INTO v_position
  FROM futures_positions fp
  WHERE fp.id = p_position_id
    AND fp.status = 'closed';
  
  IF NOT FOUND THEN
    RETURN;
  END IF;
  
  -- Calculate volume contribution
  SELECT * INTO v_contribution
  FROM calculate_volume_contribution(
    v_position.position_size,
    v_position.entry_price,
    v_position.margin_amount,
    v_position.margin_from_locked_bonus,
    v_position.opened_at,
    v_position.closed_at,
    60
  );
  
  -- Return results
  RETURN QUERY SELECT
    p_position_id,
    v_contribution.total_notional_value,
    v_contribution.bonus_volume,
    v_contribution.real_volume,
    v_contribution.bonus_margin_percentage,
    v_contribution.real_margin_percentage,
    EXTRACT(EPOCH FROM (v_position.closed_at - v_position.opened_at)) / 60,
    v_contribution.duration_met;
END;
$$;

-- Function to get total volume contributions for a user
CREATE OR REPLACE FUNCTION get_user_volume_summary(
  p_user_id uuid,
  p_days_back integer DEFAULT 30
)
RETURNS TABLE (
  total_positions integer,
  total_bonus_volume numeric,
  total_real_volume numeric,
  total_notional_volume numeric,
  positions_meeting_duration integer,
  positions_not_meeting_duration integer,
  avg_position_duration_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN QUERY
  WITH position_volumes AS (
    SELECT
      fp.id,
      fp.position_size,
      fp.entry_price,
      fp.margin_amount,
      COALESCE(fp.margin_from_locked_bonus, 0) as margin_from_locked_bonus,
      fp.opened_at,
      fp.closed_at,
      EXTRACT(EPOCH FROM (fp.closed_at - fp.opened_at)) / 60 as duration_minutes
    FROM futures_positions fp
    WHERE fp.user_id = p_user_id
      AND fp.status = 'closed'
      AND fp.closed_at >= now() - (p_days_back || ' days')::interval
  ),
  volume_calcs AS (
    SELECT
      pv.*,
      vc.*
    FROM position_volumes pv
    CROSS JOIN LATERAL calculate_volume_contribution(
      pv.position_size,
      pv.entry_price,
      pv.margin_amount,
      pv.margin_from_locked_bonus,
      pv.opened_at,
      pv.closed_at,
      60
    ) vc
  )
  SELECT
    COUNT(*)::integer as total_positions,
    COALESCE(SUM(bonus_volume), 0) as total_bonus_volume,
    COALESCE(SUM(real_volume), 0) as total_real_volume,
    COALESCE(SUM(total_notional_value), 0) as total_notional_volume,
    COUNT(*) FILTER (WHERE duration_met = true)::integer as positions_meeting_duration,
    COUNT(*) FILTER (WHERE duration_met = false AND margin_from_locked_bonus > 0)::integer as positions_not_meeting_duration,
    COALESCE(AVG(duration_minutes), 0) as avg_position_duration_minutes
  FROM volume_calcs;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION position_meets_duration_requirement(timestamptz, timestamptz, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_volume_contribution(numeric, numeric, numeric, numeric, timestamptz, timestamptz, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION get_position_volume_breakdown(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_volume_summary(uuid, integer) TO authenticated;
