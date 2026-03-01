/*
  # Fix Deposits Access for Staff and Hide Bolt from Acquisition

  1. Changes
    - Update admin_get_all_deposits to allow staff with view_wallets permission
    - Update get_visitor_analytics to exclude bolt.new and webcontainer URLs
    
  2. Security
    - Staff must have explicit view_wallets permission
*/

-- Update admin_get_all_deposits to allow staff with view_wallets permission
CREATE OR REPLACE FUNCTION admin_get_all_deposits(
  p_status text DEFAULT NULL,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_is_admin boolean := false;
  v_is_staff_with_permission boolean := false;
  v_deposits jsonb;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  -- Check if user is admin
  SELECT up.is_admin INTO v_is_admin
  FROM user_profiles up
  WHERE up.id = v_user_id;

  IF v_is_admin IS NOT TRUE THEN
    v_is_admin := COALESCE((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean, false);
  END IF;

  -- Check if user is staff with view_wallets permission
  IF v_is_admin IS NOT TRUE THEN
    SELECT EXISTS (
      SELECT 1 FROM admin_staff ast
      WHERE ast.id = v_user_id
        AND ast.is_active = true
        AND (
          EXISTS (
            SELECT 1 FROM admin_role_permissions arp
            JOIN admin_permissions ap ON ap.id = arp.permission_id
            WHERE arp.role_id = ast.role_id
              AND ap.code = 'view_wallets'
          )
          OR
          EXISTS (
            SELECT 1 FROM staff_permission_overrides spo
            JOIN admin_permissions ap ON ap.id = spo.permission_id
            WHERE spo.staff_id = ast.id
              AND ap.code = 'view_wallets'
              AND spo.is_granted = true
          )
        )
    ) INTO v_is_staff_with_permission;
  END IF;

  IF v_is_admin IS NOT TRUE AND v_is_staff_with_permission IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'Admin access required');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'payment_id', cd.payment_id,
      'user_id', cd.user_id,
      'user_email', au.email,
      'user_name', COALESCE(up.full_name, up.username, 'Unknown'),
      'nowpayments_payment_id', cd.nowpayments_payment_id,
      'price_amount', cd.price_amount,
      'price_currency', cd.price_currency,
      'pay_amount', cd.pay_amount,
      'pay_currency', cd.pay_currency,
      'pay_address', cd.pay_address,
      'status', cd.status,
      'actually_paid', cd.actually_paid,
      'outcome_amount', cd.outcome_amount,
      'created_at', cd.created_at,
      'updated_at', cd.updated_at,
      'completed_at', cd.completed_at,
      'expires_at', cd.expires_at,
      'wallet_type', cd.wallet_type
    ) ORDER BY cd.created_at DESC
  )
  INTO v_deposits
  FROM crypto_deposits cd
  JOIN auth.users au ON au.id = cd.user_id
  LEFT JOIN user_profiles up ON up.id = cd.user_id
  WHERE (p_status IS NULL OR cd.status = p_status)
  LIMIT p_limit
  OFFSET p_offset;

  RETURN jsonb_build_object(
    'success', true,
    'deposits', COALESCE(v_deposits, '[]'::jsonb)
  );
END;
$$;

-- Drop and recreate get_visitor_analytics to exclude bolt.new
DROP FUNCTION IF EXISTS get_visitor_analytics(timestamptz, timestamptz);

