/*
  # Drop duplicate close_trader_trade function

  1. Changes
    - Drops the older overload of close_trader_trade with signature
      (p_admin_id uuid, p_trade_id uuid, p_exit_price numeric, p_pnl_percentage numeric)
    - Keeps the newer version with signature
      (p_trade_id uuid, p_exit_price numeric, p_pnl_percentage numeric, p_admin_id uuid)
    - This resolves the "Could not choose the best candidate function" ambiguity error

  2. Security
    - No changes to RLS or policies
*/

DROP FUNCTION IF EXISTS public.close_trader_trade(p_admin_id uuid, p_trade_id uuid, p_exit_price numeric, p_pnl_percentage numeric);
