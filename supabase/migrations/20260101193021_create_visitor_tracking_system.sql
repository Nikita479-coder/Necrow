/*
  # Visitor Tracking System
  
  Track ALL visitors to the site, not just those who sign up.
  This allows us to see the full funnel: Visits -> Signups -> Conversions
  
  1. New Tables
    - `visitor_sessions` - Track every unique visitor session
      - `id` (uuid, primary key)
      - `session_id` (text, unique) - Browser-generated session ID
      - `user_id` (uuid, nullable) - Linked after signup
      - `utm_source`, `utm_medium`, `utm_campaign`, etc.
      - `referrer_url`, `referrer_domain`
      - `landing_page`
      - `device_type`, `browser`, `os`
      - `country`, `city`, `ip_address`
      - `first_visit_at`, `last_visit_at`
      - `page_views` (integer)
      - `converted` (boolean) - Did they sign up?
      
  2. Functions
    - `track_visitor_session` - Track/update a visitor session
    - `link_visitor_to_user` - Link a visitor session to a signed up user
    - `get_visitor_analytics` - Get visit/signup stats
*/

-- Visitor sessions table
CREATE TABLE IF NOT EXISTS visitor_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id text UNIQUE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
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
  first_visit_at timestamptz DEFAULT now(),
  last_visit_at timestamptz DEFAULT now(),
  page_views integer DEFAULT 1,
  converted boolean DEFAULT false,
  conversion_date timestamptz
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_session_id ON visitor_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_user_id ON visitor_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_utm_source ON visitor_sessions(utm_source);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_utm_campaign ON visitor_sessions(utm_campaign);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_first_visit ON visitor_sessions(first_visit_at);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_converted ON visitor_sessions(converted);
CREATE INDEX IF NOT EXISTS idx_visitor_sessions_referrer_domain ON visitor_sessions(referrer_domain);

-- Enable RLS
ALTER TABLE visitor_sessions ENABLE ROW LEVEL SECURITY;

-- Anyone can insert visitor sessions (for tracking anonymous visitors)
CREATE POLICY "Anyone can insert visitor sessions"
  ON visitor_sessions FOR INSERT
  WITH CHECK (true);

-- Anyone can update their own session by session_id
CREATE POLICY "Anyone can update visitor sessions by session_id"
  ON visitor_sessions FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Admins can view all sessions
CREATE POLICY "Admins can view all visitor sessions"
  ON visitor_sessions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Function to track/update visitor session
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
  v_existing visitor_sessions;
BEGIN
  -- Extract domain from referrer URL
  IF p_referrer_url IS NOT NULL AND p_referrer_url != '' THEN
    v_referrer_domain := regexp_replace(
      regexp_replace(p_referrer_url, '^https?://', ''),
      '/.*$', ''
    );
  END IF;
  
  -- Check if session already exists
  SELECT * INTO v_existing FROM visitor_sessions WHERE session_id = p_session_id;
  
  IF v_existing IS NOT NULL THEN
    -- Update existing session
    UPDATE visitor_sessions SET
      last_visit_at = now(),
      page_views = page_views + 1,
      -- Only update UTM params if current ones are null and new ones are not
      utm_source = COALESCE(visitor_sessions.utm_source, NULLIF(p_utm_source, '')),
      utm_medium = COALESCE(visitor_sessions.utm_medium, NULLIF(p_utm_medium, '')),
      utm_campaign = COALESCE(visitor_sessions.utm_campaign, NULLIF(p_utm_campaign, '')),
      utm_content = COALESCE(visitor_sessions.utm_content, NULLIF(p_utm_content, '')),
      utm_term = COALESCE(visitor_sessions.utm_term, NULLIF(p_utm_term, ''))
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
      os
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
      NULLIF(p_os, '')
    )
    RETURNING id INTO v_result_id;
  END IF;
  
  RETURN v_result_id;
END;
$$;