CREATE FUNCTION get_visitor_analytics(
  p_start_date timestamptz,
  p_end_date timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_total_visitors bigint;
  v_unique_visitors bigint;
  v_total_signups bigint;
  v_total_page_views bigint;
  v_sources jsonb;
  v_campaigns jsonb;
  v_devices jsonb;
  v_daily_stats jsonb;
BEGIN
  -- Filter out bolt.new and webcontainer URLs
  WITH filtered_sessions AS (
    SELECT * FROM visitor_sessions
    WHERE first_visit_at BETWEEN p_start_date AND p_end_date
      AND (referrer_domain IS NULL OR (
        referrer_domain NOT LIKE '%bolt.new%' 
        AND referrer_domain NOT LIKE '%webcontainer%'
        AND referrer_domain NOT LIKE '%stackblitz%'
      ))
      AND (utm_source IS NULL OR (
        utm_source NOT LIKE '%bolt%'
        AND utm_source NOT LIKE '%webcontainer%'
        AND utm_source NOT LIKE '%stackblitz%'
      ))
      AND (landing_page IS NULL OR (
        landing_page NOT LIKE '%webcontainer%'
        AND landing_page NOT LIKE '%local-credentialless%'
      ))
  )
  SELECT 
    COUNT(*),
    COUNT(DISTINCT session_id),
    COUNT(*) FILTER (WHERE converted = true),
    COALESCE(SUM(page_views), 0)
  INTO v_total_visitors, v_unique_visitors, v_total_signups, v_total_page_views
  FROM filtered_sessions;

  -- Sources breakdown (excluding bolt/webcontainer)
  WITH filtered_sessions AS (
    SELECT * FROM visitor_sessions
    WHERE first_visit_at BETWEEN p_start_date AND p_end_date
      AND (referrer_domain IS NULL OR (
        referrer_domain NOT LIKE '%bolt.new%' 
        AND referrer_domain NOT LIKE '%webcontainer%'
        AND referrer_domain NOT LIKE '%stackblitz%'
      ))
      AND (utm_source IS NULL OR (
        utm_source NOT LIKE '%bolt%'
        AND utm_source NOT LIKE '%webcontainer%'
        AND utm_source NOT LIKE '%stackblitz%'
      ))
      AND (landing_page IS NULL OR (
        landing_page NOT LIKE '%webcontainer%'
        AND landing_page NOT LIKE '%local-credentialless%'
      ))
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'source', COALESCE(source, 'direct'),
      'visitors', visitor_count,
      'signups', signup_count,
      'conversion_rate', CASE WHEN visitor_count > 0 THEN ROUND((signup_count::numeric / visitor_count) * 100, 1) ELSE 0 END,
      'page_views', total_page_views
    ) ORDER BY visitor_count DESC
  ), '[]'::jsonb)
  INTO v_sources
  FROM (
    SELECT 
      COALESCE(utm_source, referrer_domain, 'direct') as source,
      COUNT(*) as visitor_count,
      COUNT(*) FILTER (WHERE converted = true) as signup_count,
      SUM(page_views) as total_page_views
    FROM filtered_sessions
    GROUP BY COALESCE(utm_source, referrer_domain, 'direct')
  ) s;

  -- Campaigns breakdown (excluding bolt/webcontainer)
  WITH filtered_sessions AS (
    SELECT * FROM visitor_sessions
    WHERE first_visit_at BETWEEN p_start_date AND p_end_date
      AND utm_campaign IS NOT NULL
      AND (referrer_domain IS NULL OR (
        referrer_domain NOT LIKE '%bolt.new%' 
        AND referrer_domain NOT LIKE '%webcontainer%'
        AND referrer_domain NOT LIKE '%stackblitz%'
      ))
      AND (utm_source IS NULL OR (
        utm_source NOT LIKE '%bolt%'
        AND utm_source NOT LIKE '%webcontainer%'
        AND utm_source NOT LIKE '%stackblitz%'
      ))
      AND utm_campaign NOT LIKE '%bolt%'
      AND utm_campaign NOT LIKE '%webcontainer%'
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'campaign', campaign,
      'source', source,
      'visitors', visitor_count,
      'signups', signup_count,
      'conversion_rate', CASE WHEN visitor_count > 0 THEN ROUND((signup_count::numeric / visitor_count) * 100, 1) ELSE 0 END
    ) ORDER BY visitor_count DESC
  ), '[]'::jsonb)
  INTO v_campaigns
  FROM (
    SELECT 
      utm_campaign as campaign,
      COALESCE(utm_source, 'unknown') as source,
      COUNT(*) as visitor_count,
      COUNT(*) FILTER (WHERE converted = true) as signup_count
    FROM filtered_sessions
    GROUP BY utm_campaign, COALESCE(utm_source, 'unknown')
  ) c;

  -- Devices breakdown (excluding bolt/webcontainer)
  WITH filtered_sessions AS (
    SELECT * FROM visitor_sessions
    WHERE first_visit_at BETWEEN p_start_date AND p_end_date
      AND (referrer_domain IS NULL OR (
        referrer_domain NOT LIKE '%bolt.new%' 
        AND referrer_domain NOT LIKE '%webcontainer%'
        AND referrer_domain NOT LIKE '%stackblitz%'
      ))
      AND (utm_source IS NULL OR (
        utm_source NOT LIKE '%bolt%'
        AND utm_source NOT LIKE '%webcontainer%'
        AND utm_source NOT LIKE '%stackblitz%'
      ))
      AND (landing_page IS NULL OR (
        landing_page NOT LIKE '%webcontainer%'
        AND landing_page NOT LIKE '%local-credentialless%'
      ))
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'device', COALESCE(device, 'unknown'),
      'visitors', visitor_count,
      'signups', signup_count
    ) ORDER BY visitor_count DESC
  ), '[]'::jsonb)
  INTO v_devices
  FROM (
    SELECT 
      device_type as device,
      COUNT(*) as visitor_count,
      COUNT(*) FILTER (WHERE converted = true) as signup_count
    FROM filtered_sessions
    GROUP BY device_type
  ) d;

  -- Daily stats (excluding bolt/webcontainer)
  WITH filtered_sessions AS (
    SELECT * FROM visitor_sessions
    WHERE first_visit_at BETWEEN p_start_date AND p_end_date
      AND (referrer_domain IS NULL OR (
        referrer_domain NOT LIKE '%bolt.new%' 
        AND referrer_domain NOT LIKE '%webcontainer%'
        AND referrer_domain NOT LIKE '%stackblitz%'
      ))
      AND (utm_source IS NULL OR (
        utm_source NOT LIKE '%bolt%'
        AND utm_source NOT LIKE '%webcontainer%'
        AND utm_source NOT LIKE '%stackblitz%'
      ))
      AND (landing_page IS NULL OR (
        landing_page NOT LIKE '%webcontainer%'
        AND landing_page NOT LIKE '%local-credentialless%'
      ))
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'date', visit_date,
      'visitors', visitor_count,
      'signups', signup_count
    ) ORDER BY visit_date
  ), '[]'::jsonb)
  INTO v_daily_stats
  FROM (
    SELECT 
      DATE(first_visit_at) as visit_date,
      COUNT(*) as visitor_count,
      COUNT(*) FILTER (WHERE converted = true) as signup_count
    FROM filtered_sessions
    GROUP BY DATE(first_visit_at)
  ) ds;

  RETURN jsonb_build_object(
    'total_visitors', v_total_visitors,
    'unique_visitors', v_unique_visitors,
    'total_signups', v_total_signups,
    'overall_conversion_rate', CASE WHEN v_total_visitors > 0 THEN ROUND((v_total_signups::numeric / v_total_visitors) * 100, 1) ELSE 0 END,
    'total_page_views', v_total_page_views,
    'sources', v_sources,
    'campaigns', v_campaigns,
    'devices', v_devices,
    'daily_stats', v_daily_stats
  );
END;
$$;
