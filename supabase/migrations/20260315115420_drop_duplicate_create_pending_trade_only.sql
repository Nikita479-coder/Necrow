/*
  # Drop duplicate create_pending_trade_only function

  1. Changes
    - Drops the old version of `create_pending_trade_only` that has p_admin_id as the last parameter
    - Keeps the corrected version with p_admin_id as the first parameter
    - This resolves the "could not choose best candidate function" ambiguity error
*/

DROP FUNCTION IF EXISTS create_pending_trade_only(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text,
  p_admin_id uuid
);
