/*
  # Optimize RLS Policies - Part 2 (Trading Tables)

  ## Description
  Continues optimizing RLS policies with auth.uid() wrapper.
*/

-- copy_relationships
DROP POLICY IF EXISTS "Users can read own copy relationships" ON copy_relationships;
CREATE POLICY "Users can read own copy relationships" ON copy_relationships
  FOR SELECT TO authenticated USING (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert copy relationships" ON copy_relationships;
CREATE POLICY "Users can insert copy relationships" ON copy_relationships
  FOR INSERT TO authenticated WITH CHECK (follower_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can update own copy relationships" ON copy_relationships;
CREATE POLICY "Users can update own copy relationships" ON copy_relationships
  FOR UPDATE TO authenticated
  USING (follower_id = (select auth.uid()))
  WITH CHECK (follower_id = (select auth.uid()));

-- kyc_verifications
DROP POLICY IF EXISTS "Users can read own KYC" ON kyc_verifications;
CREATE POLICY "Users can read own KYC" ON kyc_verifications
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own KYC" ON kyc_verifications;
CREATE POLICY "Users can insert own KYC" ON kyc_verifications
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- kyc_documents
DROP POLICY IF EXISTS "Users can view own documents" ON kyc_documents;
CREATE POLICY "Users can view own documents" ON kyc_documents
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert own documents" ON kyc_documents;
CREATE POLICY "Users can insert own documents" ON kyc_documents
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- referral_stats
DROP POLICY IF EXISTS "Users can read own referral stats" ON referral_stats;
CREATE POLICY "Users can read own referral stats" ON referral_stats
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- referral_commissions
DROP POLICY IF EXISTS "Users can read own referral commissions" ON referral_commissions;
CREATE POLICY "Users can read own referral commissions" ON referral_commissions
  FOR SELECT TO authenticated USING (referrer_id = (select auth.uid()));

-- swap_orders
DROP POLICY IF EXISTS "Users can read own swap orders" ON swap_orders;
CREATE POLICY "Users can read own swap orders" ON swap_orders
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS "Users can insert swap orders" ON swap_orders;
CREATE POLICY "Users can insert swap orders" ON swap_orders
  FOR INSERT TO authenticated WITH CHECK (user_id = (select auth.uid()));

-- user_leverage_limits
DROP POLICY IF EXISTS "Users can read own leverage limits" ON user_leverage_limits;
CREATE POLICY "Users can read own leverage limits" ON user_leverage_limits
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- user_fee_rebates
DROP POLICY IF EXISTS "Users can read own fee rebates" ON user_fee_rebates;
CREATE POLICY "Users can read own fee rebates" ON user_fee_rebates
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));

-- crypto_deposits
DROP POLICY IF EXISTS "Users can read own deposits" ON crypto_deposits;
CREATE POLICY "Users can read own deposits" ON crypto_deposits
  FOR SELECT TO authenticated USING (user_id = (select auth.uid()));