-- Function to link visitor session to user after signup
CREATE OR REPLACE FUNCTION link_visitor_to_user(
  p_session_id text,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_visitor visitor_sessions;
BEGIN
  -- Update the visitor session
  UPDATE visitor_sessions SET
    user_id = p_user_id,
    converted = true,
    conversion_date = now()
  WHERE session_id = p_session_id;
  
  -- Get the visitor data to copy to user_acquisition_sources
  SELECT * INTO v_visitor FROM visitor_sessions WHERE session_id = p_session_id;
  
  IF v_visitor IS NOT NULL THEN
    -- Also save to user_acquisition_sources for backward compatibility
    INSERT INTO user_acquisition_sources (
      user_id,
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
      country,
      city,
      ip_address,
      session_id
    ) VALUES (
      p_user_id,
      v_visitor.utm_source,
      v_visitor.utm_medium,
      v_visitor.utm_campaign,
      v_visitor.utm_content,
      v_visitor.utm_term,
      v_visitor.referrer_url,
      v_visitor.referrer_domain,
      v_visitor.landing_page,
      v_visitor.device_type,
      v_visitor.browser,
      v_visitor.os,
      v_visitor.country,
      v_visitor.city,
      v_visitor.ip_address,
      p_session_id
    )
    ON CONFLICT (user_id) DO UPDATE SET
      utm_source = COALESCE(EXCLUDED.utm_source, user_acquisition_sources.utm_source),
      utm_medium = COALESCE(EXCLUDED.utm_medium, user_acquisition_sources.utm_medium),
      utm_campaign = COALESCE(EXCLUDED.utm_campaign, user_acquisition_sources.utm_campaign),
      utm_content = COALESCE(EXCLUDED.utm_content, user_acquisition_sources.utm_content),
      utm_term = COALESCE(EXCLUDED.utm_term, user_acquisition_sources.utm_term),
      referrer_url = COALESCE(EXCLUDED.referrer_url, user_acquisition_sources.referrer_url),
      referrer_domain = COALESCE(EXCLUDED.referrer_domain, user_acquisition_sources.referrer_domain),
      landing_page = COALESCE(EXCLUDED.landing_page, user_acquisition_sources.landing_page),
      device_type = COALESCE(EXCLUDED.device_type, user_acquisition_sources.device_type),
      browser = COALESCE(EXCLUDED.browser, user_acquisition_sources.browser),
      os = COALESCE(EXCLUDED.os, user_acquisition_sources.os),
      session_id = COALESCE(EXCLUDED.session_id, user_acquisition_sources.session_id);
      
    -- Record signup event
    INSERT INTO acquisition_events (user_id, event_type, event_data)
    VALUES (p_user_id, 'signup', jsonb_build_object(
      'utm_source', v_visitor.utm_source,
      'utm_campaign', v_visitor.utm_campaign,
      'session_id', p_session_id
    ));
  END IF;
END;
$$;

-- Function to get comprehensive visitor analytics
CREATE OR REPLACE FUNCTION get_visitor_analytics(
  p_start_date timestamptz DEFAULT now() - interval '30 days',
  p_end_date timestamptz DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_visitors', (
      SELECT COUNT(*) FROM visitor_sessions
      WHERE first_visit_at BETWEEN p_start_date AND p_end_date
    ),
    'unique_visitors', (
      SELECT COUNT(DISTINCT session_id) FROM visitor_sessions
      WHERE first_visit_at BETWEEN p_start_date AND p_end_date
    ),
    'total_signups', (
      SELECT COUNT(*) FROM visitor_sessions
      WHERE first_visit_at BETWEEN p_start_date AND p_end_date
      AND converted = true
    ),
    'overall_conversion_rate', (
      SELECT ROUND(
        COUNT(*) FILTER (WHERE converted = true) * 100.0 / NULLIF(COUNT(*), 0),
        2
      )
      FROM visitor_sessions
      WHERE first_visit_at BETWEEN p_start_date AND p_end_date
    ),
    'total_page_views', (
      SELECT COALESCE(SUM(page_views), 0) FROM visitor_sessions
      WHERE first_visit_at BETWEEN p_start_date AND p_end_date
    ),
    'sources', (
      SELECT COALESCE(jsonb_agg(source_data ORDER BY visitors DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'source', COALESCE(utm_source, referrer_domain, 'direct'),
          'visitors', COUNT(*),
          'signups', COUNT(*) FILTER (WHERE converted = true),
          'conversion_rate', ROUND(
            COUNT(*) FILTER (WHERE converted = true) * 100.0 / NULLIF(COUNT(*), 0),
            2
          ),
          'page_views', SUM(page_views)
        ) as source_data,
        COUNT(*) as visitors
        FROM visitor_sessions
        WHERE first_visit_at BETWEEN p_start_date AND p_end_date
        GROUP BY COALESCE(utm_source, referrer_domain, 'direct')
        ORDER BY COUNT(*) DESC
        LIMIT 20
      ) s
    ),
    'campaigns', (
      SELECT COALESCE(jsonb_agg(campaign_data ORDER BY visitors DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'campaign', utm_campaign,
          'source', COALESCE(utm_source, 'unknown'),
          'visitors', COUNT(*),
          'signups', COUNT(*) FILTER (WHERE converted = true),
          'conversion_rate', ROUND(
            COUNT(*) FILTER (WHERE converted = true) * 100.0 / NULLIF(COUNT(*), 0),
            2
          )
        ) as campaign_data,
        COUNT(*) as visitors
        FROM visitor_sessions
        WHERE first_visit_at BETWEEN p_start_date AND p_end_date
        AND utm_campaign IS NOT NULL
        GROUP BY utm_campaign, utm_source
        ORDER BY COUNT(*) DESC
        LIMIT 20
      ) c
    ),
    'devices', (
      SELECT COALESCE(jsonb_agg(device_data), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'device', COALESCE(device_type, 'unknown'),
          'visitors', COUNT(*),
          'signups', COUNT(*) FILTER (WHERE converted = true)
        ) as device_data
        FROM visitor_sessions
        WHERE first_visit_at BETWEEN p_start_date AND p_end_date
        GROUP BY device_type
        ORDER BY COUNT(*) DESC
      ) d
    ),
    'daily_stats', (
      SELECT COALESCE(jsonb_agg(daily_data ORDER BY date), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'date', to_char(first_visit_at::date, 'YYYY-MM-DD'),
          'visitors', COUNT(*),
          'signups', COUNT(*) FILTER (WHERE converted = true)
        ) as daily_data
        FROM visitor_sessions
        WHERE first_visit_at BETWEEN p_start_date AND p_end_date
        GROUP BY first_visit_at::date
        ORDER BY first_visit_at::date
      ) ds
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION track_visitor_session TO anon, authenticated;
GRANT EXECUTE ON FUNCTION link_visitor_to_user TO authenticated;
GRANT EXECUTE ON FUNCTION get_visitor_analytics TO authenticated;
