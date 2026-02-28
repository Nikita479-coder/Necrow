/*
  # Fix Function Search Paths - Batch 1
  
  This migration fixes mutable search_path issues in functions.
  Functions without explicit search_path can be exploited by attackers
  who create malicious objects in other schemas.
  
  ## Functions Fixed
  - Core utility functions
  - Admin check functions
  - Wallet functions
  
  ## Security
  - All functions now have immutable search_path set to 'public'
*/

-- Fix detect_malicious_pattern function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'detect_malicious_pattern'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix sanitize_text_input function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'sanitize_text_input'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix is_user_admin function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'is_user_admin'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix check_admin_permission function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'check_admin_permission'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_user_vip_level function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_user_vip_level'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix calculate_total_portfolio_value function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'calculate_total_portfolio_value'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_wallet_balances function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_wallet_balances'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix transfer_between_wallets function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'transfer_between_wallets'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_swap_rate function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_swap_rate'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix execute_swap function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'execute_swap'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;
