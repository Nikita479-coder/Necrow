/*
  # Set Default Target Count Snapshots

  1. Changes
    - Set reasonable default values for existing popup banners based on their targeting
    - If no targeting, set to total user count at migration time
*/

DO $$
DECLARE
  v_total_users integer;
BEGIN
  -- Get current total user count
  SELECT COUNT(*)::integer INTO v_total_users FROM user_profiles;
  
  -- Update popups with no targeting to have the total user count
  UPDATE popup_banners
  SET target_count_snapshot = v_total_users,
      updated_at = now()
  WHERE (target_count_snapshot = 0 OR target_count_snapshot IS NULL)
    AND (target_audiences IS NULL OR array_length(target_audiences, 1) IS NULL);
  
  -- For popups with specific targeting, set to their unique viewer count
  -- (conservative estimate that they were shown to approximately who saw them)
  UPDATE popup_banners pb
  SET target_count_snapshot = GREATEST(
    (SELECT COUNT(DISTINCT user_id)::integer FROM popup_banner_views WHERE popup_id = pb.id),
    1
  ),
  updated_at = now()
  WHERE (target_count_snapshot = 0 OR target_count_snapshot IS NULL)
    AND target_audiences IS NOT NULL
    AND array_length(target_audiences, 1) > 0;
END $$;
