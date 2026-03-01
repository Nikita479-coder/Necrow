/*
  # Fix Track Visitor Session Function
  
  The function was failing to properly detect existing sessions
  and update them, causing duplicate key errors.
  
  Changes:
  - Use proper EXISTS check instead of SELECT INTO
  - Fix the update logic to correctly increment page views
*/

CREATE OR REPLACE FUNCTION track_visitor_session(
  p_session_id text,
  p_utm_source text DEFAULT NULL,
  p_utm_medium text DEFAULT NULL,
  p_utm_campaign text DEFAULT NULL,
  p_utm_content text DEFAULT NULL,
  p_utm_term text DEFAULT NULL,
  p_referrer_url text DEFAULT NULL,
  p_landing_page text DEFAULT NULL,
  p_device_type text DEFAULT NULL,
  p_browser text DEFAULT NULL,
  p_os text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_domain text;
  v_result_id uuid;
  v_exists boolean;
BEGIN
  -- Extract domain from referrer URL
  IF p_referrer_url IS NOT NULL AND p_referrer_url != '' THEN
    v_referrer_domain := regexp_replace(
      regexp_replace(p_referrer_url, '^https?://', ''),
      '/.*$', ''
    );
  END IF;
  
  -- Check if session already exists
  SELECT EXISTS(SELECT 1 FROM visitor_sessions WHERE session_id = p_session_id) INTO v_exists;
  
  IF v_exists THEN
    -- Update existing session
    UPDATE visitor_sessions SET
      last_visit_at = now(),
      page_views = COALESCE(page_views, 0) + 1,
      -- Only update UTM params if current ones are null and new ones are not
      utm_source = COALESCE(utm_source, NULLIF(p_utm_source, '')),
      utm_medium = COALESCE(utm_medium, NULLIF(p_utm_medium, '')),
      utm_campaign = COALESCE(utm_campaign, NULLIF(p_utm_campaign, '')),
      utm_content = COALESCE(utm_content, NULLIF(p_utm_content, '')),
      utm_term = COALESCE(utm_term, NULLIF(p_utm_term, ''))
    WHERE session_id = p_session_id
    RETURNING id INTO v_result_id;
  ELSE
    -- Insert new session
    INSERT INTO visitor_sessions (
      session_id,
      utm_source,
      utm_medium,
      utm_campaign,
      utm_content,
      utm_term,
      referrer_url,
      referrer_domain,
      landing_page,
      device_type,
      browser,
      os,
      page_views
    ) VALUES (
      p_session_id,
      NULLIF(p_utm_source, ''),
      NULLIF(p_utm_medium, ''),
      NULLIF(p_utm_campaign, ''),
      NULLIF(p_utm_content, ''),
      NULLIF(p_utm_term, ''),
      NULLIF(p_referrer_url, ''),
      v_referrer_domain,
      NULLIF(p_landing_page, ''),
      NULLIF(p_device_type, ''),
      NULLIF(p_browser, ''),
      NULLIF(p_os, ''),
      1
    )
    RETURNING id INTO v_result_id;
  END IF;
  
  RETURN v_result_id;
END;
$$;
