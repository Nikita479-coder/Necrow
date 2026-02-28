/*
  # Exclusive VIP Affiliate Program

  ## Overview
  Creates an exclusive multi-level affiliate program for selected users with:
  - 5-level deposit commission: 5%, 4%, 3%, 2%, 1%
  - 5-level trading fee revenue share: 50%, 40%, 30%, 20%, 10%
  - Separate affiliate balance (not main wallet)
  - Withdrawal functionality

  ## New Tables
  1. `exclusive_affiliates` - Users enrolled in the exclusive program
  2. `exclusive_affiliate_balances` - Separate balance for affiliate earnings
  3. `exclusive_affiliate_commissions` - Commission history tracking
  4. `exclusive_affiliate_withdrawals` - Withdrawal requests

  ## Security
  - RLS enabled on all tables
  - Only enrolled users can see their data
  - Admins have full access
*/

-- Exclusive affiliates table - who is enrolled
CREATE TABLE IF NOT EXISTS exclusive_affiliates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  enrolled_by UUID REFERENCES auth.users(id),
  deposit_commission_rates JSONB NOT NULL DEFAULT '{"level_1": 5, "level_2": 4, "level_3": 3, "level_4": 2, "level_5": 1}',
  fee_share_rates JSONB NOT NULL DEFAULT '{"level_1": 50, "level_2": 40, "level_3": 30, "level_4": 20, "level_5": 10}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exclusive_affiliates_user ON exclusive_affiliates(user_id);
CREATE INDEX IF NOT EXISTS idx_exclusive_affiliates_active ON exclusive_affiliates(is_active) WHERE is_active = true;

ALTER TABLE exclusive_affiliates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own exclusive affiliate status"
  ON exclusive_affiliates FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admin full access to exclusive affiliates"
  ON exclusive_affiliates FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Exclusive affiliate balances - separate from main wallet
CREATE TABLE IF NOT EXISTS exclusive_affiliate_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  available_balance NUMERIC NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
  pending_balance NUMERIC NOT NULL DEFAULT 0 CHECK (pending_balance >= 0),
  total_earned NUMERIC NOT NULL DEFAULT 0 CHECK (total_earned >= 0),
  total_withdrawn NUMERIC NOT NULL DEFAULT 0 CHECK (total_withdrawn >= 0),
  deposit_commissions_earned NUMERIC NOT NULL DEFAULT 0 CHECK (deposit_commissions_earned >= 0),
  fee_share_earned NUMERIC NOT NULL DEFAULT 0 CHECK (fee_share_earned >= 0),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exclusive_affiliate_balances_user ON exclusive_affiliate_balances(user_id);

ALTER TABLE exclusive_affiliate_balances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own exclusive affiliate balance"
  ON exclusive_affiliate_balances FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admin full access to exclusive affiliate balances"
  ON exclusive_affiliate_balances FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Exclusive affiliate commissions tracking
CREATE TABLE IF NOT EXISTS exclusive_affiliate_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES auth.users(id),
  source_user_id UUID NOT NULL REFERENCES auth.users(id),
  tier_level INTEGER NOT NULL CHECK (tier_level >= 1 AND tier_level <= 5),
  commission_type TEXT NOT NULL CHECK (commission_type IN ('deposit', 'trading_fee')),
  source_amount NUMERIC NOT NULL CHECK (source_amount >= 0),
  commission_rate NUMERIC NOT NULL CHECK (commission_rate >= 0 AND commission_rate <= 100),
  commission_amount NUMERIC NOT NULL CHECK (commission_amount >= 0),
  reference_id UUID,
  reference_type TEXT,
  status TEXT DEFAULT 'credited' CHECK (status IN ('pending', 'credited', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exclusive_commissions_affiliate ON exclusive_affiliate_commissions(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_exclusive_commissions_source ON exclusive_affiliate_commissions(source_user_id);
CREATE INDEX IF NOT EXISTS idx_exclusive_commissions_type ON exclusive_affiliate_commissions(commission_type);
CREATE INDEX IF NOT EXISTS idx_exclusive_commissions_created ON exclusive_affiliate_commissions(created_at);

ALTER TABLE exclusive_affiliate_commissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own exclusive commissions"
  ON exclusive_affiliate_commissions FOR SELECT TO authenticated
  USING (affiliate_id = auth.uid());

CREATE POLICY "Admin full access to exclusive commissions"
  ON exclusive_affiliate_commissions FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Exclusive affiliate withdrawals
CREATE TABLE IF NOT EXISTS exclusive_affiliate_withdrawals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'USDT',
  wallet_address TEXT NOT NULL,
  network TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'rejected')),
  processed_by UUID REFERENCES auth.users(id),
  processed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exclusive_withdrawals_user ON exclusive_affiliate_withdrawals(user_id);
CREATE INDEX IF NOT EXISTS idx_exclusive_withdrawals_status ON exclusive_affiliate_withdrawals(status);
CREATE INDEX IF NOT EXISTS idx_exclusive_withdrawals_created ON exclusive_affiliate_withdrawals(created_at);

ALTER TABLE exclusive_affiliate_withdrawals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own exclusive withdrawals"
  ON exclusive_affiliate_withdrawals FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can create exclusive withdrawals"
  ON exclusive_affiliate_withdrawals FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admin full access to exclusive withdrawals"
  ON exclusive_affiliate_withdrawals FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Network statistics for exclusive affiliates
CREATE TABLE IF NOT EXISTS exclusive_affiliate_network_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  level_1_count INTEGER DEFAULT 0,
  level_2_count INTEGER DEFAULT 0,
  level_3_count INTEGER DEFAULT 0,
  level_4_count INTEGER DEFAULT 0,
  level_5_count INTEGER DEFAULT 0,
  level_1_earnings NUMERIC DEFAULT 0,
  level_2_earnings NUMERIC DEFAULT 0,
  level_3_earnings NUMERIC DEFAULT 0,
  level_4_earnings NUMERIC DEFAULT 0,
  level_5_earnings NUMERIC DEFAULT 0,
  this_month_earnings NUMERIC DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(affiliate_id)
);

ALTER TABLE exclusive_affiliate_network_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own network stats"
  ON exclusive_affiliate_network_stats FOR SELECT TO authenticated
  USING (affiliate_id = auth.uid());

CREATE POLICY "Admin full access to network stats"
  ON exclusive_affiliate_network_stats FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));
