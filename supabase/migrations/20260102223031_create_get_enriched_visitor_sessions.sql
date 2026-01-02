/*
  # Create Get Enriched Visitor Sessions Function

  Creates a function to retrieve visitor sessions with user profile data joined.
  This allows admins to see visitor data along with signup information.
*/

CREATE OR REPLACE FUNCTION get_enriched_visitor_sessions(
  p_start_date timestamptz DEFAULT now() - interval '30 days',
  p_limit integer DEFAULT 500
)
RETURNS TABLE (
  id uuid,
  session_id text,
  user_id uuid,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  referrer_url text,
  referrer_domain text,
  landing_page text,
  device_type text,
  browser text,
  os text,
  country text,
  city text,
  ip_address text,
  first_visit_at timestamptz,
  last_visit_at timestamptz,
  page_views integer,
  converted boolean,
  conversion_date timestamptz,
  email text,
  full_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.id = auth.uid()
    AND user_profiles.is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  RETURN QUERY
  SELECT
    vs.id,
    vs.session_id,
    vs.user_id,
    vs.utm_source,
    vs.utm_medium,
    vs.utm_campaign,
    vs.utm_content,
    vs.utm_term,
    vs.referrer_url,
    vs.referrer_domain,
    vs.landing_page,
    vs.device_type,
    vs.browser,
    vs.os,
    vs.country,
    vs.city,
    vs.ip_address,
    vs.first_visit_at,
    vs.last_visit_at,
    vs.page_views,
    vs.converted,
    vs.conversion_date,
    au.email::text,
    up.full_name
  FROM visitor_sessions vs
  LEFT JOIN auth.users au ON vs.user_id = au.id
  LEFT JOIN user_profiles up ON vs.user_id = up.id
  WHERE vs.first_visit_at >= p_start_date
  ORDER BY vs.first_visit_at DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_enriched_visitor_sessions TO authenticated;