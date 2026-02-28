/*
  # Fix auto_promote_admin_emails function search_path

  1. Problem
    - The auto_promote_admin_emails trigger function lacks a search_path setting
    
  2. Solution
    - Recreate the function with proper search_path = public
*/

CREATE OR REPLACE FUNCTION auto_promote_admin_emails()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  admin_emails text[] := ARRAY['admin@test.com', 'admin@sharktrades.com'];
BEGIN
  IF NEW.email = ANY(admin_emails) THEN
    NEW.raw_app_meta_data := 
      COALESCE(NEW.raw_app_meta_data, '{}'::jsonb) || 
      jsonb_build_object('is_admin', true);
  END IF;
  
  RETURN NEW;
END;
$$;
