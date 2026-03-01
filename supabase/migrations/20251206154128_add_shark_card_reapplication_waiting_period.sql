/*
  # Add 5 Business Day Waiting Period for Declined Shark Card Applications

  1. Changes
    - Create helper function to calculate business days between dates
    - Update apply_for_shark_card function to check for declined applications
    - Enforce 5 business day waiting period after decline
    
  2. Business Days Logic
    - Excludes weekends (Saturday and Sunday)
    - Counts only Monday-Friday as business days
*/

-- Function to calculate business days between two dates
CREATE OR REPLACE FUNCTION calculate_business_days(
  start_date timestamptz,
  end_date timestamptz
)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  iter_date date;
  end_date_only date;
  business_days integer := 0;
  day_of_week integer;
BEGIN
  iter_date := start_date::date;
  end_date_only := end_date::date;
  
  WHILE iter_date < end_date_only LOOP
    day_of_week := EXTRACT(DOW FROM iter_date);
    
    -- 0 = Sunday, 6 = Saturday, so count 1-5 (Monday-Friday)
    IF day_of_week BETWEEN 1 AND 5 THEN
      business_days := business_days + 1;
    END IF;
    
    iter_date := iter_date + 1;
  END LOOP;
  
  RETURN business_days;
END;
$$;

-- Update apply_for_shark_card to check for declined applications
CREATE OR REPLACE FUNCTION apply_for_shark_card(
  p_full_name text,
  p_country text,
  p_requested_limit numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_application_id uuid;
  v_existing_app uuid;
  v_last_declined_date timestamptz;
  v_business_days_passed integer;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  -- Check if user already has a pending or approved application
  SELECT application_id INTO v_existing_app
  FROM shark_card_applications
  WHERE user_id = v_user_id
    AND status IN ('pending', 'approved')
  LIMIT 1;
  
  IF v_existing_app IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'You already have a pending or approved application');
  END IF;
  
  -- Check for recent declined applications
  SELECT reviewed_at INTO v_last_declined_date
  FROM shark_card_applications
  WHERE user_id = v_user_id
    AND status = 'declined'
  ORDER BY reviewed_at DESC
  LIMIT 1;
  
  IF v_last_declined_date IS NOT NULL THEN
    v_business_days_passed := calculate_business_days(v_last_declined_date, now());
    
    IF v_business_days_passed < 5 THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', 'You must wait ' || (5 - v_business_days_passed) || ' more business day' || 
                CASE WHEN (5 - v_business_days_passed) > 1 THEN 's' ELSE '' END || 
                ' before reapplying. Your previous application was declined on ' || 
                to_char(v_last_declined_date, 'Mon DD, YYYY') || '.',
        'days_remaining', (5 - v_business_days_passed)
      );
    END IF;
  END IF;
  
  -- Create application
  INSERT INTO shark_card_applications (
    user_id, full_name, country, requested_limit
  )
  VALUES (
    v_user_id, p_full_name, p_country, p_requested_limit
  )
  RETURNING application_id INTO v_application_id;
  
  -- Create notification for admins
  INSERT INTO notifications (user_id, type, title, message, read)
  SELECT 
    id,
    'shark_card_application',
    'New Shark Card Application',
    p_full_name || ' applied for a Shark Card with ' || p_requested_limit || ' USDT limit',
    false
  FROM user_profiles
  WHERE is_admin = true;
  
  RETURN jsonb_build_object(
    'success', true,
    'application_id', v_application_id,
    'message', 'Application submitted successfully'
  );
END;
$$;