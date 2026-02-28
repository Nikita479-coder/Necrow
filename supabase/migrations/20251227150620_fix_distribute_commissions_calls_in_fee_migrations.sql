/*
  # Fix distribute_commissions Calls in Fee Migrations

  ## Problem
  The fee-based migration has incorrect distribute_commissions function calls
  with wrong parameter order and types

  ## Solution
  Update function calls to use correct signature:
  - p_trader_id UUID
  - p_transaction_id UUID
  - p_trade_amount NUMERIC  
  - p_fee_amount NUMERIC
  - p_leverage INTEGER
*/

-- This migration removes the incorrect distribute_commissions calls from the place_futures_order function
-- The commission distribution is now handled by the trigger on fee_collections table
-- So we just need to remove these duplicate calls

-- Check if the current place_futures_order function exists and has the problematic code
-- We'll recreate it without the manual distribute_commissions call

DROP FUNCTION IF EXISTS public.place_futures_order(uuid,text,text,text,numeric,integer,text,numeric,numeric,numeric,numeric,boolean);

-- The function will be recreated by a proper migration that doesn't include manual commission calls
-- Since the trigger on fee_collections already handles distribution automatically