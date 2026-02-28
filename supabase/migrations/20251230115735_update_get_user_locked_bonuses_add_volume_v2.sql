/*
  # Update get_user_locked_bonuses to include trading volume

  1. Changes
    - Drop and recreate function with new return columns
    - Add bonus_trading_volume_completed to return data
    - Add bonus_trading_volume_required to return data

  2. Purpose
    - Admin can see how much volume was traded using the locked bonus
    - Helps track bonus usage and unlock progress
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
  bonus_trading_volume_required numeric
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
  COALESCE(lb.bonus_trading_volume_required, 0) as bonus_trading_volume_required
FROM locked_bonuses lb
WHERE lb.user_id = p_user_id
ORDER BY lb.created_at DESC;
$function$;
