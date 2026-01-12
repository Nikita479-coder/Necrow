/*
  # Giveaway Campaign System - Core Tables

  1. New Tables
    - `giveaway_campaigns` - Main campaign configuration
      - `id` (uuid, primary key)
      - `name` (text) - Campaign display name
      - `description` (text) - Marketing description
      - `start_date` (timestamptz) - When deposits start counting
      - `end_date` (timestamptz) - When deposits stop counting
      - `draw_date` (timestamptz) - When the draw will occur
      - `status` (text) - draft/active/drawing/completed/cancelled
      - `holding_period_days` (integer) - Days deposits must be held
      - `rules_json` (jsonb) - Additional configuration
      - `total_prize_value` (numeric) - Calculated total prize pool
      - `created_by` (uuid) - Admin who created
      - `created_at`, `updated_at` (timestamptz)

    - `giveaway_ticket_tiers` - Deposit amount to ticket conversion
      - `id` (uuid, primary key)
      - `campaign_id` (uuid, references campaigns)
      - `tier_name` (text) - Bronze/Silver/Gold/Platinum
      - `min_deposit` (numeric) - Minimum deposit for this tier
      - `max_deposit` (numeric) - Maximum deposit for this tier (null = no max)
      - `base_tickets` (integer) - Base tickets awarded
      - `bonus_percentage` (numeric) - Extra tickets as percentage
      - `guaranteed_bonus_amount` (numeric) - Instant bonus for this tier
      - `sort_order` (integer) - Display ordering

    - `giveaway_prizes` - Prize pool configuration
      - `id` (uuid, primary key)
      - `campaign_id` (uuid, references campaigns)
      - `name` (text) - Prize display name
      - `prize_type` (text) - cash/fee_voucher
      - `prize_category` (text) - grand/major/mass
      - `amount` (numeric) - Prize value
      - `quantity` (integer) - Total available
      - `remaining_quantity` (integer) - Not yet awarded
      - `sort_order` (integer) - Draw order (grand first)

  2. Security
    - Enable RLS on all tables
    - Admin write access via is_user_admin() check
    - Authenticated users can read active campaigns
*/

-- Giveaway Campaigns Table
CREATE TABLE IF NOT EXISTS giveaway_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  draw_date timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'drawing', 'completed', 'cancelled')),
  holding_period_days integer NOT NULL DEFAULT 7,
  rules_json jsonb DEFAULT '{}'::jsonb,
  total_prize_value numeric(20,2) DEFAULT 0,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Giveaway Ticket Tiers Table
CREATE TABLE IF NOT EXISTS giveaway_ticket_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES giveaway_campaigns(id) ON DELETE CASCADE,
  tier_name text NOT NULL,
  min_deposit numeric(20,2) NOT NULL,
  max_deposit numeric(20,2),
  base_tickets integer NOT NULL DEFAULT 10,
  bonus_percentage numeric(5,2) DEFAULT 0,
  guaranteed_bonus_amount numeric(20,2) DEFAULT 0,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Giveaway Prizes Table
CREATE TABLE IF NOT EXISTS giveaway_prizes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES giveaway_campaigns(id) ON DELETE CASCADE,
  name text NOT NULL,
  prize_type text NOT NULL CHECK (prize_type IN ('cash', 'fee_voucher')),
  prize_category text NOT NULL CHECK (prize_category IN ('grand', 'major', 'mass')),
  amount numeric(20,2) NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  remaining_quantity integer NOT NULL DEFAULT 1,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_giveaway_campaigns_status ON giveaway_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_giveaway_campaigns_dates ON giveaway_campaigns(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_giveaway_ticket_tiers_campaign ON giveaway_ticket_tiers(campaign_id);
CREATE INDEX IF NOT EXISTS idx_giveaway_prizes_campaign ON giveaway_prizes(campaign_id);
CREATE INDEX IF NOT EXISTS idx_giveaway_prizes_category ON giveaway_prizes(prize_category, sort_order);

-- Enable RLS
ALTER TABLE giveaway_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE giveaway_ticket_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE giveaway_prizes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for giveaway_campaigns
CREATE POLICY "Admins can manage giveaway campaigns"
  ON giveaway_campaigns
  FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

CREATE POLICY "Users can view active and completed campaigns"
  ON giveaway_campaigns
  FOR SELECT
  TO authenticated
  USING (status IN ('active', 'completed'));

-- RLS Policies for giveaway_ticket_tiers
CREATE POLICY "Admins can manage ticket tiers"
  ON giveaway_ticket_tiers
  FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

CREATE POLICY "Users can view ticket tiers for active campaigns"
  ON giveaway_ticket_tiers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM giveaway_campaigns gc
      WHERE gc.id = campaign_id
      AND gc.status IN ('active', 'completed')
    )
  );

-- RLS Policies for giveaway_prizes
CREATE POLICY "Admins can manage prizes"
  ON giveaway_prizes
  FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

CREATE POLICY "Users can view prizes for active campaigns"
  ON giveaway_prizes
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM giveaway_campaigns gc
      WHERE gc.id = campaign_id
      AND gc.status IN ('active', 'completed')
    )
  );

-- Function to update campaign updated_at timestamp
CREATE OR REPLACE FUNCTION update_giveaway_campaign_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS trigger_update_giveaway_campaign_timestamp ON giveaway_campaigns;
CREATE TRIGGER trigger_update_giveaway_campaign_timestamp
  BEFORE UPDATE ON giveaway_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_giveaway_campaign_timestamp();

-- Function to calculate and update total prize value
CREATE OR REPLACE FUNCTION update_campaign_prize_value()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total numeric(20,2);
BEGIN
  SELECT COALESCE(SUM(amount * quantity), 0)
  INTO v_total
  FROM giveaway_prizes
  WHERE campaign_id = COALESCE(NEW.campaign_id, OLD.campaign_id);

  UPDATE giveaway_campaigns
  SET total_prize_value = v_total
  WHERE id = COALESCE(NEW.campaign_id, OLD.campaign_id);

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Trigger to update prize value when prizes change
DROP TRIGGER IF EXISTS trigger_update_prize_value ON giveaway_prizes;
CREATE TRIGGER trigger_update_prize_value
  AFTER INSERT OR UPDATE OR DELETE ON giveaway_prizes
  FOR EACH ROW
  EXECUTE FUNCTION update_campaign_prize_value();
