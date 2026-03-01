/*
  # Multi-Tier Affiliate Program System

  ## Overview
  Creates a comprehensive 5-tier affiliate system with:
  - Multi-tier referral tracking (5 levels deep)
  - Hybrid compensation (CPA + Rev-Share + Auto-Optimize)
  - Affiliate tier relationships
  - Override commission tracking
  - Lifetime commission support

  ## New Tables
  1. `affiliate_tiers` - Tracks affiliate relationships across 5 tiers
  2. `affiliate_compensation_plans` - User's selected compensation plan
  3. `tier_commissions` - Override commission payouts by tier
  4. `cpa_payouts` - CPA (Cost Per Acquisition) reward tracking
  5. `affiliate_settings` - Global affiliate program settings

  ## Security
  - RLS enabled on all tables
  - Users can only see their own affiliate data
  - Admins have full access
*/

-- Affiliate tier relationships table (tracks the full chain)
CREATE TABLE IF NOT EXISTS affiliate_tiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referral_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tier_level INTEGER NOT NULL CHECK (tier_level >= 1 AND tier_level <= 5),
  direct_referrer_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(affiliate_id, referral_id)
);

CREATE INDEX IF NOT EXISTS idx_affiliate_tiers_affiliate ON affiliate_tiers(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_tiers_referral ON affiliate_tiers(referral_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_tiers_tier_level ON affiliate_tiers(tier_level);

ALTER TABLE affiliate_tiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their affiliate tiers"
  ON affiliate_tiers FOR SELECT TO authenticated
  USING (affiliate_id = auth.uid());

CREATE POLICY "Admin full access to affiliate tiers"
  ON affiliate_tiers FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Compensation plans table
CREATE TABLE IF NOT EXISTS affiliate_compensation_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  plan_type TEXT NOT NULL DEFAULT 'revshare' CHECK (plan_type IN ('revshare', 'cpa', 'hybrid', 'auto_optimize')),
  hybrid_revshare_rate NUMERIC DEFAULT 0 CHECK (hybrid_revshare_rate >= 0 AND hybrid_revshare_rate <= 100),
  is_auto_optimized BOOLEAN DEFAULT false,
  last_optimization_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE affiliate_compensation_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own compensation plan"
  ON affiliate_compensation_plans FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own compensation plan"
  ON affiliate_compensation_plans FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admin full access to compensation plans"
  ON affiliate_compensation_plans FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Tier commissions tracking
CREATE TABLE IF NOT EXISTS tier_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES auth.users(id),
  source_user_id UUID NOT NULL REFERENCES auth.users(id),
  tier_level INTEGER NOT NULL CHECK (tier_level >= 1 AND tier_level <= 5),
  trade_id UUID,
  trade_amount NUMERIC NOT NULL CHECK (trade_amount >= 0),
  fee_amount NUMERIC NOT NULL CHECK (fee_amount >= 0),
  source_commission NUMERIC NOT NULL CHECK (source_commission >= 0),
  override_rate NUMERIC NOT NULL CHECK (override_rate >= 0 AND override_rate <= 1),
  commission_amount NUMERIC NOT NULL CHECK (commission_amount >= 0),
  affiliate_vip_level INTEGER NOT NULL DEFAULT 1,
  source_vip_level INTEGER NOT NULL DEFAULT 1,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tier_commissions_affiliate ON tier_commissions(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_tier_commissions_source ON tier_commissions(source_user_id);
CREATE INDEX IF NOT EXISTS idx_tier_commissions_created ON tier_commissions(created_at);
CREATE INDEX IF NOT EXISTS idx_tier_commissions_tier ON tier_commissions(tier_level);

ALTER TABLE tier_commissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own tier commissions"
  ON tier_commissions FOR SELECT TO authenticated
  USING (affiliate_id = auth.uid());

CREATE POLICY "Admin full access to tier commissions"
  ON tier_commissions FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- CPA payouts tracking
CREATE TABLE IF NOT EXISTS cpa_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  affiliate_id UUID NOT NULL REFERENCES auth.users(id),
  referred_user_id UUID NOT NULL REFERENCES auth.users(id) UNIQUE,
  cpa_amount NUMERIC NOT NULL CHECK (cpa_amount > 0),
  qualification_type TEXT NOT NULL CHECK (qualification_type IN ('signup', 'kyc_verified', 'first_deposit', 'first_trade', 'volume_threshold')),
  qualification_met_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'qualified', 'paid', 'cancelled')),
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpa_payouts_affiliate ON cpa_payouts(affiliate_id);
CREATE INDEX IF NOT EXISTS idx_cpa_payouts_status ON cpa_payouts(status);

ALTER TABLE cpa_payouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own CPA payouts"
  ON cpa_payouts FOR SELECT TO authenticated
  USING (affiliate_id = auth.uid());

CREATE POLICY "Admin full access to CPA payouts"
  ON cpa_payouts FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Affiliate program settings
CREATE TABLE IF NOT EXISTS affiliate_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key TEXT NOT NULL UNIQUE,
  setting_value JSONB NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES auth.users(id),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE affiliate_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read affiliate settings"
  ON affiliate_settings FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Admin can manage affiliate settings"
  ON affiliate_settings FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true));

