/*
  # Drop duplicate close_trader_trade function

  The old version with parameter order (p_trade_id, p_exit_price, p_pnl_percentage, p_admin_id)
  conflicts with the newer version (p_admin_id, p_trade_id, p_exit_price, p_pnl_percentage),
  causing an ambiguous function call error. Drop the old one.
*/

DROP FUNCTION IF EXISTS close_trader_trade(uuid, numeric, numeric, uuid);
