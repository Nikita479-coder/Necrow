/*
  # Fix Function Search Paths - Batch 6
  
  This migration fixes mutable search_path issues in remaining functions.
  
  ## Functions Fixed
  - CRM functions
  - Support functions  
  - Visitor tracking functions
  - Trader metrics functions
  
  ## Security
  - All functions now have immutable search_path set to 'public'
*/

-- Fix get_crm_dashboard_stats function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_crm_dashboard_stats'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_filtered_users function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_filtered_users'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix admin_get_support_tickets function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'admin_get_support_tickets'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix track_visitor_session function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'track_visitor_session'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_visitor_analytics function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_visitor_analytics'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix calculate_trader_metrics function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'calculate_trader_metrics'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix recalculate_all_trader_metrics function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'recalculate_all_trader_metrics'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_online_users function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_online_users'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_user_email function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_user_email'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix bulk_get_user_emails function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'bulk_get_user_emails'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;
