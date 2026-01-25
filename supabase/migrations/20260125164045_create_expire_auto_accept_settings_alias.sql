/*
  # Create Alias Function for Auto-Accept Expiration

  Creates an alias function `expire_auto_accept_settings` that calls the 
  existing `expire_auto_accept_periods` function for compatibility with
  the edge function.
*/

CREATE OR REPLACE FUNCTION expire_auto_accept_settings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN expire_auto_accept_periods();
END;
$$;
