/*
  # Acquisition Analytics Functions
  
  Functions to get acquisition analytics data for admin dashboard.
  
  1. Functions
    - `get_acquisition_overview` - Overall acquisition stats
    - `get_acquisition_by_source` - Breakdown by traffic source
    - `get_acquisition_by_campaign` - Breakdown by campaign
    - `get_acquisition_timeline` - Signups over time by source
    - `get_conversion_funnel` - Conversion funnel stats
    - `save_user_acquisition_data` - Save acquisition data on signup
    - `record_acquisition_event` - Record conversion events
    - `increment_campaign_link_click` - Track link clicks
*/

-- Function to save user acquisition data
CREATE OR REPLACE FUNCTION save_user_acquisition_data(
  p_user_id uuid,
  p_utm_source text DEFAULT NULL,
  p_utm_medium text DEFAULT NULL,
  p_utm_campaign text DEFAULT NULL,
  p_utm_content text DEFAULT NULL,
  p_utm_term text DEFAULT NULL,
  p_referrer_url text DEFAULT NULL,
  p_landing_page text DEFAULT NULL,
  p_device_type text DEFAULT NULL,
  p_browser text DEFAULT NULL,
  p_os text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_ip_address text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_domain text;
  v_result_id uuid;
BEGIN
  -- Extract domain from referrer URL
  IF p_referrer_url IS NOT NULL AND p_referrer_url != '' THEN
    v_referrer_domain := regexp_replace(
      regexp_replace(p_referrer_url, '^https?://', ''),
      '/.*$', ''
    );
  END IF;
  
  -- Insert or update acquisition data
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
    ip_address
  ) VALUES (
    p_user_id,
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
    NULLIF(p_country, ''),
    NULLIF(p_city, ''),
    NULLIF(p_ip_address, '')
  )
  ON CONFLICT (user_id) DO UPDATE SET
    utm_source = COALESCE(NULLIF(EXCLUDED.utm_source, ''), user_acquisition_sources.utm_source),
    utm_medium = COALESCE(NULLIF(EXCLUDED.utm_medium, ''), user_acquisition_sources.utm_medium),
    utm_campaign = COALESCE(NULLIF(EXCLUDED.utm_campaign, ''), user_acquisition_sources.utm_campaign),
    utm_content = COALESCE(NULLIF(EXCLUDED.utm_content, ''), user_acquisition_sources.utm_content),
    utm_term = COALESCE(NULLIF(EXCLUDED.utm_term, ''), user_acquisition_sources.utm_term),
    referrer_url = COALESCE(NULLIF(EXCLUDED.referrer_url, ''), user_acquisition_sources.referrer_url),
    referrer_domain = COALESCE(EXCLUDED.referrer_domain, user_acquisition_sources.referrer_domain),
    landing_page = COALESCE(NULLIF(EXCLUDED.landing_page, ''), user_acquisition_sources.landing_page),
    device_type = COALESCE(NULLIF(EXCLUDED.device_type, ''), user_acquisition_sources.device_type),
    browser = COALESCE(NULLIF(EXCLUDED.browser, ''), user_acquisition_sources.browser),
    os = COALESCE(NULLIF(EXCLUDED.os, ''), user_acquisition_sources.os),
    country = COALESCE(NULLIF(EXCLUDED.country, ''), user_acquisition_sources.country),
    city = COALESCE(NULLIF(EXCLUDED.city, ''), user_acquisition_sources.city),
    ip_address = COALESCE(NULLIF(EXCLUDED.ip_address, ''), user_acquisition_sources.ip_address)
  RETURNING id INTO v_result_id;
  
  -- Record signup event
  INSERT INTO acquisition_events (user_id, event_type, event_data)
  VALUES (p_user_id, 'signup', jsonb_build_object(
    'utm_source', p_utm_source,
    'utm_campaign', p_utm_campaign
  ));
  
  RETURN v_result_id;
END;
$$;

