/*
  # Fix Function Search Paths - Batch 2
  
  This migration fixes mutable search_path issues in more functions.
  
  ## Functions Fixed
  - Trading functions (place_futures_order, close_position, etc.)
  - Referral functions
  - Bonus functions
  
  ## Security
  - All functions now have immutable search_path set to 'public'
*/

-- Fix place_futures_order function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'place_futures_order'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix close_position function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'close_position'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix execute_liquidation function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'execute_liquidation'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix calculate_liquidation_price function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'calculate_liquidation_price'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix distribute_trading_fees function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'distribute_trading_fees'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix distribute_commissions_unified function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'distribute_commissions_unified'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix award_user_bonus function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'award_user_bonus'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix award_locked_bonus function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'award_locked_bonus'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix check_and_unlock_bonus function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'check_and_unlock_bonus'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_referred_users function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_referred_users'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;
