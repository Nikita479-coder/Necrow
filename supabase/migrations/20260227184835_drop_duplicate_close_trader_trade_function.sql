/*
  # Drop duplicate close_trader_trade function

  1. Problem
    - Two overloaded versions of `close_trader_trade` exist with the same parameters in different order
    - Signature 1: (p_admin_id uuid, p_trade_id uuid, p_exit_price numeric, p_pnl_percentage numeric)
    - Signature 2: (p_trade_id uuid, p_exit_price numeric, p_pnl_percentage numeric, p_admin_id uuid)
    - When called with named parameters, PostgreSQL cannot choose between them

  2. Fix
    - Drop the older version (p_admin_id first) since the frontend and newer code use the (p_trade_id first) signature
    - The remaining function is identical in behavior
*/

DROP FUNCTION IF EXISTS public.close_trader_trade(p_admin_id uuid, p_trade_id uuid, p_exit_price numeric, p_pnl_percentage numeric);
