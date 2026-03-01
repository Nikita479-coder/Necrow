/*
  # Optimize RLS Policies - Batch 2 (Fixed)

  1. Performance Improvements
    - Replace auth.uid() with (select auth.uid()) in RLS policies
    
  2. Tables Fixed
    - wallets
    - orders
    - positions
    - mock_trading_accounts
    - copy_traders
    - fee_vouchers
    - fee_voucher_usage
    - user_fee_rebates
    - favorites
    - futures_margin_wallets
*/

-- wallets
DROP POLICY IF EXISTS "Users can insert own wallets" ON wallets;
CREATE POLICY "Users can insert own wallets"
  ON wallets FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can view all wallets" ON wallets;
CREATE POLICY "Admins can view all wallets"
  ON wallets FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update all wallets" ON wallets;
CREATE POLICY "Admins can update all wallets"
  ON wallets FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can insert any wallet" ON wallets;
CREATE POLICY "Admins can insert any wallet"
  ON wallets FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));

-- orders
DROP POLICY IF EXISTS "Users can insert own orders" ON orders;
CREATE POLICY "Users can insert own orders"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own orders" ON orders;
CREATE POLICY "Users can update own orders"
  ON orders FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own orders" ON orders;
CREATE POLICY "Users can delete own orders"
  ON orders FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));

-- positions
DROP POLICY IF EXISTS "Users can insert own positions" ON positions;
CREATE POLICY "Users can insert own positions"
  ON positions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own positions" ON positions;
CREATE POLICY "Users can update own positions"
  ON positions FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can delete own positions" ON positions;
CREATE POLICY "Users can delete own positions"
  ON positions FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));

-- mock_trading_accounts
DROP POLICY IF EXISTS "Users can read own mock account" ON mock_trading_accounts;
CREATE POLICY "Users can read own mock account"
  ON mock_trading_accounts FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own mock account" ON mock_trading_accounts;
CREATE POLICY "Users can insert own mock account"
  ON mock_trading_accounts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own mock account" ON mock_trading_accounts;
CREATE POLICY "Users can update own mock account"
  ON mock_trading_accounts FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- copy_traders
DROP POLICY IF EXISTS "Traders can update own profile" ON copy_traders;
CREATE POLICY "Traders can update own profile"
  ON copy_traders FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Traders can insert own profile" ON copy_traders;
CREATE POLICY "Traders can insert own profile"
  ON copy_traders FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

-- fee_vouchers
DROP POLICY IF EXISTS "Users can view their own vouchers" ON fee_vouchers;
CREATE POLICY "Users can view their own vouchers"
  ON fee_vouchers FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can manage all vouchers" ON fee_vouchers;
CREATE POLICY "Admins can manage all vouchers"
  ON fee_vouchers FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- fee_voucher_usage
DROP POLICY IF EXISTS "Users can view their own voucher usage" ON fee_voucher_usage;
CREATE POLICY "Users can view their own voucher usage"
  ON fee_voucher_usage FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can manage all voucher usage" ON fee_voucher_usage;
CREATE POLICY "Admins can manage all voucher usage"
  ON fee_voucher_usage FOR ALL
  TO authenticated
  USING (is_user_admin((select auth.uid())));

-- user_fee_rebates
DROP POLICY IF EXISTS "Users can insert own fee rebates" ON user_fee_rebates;
CREATE POLICY "Users can insert own fee rebates"
  ON user_fee_rebates FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own fee rebates" ON user_fee_rebates;
CREATE POLICY "Users can update own fee rebates"
  ON user_fee_rebates FOR UPDATE
  TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- favorites
DROP POLICY IF EXISTS "Users can view own favorites" ON favorites;
CREATE POLICY "Users can view own favorites"
  ON favorites FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can add own favorites" ON favorites;
CREATE POLICY "Users can add own favorites"
  ON favorites FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can remove own favorites" ON favorites;
CREATE POLICY "Users can remove own favorites"
  ON favorites FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));

-- futures_margin_wallets
DROP POLICY IF EXISTS "Users can view own margin wallet" ON futures_margin_wallets;
CREATE POLICY "Users can view own margin wallet"
  ON futures_margin_wallets FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Admins can view all futures wallets" ON futures_margin_wallets;
CREATE POLICY "Admins can view all futures wallets"
  ON futures_margin_wallets FOR SELECT
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can update all futures wallets" ON futures_margin_wallets;
CREATE POLICY "Admins can update all futures wallets"
  ON futures_margin_wallets FOR UPDATE
  TO authenticated
  USING (is_user_admin((select auth.uid())));

DROP POLICY IF EXISTS "Admins can insert any futures wallet" ON futures_margin_wallets;
CREATE POLICY "Admins can insert any futures wallet"
  ON futures_margin_wallets FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin((select auth.uid())));
