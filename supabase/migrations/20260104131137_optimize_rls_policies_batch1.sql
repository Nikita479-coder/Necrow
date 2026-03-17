/*
  # Optimize RLS Policies - Batch 1

  1. Performance Improvements
    - Replace auth.uid() with (select auth.uid()) in RLS policies
    - This prevents re-evaluation of auth function for each row
    
  2. Tables Fixed (Batch 1)
    - giveaway_tickets
    - user_rewards  
    - user_tasks_progress
    - referral_stats
    - giveaway_winners
    - giveaway_draw_audit
*/

-- giveaway_tickets
DROP POLICY IF EXISTS "Users can view their own tickets" ON giveaway_tickets;
CREATE POLICY "Users can view their own tickets"
  ON giveaway_tickets FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can manage all tickets" ON giveaway_tickets;
CREATE POLICY "Admins can manage all tickets"
  ON giveaway_tickets FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_rewards
DROP POLICY IF EXISTS "Users can insert own rewards" ON user_rewards;
CREATE POLICY "Users can insert own rewards"
  ON user_rewards FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- user_tasks_progress
DROP POLICY IF EXISTS "Users can read own task progress" ON user_tasks_progress;
CREATE POLICY "Users can read own task progress"
  ON user_tasks_progress FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own task progress" ON user_tasks_progress;
CREATE POLICY "Users can update own task progress"
  ON user_tasks_progress FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own task progress" ON user_tasks_progress;
CREATE POLICY "Users can insert own task progress"
  ON user_tasks_progress FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- referral_stats
DROP POLICY IF EXISTS "Users can update own referral stats" ON referral_stats;
CREATE POLICY "Users can update own referral stats"
  ON referral_stats FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- giveaway_winners
DROP POLICY IF EXISTS "Users can view their own wins" ON giveaway_winners;
CREATE POLICY "Users can view their own wins"
  ON giveaway_winners FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can manage all winners" ON giveaway_winners;
CREATE POLICY "Admins can manage all winners"
  ON giveaway_winners FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- giveaway_draw_audit
DROP POLICY IF EXISTS "Admins can view draw audit" ON giveaway_draw_audit;
CREATE POLICY "Admins can view draw audit"
  ON giveaway_draw_audit FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can insert draw audit" ON giveaway_draw_audit;
CREATE POLICY "Admins can insert draw audit"
  ON giveaway_draw_audit FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));
