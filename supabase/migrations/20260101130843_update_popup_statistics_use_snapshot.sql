/*
  # Update Popup Statistics to Use Snapshot

  1. Changes
    - Modify `get_popup_statistics` function to return the snapshot value instead of dynamically calculating audience size
    - This preserves the original target count from creation time
*/

CREATE OR REPLACE FUNCTION get_popup_statistics()
RETURNS TABLE (
  popup_id uuid,
  title text,
  description text,
  image_url text,
  is_active boolean,
  created_at timestamptz,
  total_views bigint,
  unique_viewers bigint,
  view_percentage numeric,
  target_audiences text[],
  target_user_ids uuid[],
  audience_logic text,
  potential_reach bigint
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_users bigint;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  SELECT COUNT(*) INTO v_total_users FROM user_profiles;

  RETURN QUERY
  SELECT
    pb.id,
    pb.title,
    pb.description,
    pb.image_url,
    pb.is_active,
    pb.created_at,
    COUNT(pbv.id) as total_views,
    COUNT(DISTINCT pbv.user_id) as unique_viewers,
    CASE
      WHEN v_total_users > 0 THEN
        ROUND((COUNT(DISTINCT pbv.user_id)::numeric / v_total_users::numeric) * 100, 2)
      ELSE 0
    END as view_percentage,
    pb.target_audiences,
    pb.target_user_ids,
    pb.audience_logic,
    COALESCE(pb.target_count_snapshot, 0)::bigint as potential_reach  -- Use snapshot instead of dynamic calculation
  FROM popup_banners pb
  LEFT JOIN popup_banner_views pbv ON pb.id = pbv.popup_id
  GROUP BY pb.id, pb.title, pb.description, pb.image_url, pb.is_active, pb.created_at, pb.target_audiences, pb.target_user_ids, pb.audience_logic, pb.target_count_snapshot
  ORDER BY pb.created_at DESC;
END;
$$;