-- Insert default affiliate settings
INSERT INTO affiliate_settings (setting_key, setting_value, description) VALUES
  ('tier_override_rates', '{"tier_1": 1.0, "tier_2": 0.20, "tier_3": 0.10, "tier_4": 0.05, "tier_5": 0.02}', 'Override commission rates by tier (percentage of Tier-1 commission)'),
  ('cpa_amounts', '{"signup": 0, "kyc_verified": 10, "first_deposit": 25, "first_trade": 50, "volume_threshold": 100}', 'CPA payout amounts by qualification type'),
  ('cpa_volume_threshold', '10000', 'Trading volume threshold for CPA qualification'),
  ('hybrid_revshare_rates', '{"default": 25, "max": 40}', 'Rev-share rates for hybrid plan'),
  ('min_withdrawal', '10', 'Minimum withdrawal threshold in USDT'),
  ('payout_schedule', '"weekly"', 'Commission payout schedule'),
  ('payout_assets', '["USDT", "USDC", "BTC", "ETH"]', 'Available payout assets'),
  ('max_tier_depth', '5', 'Maximum affiliate tier depth')
ON CONFLICT (setting_key) DO NOTHING;

-- Add affiliate-specific columns to referral_stats
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_2_referrals INTEGER DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_3_referrals INTEGER DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_4_referrals INTEGER DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_5_referrals INTEGER DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_2_earnings NUMERIC DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_3_earnings NUMERIC DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_4_earnings NUMERIC DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS tier_5_earnings NUMERIC DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS lifetime_earnings NUMERIC DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS cpa_earnings NUMERIC DEFAULT 0;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS last_payout_at TIMESTAMPTZ;
ALTER TABLE referral_stats ADD COLUMN IF NOT EXISTS pending_payout NUMERIC DEFAULT 0;

-- Create affiliate stats summary view
CREATE OR REPLACE VIEW affiliate_stats_summary AS
SELECT 
  rs.user_id,
  rs.vip_level,
  rs.total_referrals as tier_1_referrals,
  COALESCE(rs.tier_2_referrals, 0) as tier_2_referrals,
  COALESCE(rs.tier_3_referrals, 0) as tier_3_referrals,
  COALESCE(rs.tier_4_referrals, 0) as tier_4_referrals,
  COALESCE(rs.tier_5_referrals, 0) as tier_5_referrals,
  (rs.total_referrals + COALESCE(rs.tier_2_referrals, 0) + COALESCE(rs.tier_3_referrals, 0) + COALESCE(rs.tier_4_referrals, 0) + COALESCE(rs.tier_5_referrals, 0)) as total_network_size,
  rs.total_earnings as tier_1_earnings,
  COALESCE(rs.tier_2_earnings, 0) as tier_2_earnings,
  COALESCE(rs.tier_3_earnings, 0) as tier_3_earnings,
  COALESCE(rs.tier_4_earnings, 0) as tier_4_earnings,
  COALESCE(rs.tier_5_earnings, 0) as tier_5_earnings,
  COALESCE(rs.lifetime_earnings, 0) as lifetime_earnings,
  COALESCE(rs.cpa_earnings, 0) as cpa_earnings,
  rs.this_month_earnings,
  COALESCE(rs.pending_payout, 0) as pending_payout,
  rs.total_volume_30d,
  rs.total_volume_all_time,
  vl.commission_rate,
  vl.rebate_rate,
  COALESCE(acp.plan_type, 'revshare') as compensation_plan
FROM referral_stats rs
LEFT JOIN vip_levels vl ON vl.level_number = rs.vip_level
LEFT JOIN affiliate_compensation_plans acp ON acp.user_id = rs.user_id;
