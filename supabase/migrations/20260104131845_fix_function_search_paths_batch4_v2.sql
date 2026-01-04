/*
  # Fix Function Search Paths - Batch 4
  
  This migration fixes mutable search_path issues in more functions.
  
  ## Functions Fixed
  - Withdrawal functions
  - Notification functions
  - KYC functions
  - Giveaway functions
  
  ## Security
  - All functions now have immutable search_path set to 'public'
*/

-- Fix request_withdrawal function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'request_withdrawal'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix admin_process_withdrawal function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'admin_process_withdrawal'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix admin_block_withdrawals function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'admin_block_withdrawals'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix create_notification function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'create_notification'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix broadcast_notification function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'broadcast_notification'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix insert_kyc_document function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'insert_kyc_document'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix get_document_base64 function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'get_document_base64'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix allocate_giveaway_tickets function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'allocate_giveaway_tickets'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix execute_giveaway_draw function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'execute_giveaway_draw'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;

-- Fix apply_fee_voucher function
DO $$
DECLARE
  func_oid oid;
BEGIN
  FOR func_oid IN 
    SELECT p.oid FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname = 'apply_fee_voucher'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', func_oid::regprocedure);
  END LOOP;
END $$;