-- Function to record acquisition events
CREATE OR REPLACE FUNCTION record_acquisition_event(
  p_user_id uuid,
  p_event_type text,
  p_event_data jsonb DEFAULT '{}'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
BEGIN
  INSERT INTO acquisition_events (user_id, event_type, event_data)
  VALUES (p_user_id, p_event_type, p_event_data)
  RETURNING id INTO v_event_id;
  
  -- If this is a conversion event, update campaign link stats
  IF p_event_type = 'signup' THEN
    UPDATE campaign_tracking_links
    SET conversions = conversions + 1
    WHERE utm_source = (p_event_data->>'utm_source')
    AND utm_campaign = (p_event_data->>'utm_campaign');
  END IF;
  
  RETURN v_event_id;
END;
$$;

-- Function to increment campaign link clicks
CREATE OR REPLACE FUNCTION increment_campaign_link_click(p_short_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_link campaign_tracking_links;
BEGIN
  UPDATE campaign_tracking_links
  SET clicks = clicks + 1
  WHERE short_code = p_short_code
  AND is_active = true
  RETURNING * INTO v_link;
  
  IF v_link IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Link not found');
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'destination_url', v_link.destination_url,
    'utm_source', v_link.utm_source,
    'utm_medium', v_link.utm_medium,
    'utm_campaign', v_link.utm_campaign,
    'utm_content', v_link.utm_content,
    'utm_term', v_link.utm_term
  );
END;
$$;

-- Function to get acquisition overview stats
CREATE OR REPLACE FUNCTION get_acquisition_overview(
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
    'total_signups', (
      SELECT COUNT(DISTINCT user_id)
      FROM user_acquisition_sources
      WHERE created_at BETWEEN p_start_date AND p_end_date
    ),
    'organic_signups', (
      SELECT COUNT(DISTINCT user_id)
      FROM user_acquisition_sources
      WHERE created_at BETWEEN p_start_date AND p_end_date
      AND (utm_source IS NULL OR utm_source = 'direct')
    ),
    'paid_signups', (
      SELECT COUNT(DISTINCT user_id)
      FROM user_acquisition_sources
      WHERE created_at BETWEEN p_start_date AND p_end_date
      AND utm_medium IN ('cpc', 'ppc', 'paid', 'ad', 'ads')
    ),
    'social_signups', (
      SELECT COUNT(DISTINCT user_id)
      FROM user_acquisition_sources
      WHERE created_at BETWEEN p_start_date AND p_end_date
      AND (utm_medium = 'social' OR utm_source IN ('facebook', 'instagram', 'tiktok', 'twitter', 'linkedin', 'youtube'))
    ),
    'top_sources', (
      SELECT COALESCE(jsonb_agg(source_data), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'source', COALESCE(utm_source, 'direct'),
          'count', COUNT(*),
          'percentage', ROUND(COUNT(*) * 100.0 / NULLIF((
            SELECT COUNT(*) FROM user_acquisition_sources
            WHERE created_at BETWEEN p_start_date AND p_end_date
          ), 0), 1)
        ) as source_data
        FROM user_acquisition_sources
        WHERE created_at BETWEEN p_start_date AND p_end_date
        GROUP BY utm_source
        ORDER BY COUNT(*) DESC
        LIMIT 10
      ) s
    ),
    'devices', (
      SELECT COALESCE(jsonb_agg(device_data), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'device', COALESCE(device_type, 'unknown'),
          'count', COUNT(*)
        ) as device_data
        FROM user_acquisition_sources
        WHERE created_at BETWEEN p_start_date AND p_end_date
        GROUP BY device_type
        ORDER BY COUNT(*) DESC
      ) d
    ),
    'countries', (
      SELECT COALESCE(jsonb_agg(country_data), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'country', COALESCE(country, 'unknown'),
          'count', COUNT(*)
        ) as country_data
        FROM user_acquisition_sources
        WHERE created_at BETWEEN p_start_date AND p_end_date
        AND country IS NOT NULL
        GROUP BY country
        ORDER BY COUNT(*) DESC
        LIMIT 10
      ) c
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;

