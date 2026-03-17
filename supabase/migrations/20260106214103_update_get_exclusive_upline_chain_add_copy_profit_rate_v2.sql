/*
  # Update get_exclusive_upline_chain to Include Copy Profit Rate

  ## Overview
  Updates the get_exclusive_upline_chain function to return copy_profit_rate
  alongside the existing deposit_rate and fee_rate.

  ## Changes
  - Drop and recreate function with new return type
  - Add `copy_profit_rate` to the return table
  - Fetch rate from the affiliate's `copy_profit_rates` JSONB column

  ## Security
  - Uses SECURITY DEFINER with restricted search_path
*/

-- Drop existing function to change return type
DROP FUNCTION IF EXISTS get_exclusive_upline_chain(uuid);

-- Recreate with copy_profit_rate included
CREATE OR REPLACE FUNCTION get_exclusive_upline_chain(p_user_id uuid)
RETURNS TABLE (
  affiliate_id uuid,
  tier_level integer,
  deposit_rate numeric,
  fee_rate numeric,
  copy_profit_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user uuid := p_user_id;
  v_referrer_id uuid;
  v_level integer := 1;
  v_affiliate exclusive_affiliates;
BEGIN
  WHILE v_level <= 5 LOOP
    SELECT referred_by INTO v_referrer_id
    FROM user_profiles
    WHERE id = v_current_user;
    
    IF v_referrer_id IS NULL THEN
      EXIT;
    END IF;
    
    SELECT * INTO v_affiliate
    FROM exclusive_affiliates
    WHERE user_id = v_referrer_id AND is_active = true;
    
    IF FOUND THEN
      affiliate_id := v_referrer_id;
      tier_level := v_level;
      deposit_rate := (v_affiliate.deposit_commission_rates->('level_' || v_level))::numeric;
      fee_rate := (v_affiliate.fee_share_rates->('level_' || v_level))::numeric;
      copy_profit_rate := COALESCE((v_affiliate.copy_profit_rates->('level_' || v_level))::numeric, 
        CASE v_level
          WHEN 1 THEN 10
          WHEN 2 THEN 5
          WHEN 3 THEN 4
          WHEN 4 THEN 3
          WHEN 5 THEN 2
          ELSE 0
        END
      );
      RETURN NEXT;
    END IF;
    
    v_current_user := v_referrer_id;
    v_level := v_level + 1;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION get_exclusive_upline_chain IS 
  'Returns the 5-level upline chain with deposit, fee, and copy profit commission rates for each exclusive affiliate';
