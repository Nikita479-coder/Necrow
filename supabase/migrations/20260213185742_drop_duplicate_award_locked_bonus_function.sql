/*
  # Drop Duplicate award_locked_bonus Function

  ## Summary
  There are two overloaded versions of `award_locked_bonus` with different parameter orders.
  When called with named parameters, PostgreSQL cannot determine which version to use,
  causing: "function award_locked_bonus(...) is not unique"

  ## Changes
  - Drop the OLD version with parameter order: (user_id, bonus_type_id, amount, awarded_by, notes, ...)
  - Keep the CURRENT version with parameter order: (user_id, amount, bonus_type_id, notes, awarded_by, ...)

  ## Impact
  - Fixes bulk KYC approval failures (47 out of 51 documents were failing)
  - Fixes individual KYC document approval when it triggers the bonus award
*/

DROP FUNCTION IF EXISTS award_locked_bonus(
  p_user_id uuid,
  p_bonus_type_id uuid,
  p_amount numeric,
  p_awarded_by uuid,
  p_notes text,
  p_expiry_days integer,
  p_consecutive_days integer,
  p_daily_trades integer,
  p_daily_duration_minutes integer
);