-- Function to get detailed acquisition by source
CREATE OR REPLACE FUNCTION get_acquisition_by_source(
  p_start_date timestamptz DEFAULT now() - interval '30 days',
  p_end_date timestamptz DEFAULT now()
)
RETURNS TABLE (
  source text,
  medium text,
  signups bigint,
  first_deposits bigint,
  first_trades bigint,
  total_deposited numeric,
  conversion_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(uas.utm_source, 'direct') as source,
    COALESCE(uas.utm_medium, 'none') as medium,
    COUNT(DISTINCT uas.user_id) as signups,
    COUNT(DISTINCT CASE WHEN ae.event_type = 'first_deposit' THEN ae.user_id END) as first_deposits,
    COUNT(DISTINCT CASE WHEN ae.event_type = 'first_trade' THEN ae.user_id END) as first_trades,
    COALESCE(SUM(CASE WHEN ae.event_type = 'first_deposit' THEN (ae.event_data->>'amount')::numeric END), 0) as total_deposited,
    ROUND(
      COUNT(DISTINCT CASE WHEN ae.event_type = 'first_deposit' THEN ae.user_id END) * 100.0 / 
      NULLIF(COUNT(DISTINCT uas.user_id), 0),
      1
    ) as conversion_rate
  FROM user_acquisition_sources uas
  LEFT JOIN acquisition_events ae ON uas.user_id = ae.user_id
  WHERE uas.created_at BETWEEN p_start_date AND p_end_date
  GROUP BY uas.utm_source, uas.utm_medium
  ORDER BY signups DESC;
END;
$$;

-- Function to get acquisition by campaign
CREATE OR REPLACE FUNCTION get_acquisition_by_campaign(
  p_start_date timestamptz DEFAULT now() - interval '30 days',
  p_end_date timestamptz DEFAULT now()
)
RETURNS TABLE (
  campaign text,
  source text,
  medium text,
  signups bigint,
  clicks bigint,
  conversions bigint,
  conversion_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(uas.utm_campaign, 'no_campaign') as campaign,
    COALESCE(uas.utm_source, 'direct') as source,
    COALESCE(uas.utm_medium, 'none') as medium,
    COUNT(DISTINCT uas.user_id) as signups,
    COALESCE(MAX(ctl.clicks), 0)::bigint as clicks,
    COALESCE(MAX(ctl.conversions), 0)::bigint as conversions,
    ROUND(
      COUNT(DISTINCT uas.user_id) * 100.0 / NULLIF(MAX(ctl.clicks), 0),
      1
    ) as conversion_rate
  FROM user_acquisition_sources uas
  LEFT JOIN campaign_tracking_links ctl ON 
    uas.utm_source = ctl.utm_source 
    AND uas.utm_campaign = ctl.utm_campaign
  WHERE uas.created_at BETWEEN p_start_date AND p_end_date
  AND uas.utm_campaign IS NOT NULL
  GROUP BY uas.utm_campaign, uas.utm_source, uas.utm_medium
  ORDER BY signups DESC;
END;
$$;

-- Function to get acquisition timeline
CREATE OR REPLACE FUNCTION get_acquisition_timeline(
  p_start_date timestamptz DEFAULT now() - interval '30 days',
  p_end_date timestamptz DEFAULT now(),
  p_interval text DEFAULT 'day'
)
RETURNS TABLE (
  period text,
  source text,
  count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE p_interval
      WHEN 'hour' THEN to_char(uas.created_at, 'YYYY-MM-DD HH24:00')
      WHEN 'day' THEN to_char(uas.created_at, 'YYYY-MM-DD')
      WHEN 'week' THEN to_char(date_trunc('week', uas.created_at), 'YYYY-MM-DD')
      WHEN 'month' THEN to_char(uas.created_at, 'YYYY-MM')
      ELSE to_char(uas.created_at, 'YYYY-MM-DD')
    END as period,
    COALESCE(uas.utm_source, 'direct') as source,
    COUNT(*) as count
  FROM user_acquisition_sources uas
  WHERE uas.created_at BETWEEN p_start_date AND p_end_date
  GROUP BY period, source
  ORDER BY period, count DESC;
END;
$$;

-- Function to get conversion funnel
CREATE OR REPLACE FUNCTION get_conversion_funnel(
  p_source text DEFAULT NULL,
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
  v_total_signups bigint;
  v_kyc_completed bigint;
  v_first_deposits bigint;
  v_first_trades bigint;
BEGIN
  -- Get total signups
  SELECT COUNT(DISTINCT user_id) INTO v_total_signups
  FROM user_acquisition_sources
  WHERE created_at BETWEEN p_start_date AND p_end_date
  AND (p_source IS NULL OR utm_source = p_source);
  
  -- Get KYC completed
  SELECT COUNT(DISTINCT ae.user_id) INTO v_kyc_completed
  FROM acquisition_events ae
  JOIN user_acquisition_sources uas ON ae.user_id = uas.user_id
  WHERE ae.event_type = 'kyc_completed'
  AND uas.created_at BETWEEN p_start_date AND p_end_date
  AND (p_source IS NULL OR uas.utm_source = p_source);
  
  -- Get first deposits
  SELECT COUNT(DISTINCT ae.user_id) INTO v_first_deposits
  FROM acquisition_events ae
  JOIN user_acquisition_sources uas ON ae.user_id = uas.user_id
  WHERE ae.event_type = 'first_deposit'
  AND uas.created_at BETWEEN p_start_date AND p_end_date
  AND (p_source IS NULL OR uas.utm_source = p_source);
  
  -- Get first trades
  SELECT COUNT(DISTINCT ae.user_id) INTO v_first_trades
  FROM acquisition_events ae
  JOIN user_acquisition_sources uas ON ae.user_id = uas.user_id
  WHERE ae.event_type = 'first_trade'
  AND uas.created_at BETWEEN p_start_date AND p_end_date
  AND (p_source IS NULL OR uas.utm_source = p_source);
  
  v_result := jsonb_build_object(
    'signups', jsonb_build_object('count', v_total_signups, 'percentage', 100),
    'kyc_completed', jsonb_build_object(
      'count', v_kyc_completed, 
      'percentage', ROUND(v_kyc_completed * 100.0 / NULLIF(v_total_signups, 0), 1)
    ),
    'first_deposit', jsonb_build_object(
      'count', v_first_deposits,
      'percentage', ROUND(v_first_deposits * 100.0 / NULLIF(v_total_signups, 0), 1)
    ),
    'first_trade', jsonb_build_object(
      'count', v_first_trades,
      'percentage', ROUND(v_first_trades * 100.0 / NULLIF(v_total_signups, 0), 1)
    )
  );
  
  RETURN v_result;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION save_user_acquisition_data TO authenticated;
GRANT EXECUTE ON FUNCTION record_acquisition_event TO authenticated;
GRANT EXECUTE ON FUNCTION increment_campaign_link_click TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_acquisition_overview TO authenticated;
GRANT EXECUTE ON FUNCTION get_acquisition_by_source TO authenticated;
GRANT EXECUTE ON FUNCTION get_acquisition_by_campaign TO authenticated;
GRANT EXECUTE ON FUNCTION get_acquisition_timeline TO authenticated;
GRANT EXECUTE ON FUNCTION get_conversion_funnel TO authenticated;
