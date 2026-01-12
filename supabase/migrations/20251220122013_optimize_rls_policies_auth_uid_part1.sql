/*
  # Optimize RLS Policies - Part 1 (Core Tables)

  ## Description
  Optimizes Row Level Security policies by wrapping auth.uid() calls in a subquery.
  This ensures the auth function is evaluated once per query rather than for each row.

  ## Tables Updated
  - user_profiles
  - wallets
  - transactions
  - favorites
  - user_rewards
  - notifications
  - futures_positions
  - futures_orders
  - futures_margin_wallets
*/

-- ============================================
-- user_profiles policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
CREATE POLICY "Users can read own profile" ON user_profiles
  FOR SELECT TO authenticated
  USING (id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
CREATE POLICY "Users can update own profile" ON user_profiles
  FOR UPDATE TO authenticated
  USING (id = (select auth.uid()))
  WITH CHECK (id = (select auth.uid()));

-- ============================================
-- wallets policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own wallets" ON wallets;
CREATE POLICY "Users can read own wallets" ON wallets
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own wallets" ON wallets;
CREATE POLICY "Users can update own wallets" ON wallets
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- transactions policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own transactions" ON transactions;
CREATE POLICY "Users can read own transactions" ON transactions
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own transactions" ON transactions;
CREATE POLICY "Users can insert own transactions" ON transactions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- favorites policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own favorites" ON favorites;
CREATE POLICY "Users can read own favorites" ON favorites
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own favorites" ON favorites;
CREATE POLICY "Users can insert own favorites" ON favorites
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own favorites" ON favorites;
CREATE POLICY "Users can delete own favorites" ON favorites
  FOR DELETE TO authenticated
  USING (user_id = (select auth.uid()));

-- ============================================
-- user_rewards policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own rewards" ON user_rewards;
CREATE POLICY "Users can read own rewards" ON user_rewards
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own rewards" ON user_rewards;
CREATE POLICY "Users can update own rewards" ON user_rewards
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- notifications policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
CREATE POLICY "Users can read own notifications" ON notifications
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications" ON notifications
  FOR DELETE TO authenticated
  USING (user_id = (select auth.uid()));

-- ============================================
-- futures_positions policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own positions" ON futures_positions;
CREATE POLICY "Users can read own positions" ON futures_positions
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own positions" ON futures_positions;
CREATE POLICY "Users can insert own positions" ON futures_positions
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own positions" ON futures_positions;
CREATE POLICY "Users can update own positions" ON futures_positions
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- futures_orders policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own orders" ON futures_orders;
CREATE POLICY "Users can read own orders" ON futures_orders
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own orders" ON futures_orders;
CREATE POLICY "Users can insert own orders" ON futures_orders
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own orders" ON futures_orders;
CREATE POLICY "Users can update own orders" ON futures_orders
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- ============================================
-- futures_margin_wallets policies
-- ============================================
DROP POLICY IF EXISTS "Users can read own margin wallets" ON futures_margin_wallets;
CREATE POLICY "Users can read own margin wallets" ON futures_margin_wallets
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own margin wallets" ON futures_margin_wallets;
CREATE POLICY "Users can update own margin wallets" ON futures_margin_wallets
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));
