/*
  # Giveaway Tickets and Winners Tables

  1. New Tables
    - `giveaway_tickets` - Tracks tickets awarded per deposit
      - `id` (uuid, primary key)
      - `campaign_id` (uuid, references campaigns)
      - `user_id` (uuid, references auth.users)
      - `deposit_payment_id` (uuid, references crypto_deposits.payment_id)
      - `ticket_count` (integer) - Number of tickets from this deposit
      - `deposit_amount` (numeric) - Amount that was deposited
      - `tier_name` (text) - Which tier was applied
      - `guaranteed_bonus_awarded` (numeric) - Any instant bonus given
      - `awarded_at` (timestamptz) - When tickets were awarded
      - `eligible_at` (timestamptz) - When holding period ends
      - `is_eligible` (boolean) - Whether tickets can be used in draw

    - `giveaway_winners` - Records of winners from draws
      - `id` (uuid, primary key)
      - `campaign_id` (uuid, references campaigns)
      - `user_id` (uuid, references auth.users)
      - `prize_id` (uuid, references prizes)
      - `ticket_id` (uuid, references tickets) - Winning ticket
      - `won_at` (timestamptz) - When drawn
      - `credit_status` (text) - pending/credited/failed
      - `credited_at` (timestamptz) - When prize was delivered
      - `credit_details` (jsonb) - Transaction ID, voucher ID, etc.

    - `giveaway_draw_audit` - Full audit trail of draw
      - `id` (uuid, primary key)
      - `campaign_id` (uuid, references campaigns)
      - `prize_id` (uuid, references prizes)
      - `winner_user_id` (uuid)
      - `winning_ticket_id` (uuid)
      - `random_value` (numeric) - The random number used
      - `pool_size` (integer) - Total tickets in pool at draw time
      - `drawn_at` (timestamptz)
      - `drawn_by` (uuid) - Admin who executed

  2. Security
    - Enable RLS on all tables
    - Users can only view their own tickets and wins
    - Admins have full access
*/

-- Giveaway Tickets Table
CREATE TABLE IF NOT EXISTS giveaway_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES giveaway_campaigns(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  deposit_payment_id uuid REFERENCES crypto_deposits(payment_id),
  ticket_count integer NOT NULL DEFAULT 0,
  deposit_amount numeric(20,2) NOT NULL,
  tier_name text,
  guaranteed_bonus_awarded numeric(20,2) DEFAULT 0,
  awarded_at timestamptz DEFAULT now(),
  eligible_at timestamptz NOT NULL,
  is_eligible boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Giveaway Winners Table
CREATE TABLE IF NOT EXISTS giveaway_winners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES giveaway_campaigns(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  prize_id uuid NOT NULL REFERENCES giveaway_prizes(id),
  ticket_id uuid REFERENCES giveaway_tickets(id),
  won_at timestamptz DEFAULT now(),
  credit_status text NOT NULL DEFAULT 'pending' CHECK (credit_status IN ('pending', 'credited', 'failed')),
  credited_at timestamptz,
  credit_details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Giveaway Draw Audit Table
CREATE TABLE IF NOT EXISTS giveaway_draw_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES giveaway_campaigns(id) ON DELETE CASCADE,
  prize_id uuid NOT NULL REFERENCES giveaway_prizes(id),
  prize_name text,
  winner_user_id uuid REFERENCES auth.users(id),
  winning_ticket_id uuid REFERENCES giveaway_tickets(id),
  random_value numeric(20,10),
  pool_size integer,
  cumulative_weight integer,
  drawn_at timestamptz DEFAULT now(),
  drawn_by uuid REFERENCES auth.users(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_giveaway_tickets_campaign ON giveaway_tickets(campaign_id);
CREATE INDEX IF NOT EXISTS idx_giveaway_tickets_user ON giveaway_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_giveaway_tickets_deposit ON giveaway_tickets(deposit_payment_id);
CREATE INDEX IF NOT EXISTS idx_giveaway_tickets_eligible ON giveaway_tickets(campaign_id, is_eligible) WHERE is_eligible = true;
CREATE INDEX IF NOT EXISTS idx_giveaway_tickets_eligibility_date ON giveaway_tickets(eligible_at);

CREATE INDEX IF NOT EXISTS idx_giveaway_winners_campaign ON giveaway_winners(campaign_id);
CREATE INDEX IF NOT EXISTS idx_giveaway_winners_user ON giveaway_winners(user_id);
CREATE INDEX IF NOT EXISTS idx_giveaway_winners_status ON giveaway_winners(credit_status);

CREATE INDEX IF NOT EXISTS idx_giveaway_draw_audit_campaign ON giveaway_draw_audit(campaign_id);

-- Enable RLS
ALTER TABLE giveaway_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE giveaway_winners ENABLE ROW LEVEL SECURITY;
ALTER TABLE giveaway_draw_audit ENABLE ROW LEVEL SECURITY;

-- RLS Policies for giveaway_tickets
CREATE POLICY "Users can view their own tickets"
  ON giveaway_tickets
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all tickets"
  ON giveaway_tickets
  FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

-- RLS Policies for giveaway_winners
CREATE POLICY "Users can view their own wins"
  ON giveaway_winners
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all winners"
  ON giveaway_winners
  FOR ALL
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

-- RLS Policies for giveaway_draw_audit (admin only)
CREATE POLICY "Admins can view draw audit"
  ON giveaway_draw_audit
  FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

CREATE POLICY "Admins can insert draw audit"
  ON giveaway_draw_audit
  FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin(auth.uid()));

-- Function to update ticket eligibility based on holding period
CREATE OR REPLACE FUNCTION update_giveaway_ticket_eligibility()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE giveaway_tickets
  SET is_eligible = true
  WHERE is_eligible = false
    AND eligible_at <= now()
    AND EXISTS (
      SELECT 1 FROM giveaway_campaigns gc
      WHERE gc.id = campaign_id
      AND gc.status = 'active'
    );
END;
$$;

-- Function to get campaign statistics
CREATE OR REPLACE FUNCTION get_giveaway_campaign_stats(p_campaign_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_participants', COUNT(DISTINCT gt.user_id),
    'total_deposits', COUNT(gt.id),
    'total_deposit_amount', COALESCE(SUM(gt.deposit_amount), 0),
    'total_tickets', COALESCE(SUM(gt.ticket_count), 0),
    'eligible_tickets', COALESCE(SUM(CASE WHEN gt.is_eligible THEN gt.ticket_count ELSE 0 END), 0),
    'pending_tickets', COALESCE(SUM(CASE WHEN NOT gt.is_eligible THEN gt.ticket_count ELSE 0 END), 0),
    'guaranteed_bonuses_awarded', COALESCE(SUM(gt.guaranteed_bonus_awarded), 0),
    'prizes_awarded', (SELECT COUNT(*) FROM giveaway_winners WHERE campaign_id = p_campaign_id),
    'prizes_credited', (SELECT COUNT(*) FROM giveaway_winners WHERE campaign_id = p_campaign_id AND credit_status = 'credited')
  )
  INTO v_stats
  FROM giveaway_tickets gt
  WHERE gt.campaign_id = p_campaign_id;

  RETURN v_stats;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_giveaway_ticket_eligibility() TO authenticated;
GRANT EXECUTE ON FUNCTION get_giveaway_campaign_stats(uuid) TO authenticated;
