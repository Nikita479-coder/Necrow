/*
  # Optimize RLS Policies - Batch 3 (Copy Trading - Fixed)

  1. Performance Improvements
    - Replace auth.uid() with (select auth.uid()) in RLS policies
    
  2. Tables Fixed
    - copy_positions
    - copy_position_history
    - copy_trading_stats
    - copy_trade_responses
    - copy_trade_notifications
    - copy_trade_daily_performance
    - copy_trade_allocations
    - pending_copy_trades
    - admin_managed_traders
    - admin_trader_positions
    - trader_trades
    - traders
*/

-- copy_positions
DROP POLICY IF EXISTS "Users can view own copy positions" ON copy_positions;
CREATE POLICY "Users can view own copy positions"
  ON copy_positions FOR SELECT
  TO authenticated
  USING (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own copy positions" ON copy_positions;
CREATE POLICY "Users can insert own copy positions"
  ON copy_positions FOR INSERT
  TO authenticated
  WITH CHECK (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own copy positions" ON copy_positions;
CREATE POLICY "Users can update own copy positions"
  ON copy_positions FOR UPDATE
  TO authenticated
  USING (follower_id = (select auth.uid()))
  WITH CHECK (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own copy positions" ON copy_positions;
CREATE POLICY "Users can delete own copy positions"
  ON copy_positions FOR DELETE
  TO authenticated
  USING (follower_id = (select auth.uid()));

-- copy_position_history
DROP POLICY IF EXISTS "Users can view own copy history" ON copy_position_history;
CREATE POLICY "Users can view own copy history"
  ON copy_position_history FOR SELECT
  TO authenticated
  USING (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own copy history" ON copy_position_history;
CREATE POLICY "Users can insert own copy history"
  ON copy_position_history FOR INSERT
  TO authenticated
  WITH CHECK (follower_id = (select auth.uid()));

-- copy_trading_stats
DROP POLICY IF EXISTS "Users can view own copy stats" ON copy_trading_stats;
CREATE POLICY "Users can view own copy stats"
  ON copy_trading_stats FOR SELECT
  TO authenticated
  USING (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own copy stats" ON copy_trading_stats;
CREATE POLICY "Users can insert own copy stats"
  ON copy_trading_stats FOR INSERT
  TO authenticated
  WITH CHECK (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own copy stats" ON copy_trading_stats;
CREATE POLICY "Users can update own copy stats"
  ON copy_trading_stats FOR UPDATE
  TO authenticated
  USING (follower_id = (select auth.uid()))
  WITH CHECK (follower_id = (select auth.uid()));

-- copy_trade_responses
DROP POLICY IF EXISTS "Followers can view own responses" ON copy_trade_responses;
CREATE POLICY "Followers can view own responses"
  ON copy_trade_responses FOR SELECT
  TO authenticated
  USING (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Followers can create responses" ON copy_trade_responses;
CREATE POLICY "Followers can create responses"
  ON copy_trade_responses FOR INSERT
  TO authenticated
  WITH CHECK (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can view all responses" ON copy_trade_responses;
CREATE POLICY "Admins can view all responses"
  ON copy_trade_responses FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- copy_trade_notifications
DROP POLICY IF EXISTS "Users can view own notifications" ON copy_trade_notifications;
CREATE POLICY "Users can view own notifications"
  ON copy_trade_notifications FOR SELECT
  TO authenticated
  USING (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own notifications" ON copy_trade_notifications;
CREATE POLICY "Users can update own notifications"
  ON copy_trade_notifications FOR UPDATE
  TO authenticated
  USING (follower_id = (select auth.uid()))
  WITH CHECK (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own notifications" ON copy_trade_notifications;
CREATE POLICY "Users can delete own notifications"
  ON copy_trade_notifications FOR DELETE
  TO authenticated
  USING (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can view all notifications" ON copy_trade_notifications;
CREATE POLICY "Admins can view all notifications"
  ON copy_trade_notifications FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- copy_trade_daily_performance
DROP POLICY IF EXISTS "Users can view own copy performance" ON copy_trade_daily_performance;
CREATE POLICY "Users can view own copy performance"
  ON copy_trade_daily_performance FOR SELECT
  TO authenticated
  USING (follower_id = (select auth.uid()));

-- copy_trade_allocations
DROP POLICY IF EXISTS "Admins can view all allocations" ON copy_trade_allocations;
CREATE POLICY "Admins can view all allocations"
  ON copy_trade_allocations FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- pending_copy_trades
DROP POLICY IF EXISTS "Admins can view all pending trades" ON pending_copy_trades;
CREATE POLICY "Admins can view all pending trades"
  ON pending_copy_trades FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- admin_managed_traders
DROP POLICY IF EXISTS "Admins can view all managed traders" ON admin_managed_traders;
CREATE POLICY "Admins can view all managed traders"
  ON admin_managed_traders FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can insert managed traders" ON admin_managed_traders;
CREATE POLICY "Admins can insert managed traders"
  ON admin_managed_traders FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update managed traders" ON admin_managed_traders;
CREATE POLICY "Admins can update managed traders"
  ON admin_managed_traders FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can delete managed traders" ON admin_managed_traders;
CREATE POLICY "Admins can delete managed traders"
  ON admin_managed_traders FOR DELETE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- admin_trader_positions
DROP POLICY IF EXISTS "Admins can insert positions" ON admin_trader_positions;
CREATE POLICY "Admins can insert positions"
  ON admin_trader_positions FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update positions" ON admin_trader_positions;
CREATE POLICY "Admins can update positions"
  ON admin_trader_positions FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can delete positions" ON admin_trader_positions;
CREATE POLICY "Admins can delete positions"
  ON admin_trader_positions FOR DELETE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- trader_trades
DROP POLICY IF EXISTS "Admins can view all trader trades" ON trader_trades;
CREATE POLICY "Admins can view all trader trades"
  ON trader_trades FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- traders
DROP POLICY IF EXISTS "Admins can insert traders" ON traders;
CREATE POLICY "Admins can insert traders"
  ON traders FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update traders" ON traders;
CREATE POLICY "Admins can update traders"
  ON traders FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can delete traders" ON traders;
CREATE POLICY "Admins can delete traders"
  ON traders FOR DELETE
  TO authenticated
  USING (is_user_admin((select auth.uid())));
