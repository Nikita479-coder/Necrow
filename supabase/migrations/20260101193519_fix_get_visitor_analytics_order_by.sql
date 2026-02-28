/*
  # Fix Get Visitor Analytics Function
  
  Fix ORDER BY clause in daily_stats subquery - can't order by
  a column inside the jsonb object. Need to order by the actual date.
*/

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
      SELECT COALESCE(jsonb_agg(source_data), '[]'::jsonb)
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
        ) as source_data
        FROM visitor_sessions
        WHERE first_visit_at BETWEEN p_start_date AND p_end_date
        GROUP BY COALESCE(utm_source, referrer_domain, 'direct')
        ORDER BY COUNT(*) DESC
        LIMIT 20
      ) s
    ),
    'campaigns', (
      SELECT COALESCE(jsonb_agg(campaign_data), '[]'::jsonb)
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
        ) as campaign_data
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
      SELECT COALESCE(jsonb_agg(daily_data), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'date', to_char(visit_date, 'YYYY-MM-DD'),
          'visitors', visitor_count,
          'signups', signup_count
        ) as daily_data
        FROM (
          SELECT 
            first_visit_at::date as visit_date,
            COUNT(*) as visitor_count,
            COUNT(*) FILTER (WHERE converted = true) as signup_count
          FROM visitor_sessions
          WHERE first_visit_at BETWEEN p_start_date AND p_end_date
          GROUP BY first_visit_at::date
          ORDER BY first_visit_at::date
        ) daily_raw
      ) ds
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;
