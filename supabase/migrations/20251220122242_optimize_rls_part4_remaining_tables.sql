/*
  # Optimize RLS Policies - Part 4 (Remaining Tables)

  ## Description
  Final batch of RLS policy optimizations with auth.uid() wrapper.
*/

-- wallet_addresses
DROP POLICY IF EXISTS "Users can read own wallet addresses" ON wallet_addresses;
CREATE POLICY "Users can read own wallet addresses" ON wallet_addresses
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert wallet addresses" ON wallet_addresses;
CREATE POLICY "Users can insert wallet addresses" ON wallet_addresses
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- positions
DROP POLICY IF EXISTS "Users can read own positions" ON positions;
CREATE POLICY "Users can read own positions" ON positions
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- orders
DROP POLICY IF EXISTS "Users can read own orders" ON orders;
CREATE POLICY "Users can read own orders" ON orders
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- trades
DROP POLICY IF EXISTS "Users can read own trades" ON trades;
CREATE POLICY "Users can read own trades" ON trades
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- stake_rewards
DROP POLICY IF EXISTS "Users can read own stake rewards" ON stake_rewards;
CREATE POLICY "Users can read own stake rewards" ON stake_rewards
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM user_stakes
    WHERE user_stakes.id = stake_rewards.stake_id
    AND user_stakes.user_id = (select auth.uid())
  ));

-- funding_payments
DROP POLICY IF EXISTS "Users can read own funding payments" ON funding_payments;
CREATE POLICY "Users can read own funding payments" ON funding_payments
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- fee_collections (user can see fees they paid)
DROP POLICY IF EXISTS "Users can read own fees" ON fee_collections;
CREATE POLICY "Users can read own fees" ON fee_collections
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- liquidation_events
DROP POLICY IF EXISTS "Users can read own liquidation events" ON liquidation_events;
CREATE POLICY "Users can read own liquidation events" ON liquidation_events
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- telegram_verifications
DROP POLICY IF EXISTS "Users can read own telegram verification" ON telegram_verifications;
CREATE POLICY "Users can read own telegram verification" ON telegram_verifications
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- telegram_linking_codes
DROP POLICY IF EXISTS "Users can read own telegram linking codes" ON telegram_linking_codes;
CREATE POLICY "Users can read own telegram linking codes" ON telegram_linking_codes
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert telegram linking codes" ON telegram_linking_codes;
CREATE POLICY "Users can insert telegram linking codes" ON telegram_linking_codes
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- ip_verification_codes
DROP POLICY IF EXISTS "Users can read own ip verification codes" ON ip_verification_codes;
CREATE POLICY "Users can read own ip verification codes" ON ip_verification_codes
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- login_verification_codes
DROP POLICY IF EXISTS "Users can read own login codes" ON login_verification_codes;
CREATE POLICY "Users can read own login codes" ON login_verification_codes
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- mock_trading_accounts
DROP POLICY IF EXISTS "Users can read own mock accounts" ON mock_trading_accounts;
CREATE POLICY "Users can read own mock accounts" ON mock_trading_accounts
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert mock accounts" ON mock_trading_accounts;
CREATE POLICY "Users can insert mock accounts" ON mock_trading_accounts
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own mock accounts" ON mock_trading_accounts;
CREATE POLICY "Users can update own mock accounts" ON mock_trading_accounts
  FOR UPDATE TO authenticated
  USING (user_id = (select auth.uid()))
  WITH CHECK (user_id = (select auth.uid()));

-- user_risk_flags
DROP POLICY IF EXISTS "Users can read own risk flags" ON user_risk_flags;
CREATE POLICY "Users can read own risk flags" ON user_risk_flags
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- copy_trading_stats (for followers)
DROP POLICY IF EXISTS "Users can read own copy stats" ON copy_trading_stats;
CREATE POLICY "Users can read own copy stats" ON copy_trading_stats
  FOR SELECT TO authenticated USING (follower_id = (select auth.uid()));
