/*
  # Fix Locked Bonus Display - Include Margin in Positions

  1. Changes
    - Update get_user_locked_bonuses function to include margin_in_positions
    - Calculate total margin from active futures positions using locked bonus funds
    - This ensures locked bonus total includes funds in active positions

  2. Purpose
    - Users can see their total locked bonus value including margin in positions
    - Realized losses are calculated correctly (excluding margin in positions)
*/

DROP FUNCTION IF EXISTS public.get_user_locked_bonuses(uuid);

CREATE FUNCTION public.get_user_locked_bonuses(p_user_id uuid)
RETURNS TABLE(
  id uuid, 
  original_amount numeric, 
  current_amount numeric, 
  realized_profits numeric, 
  bonus_type_name text, 
  status text, 
  expires_at timestamp with time zone, 
  days_remaining integer, 
  created_at timestamp with time zone,
  bonus_trading_volume_completed numeric,
  bonus_trading_volume_required numeric,
  margin_in_positions numeric
)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
SELECT 
  lb.id,
  lb.original_amount,
  lb.current_amount,
  lb.realized_profits,
  lb.bonus_type_name,
  lb.status,
  lb.expires_at,
  GREATEST(0, EXTRACT(DAY FROM (lb.expires_at - now()))::integer) as days_remaining,
  lb.created_at,
  COALESCE(lb.bonus_trading_volume_completed, 0) as bonus_trading_volume_completed,
  COALESCE(lb.bonus_trading_volume_required, 0) as bonus_trading_volume_required,
  COALESCE((
    SELECT SUM(fp.margin_from_locked_bonus)
    FROM futures_positions fp
    WHERE fp.user_id = p_user_id
      AND fp.status = 'open'
      AND fp.margin_from_locked_bonus > 0
  ), 0) as margin_in_positions
FROM locked_bonuses lb
WHERE lb.user_id = p_user_id
ORDER BY lb.created_at DESC;
$function$;
