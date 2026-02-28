/*
  # Pending Copy Trades System - Trader-Initiated with 10-Minute Acceptance Window

  ## Overview
  Creates a consent-based copy trading system where:
  - Traders post trade proposals
  - Followers receive notifications
  - Followers have 10 minutes to accept or decline
  - Risk acknowledgment required for acceptance

  ## Tables Created
  1. `pending_copy_trades` - Trader-initiated trades awaiting follower responses
  2. `copy_trade_responses` - Individual follower responses to pending trades
  3. `copy_trade_notifications` - Real-time notification tracking

  ## Key Features
  - 10-minute expiration window
  - Risk acknowledgment requirement
  - Real-time notifications
  - Response tracking and analytics

  ## Security
  - RLS enabled on all tables
  - Users can only view relevant trades
  - Proper authentication checks
*/

-- Add new columns to copy_relationships
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_relationships' AND column_name = 'require_approval'
  ) THEN
    ALTER TABLE copy_relationships ADD COLUMN require_approval boolean DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_relationships' AND column_name = 'notification_enabled'
  ) THEN
    ALTER TABLE copy_relationships ADD COLUMN notification_enabled boolean DEFAULT true;
  END IF;
END $$;

-- Create pending_copy_trades table
CREATE TABLE IF NOT EXISTS pending_copy_trades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trader_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

  -- Trade details
  pair text NOT NULL,
  side text NOT NULL CHECK (side IN ('long', 'short')),
  entry_price numeric NOT NULL CHECK (entry_price > 0),
  quantity numeric NOT NULL CHECK (quantity > 0),
  leverage integer NOT NULL CHECK (leverage >= 1 AND leverage <= 125),
  margin_used numeric NOT NULL CHECK (margin_used > 0),

  -- Trade metadata
  notes text,
  trader_balance numeric DEFAULT 0,

  -- Status and timing
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'expired', 'executed', 'cancelled')),
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  executed_at timestamptz,

  -- Stats
  total_followers_notified integer DEFAULT 0,
  total_accepted integer DEFAULT 0,
  total_declined integer DEFAULT 0,
  total_expired integer DEFAULT 0
);

-- Create copy_trade_responses table
CREATE TABLE IF NOT EXISTS copy_trade_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pending_trade_id uuid NOT NULL REFERENCES pending_copy_trades(id) ON DELETE CASCADE,
  follower_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  copy_relationship_id uuid NOT NULL REFERENCES copy_relationships(id) ON DELETE CASCADE,

  -- Response details
  response text NOT NULL CHECK (response IN ('accepted', 'declined', 'expired')),
  decline_reason text,
  risk_acknowledged boolean DEFAULT false,

  -- Allocation (if accepted)
  allocated_amount numeric DEFAULT 0,
  follower_leverage integer,

  -- Timestamps
  created_at timestamptz DEFAULT now() NOT NULL,
  responded_at timestamptz,

  -- Constraints
  UNIQUE(pending_trade_id, follower_id)
);

-- Create copy_trade_notifications table
CREATE TABLE IF NOT EXISTS copy_trade_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  pending_trade_id uuid NOT NULL REFERENCES pending_copy_trades(id) ON DELETE CASCADE,

  -- Notification details
  notification_status text NOT NULL DEFAULT 'unread' CHECK (notification_status IN ('unread', 'read', 'responded')),
  notification_type text DEFAULT 'pending_trade',

  -- Timestamps
  created_at timestamptz DEFAULT now() NOT NULL,
  read_at timestamptz,
  responded_at timestamptz,

  -- Constraints
  UNIQUE(follower_id, pending_trade_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_pending_trades_trader ON pending_copy_trades(trader_id);
CREATE INDEX IF NOT EXISTS idx_pending_trades_status ON pending_copy_trades(status);
CREATE INDEX IF NOT EXISTS idx_pending_trades_expires ON pending_copy_trades(expires_at);
CREATE INDEX IF NOT EXISTS idx_pending_trades_created ON pending_copy_trades(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_trade_responses_pending ON copy_trade_responses(pending_trade_id);
CREATE INDEX IF NOT EXISTS idx_trade_responses_follower ON copy_trade_responses(follower_id);
CREATE INDEX IF NOT EXISTS idx_trade_responses_response ON copy_trade_responses(response);

CREATE INDEX IF NOT EXISTS idx_notifications_follower ON copy_trade_notifications(follower_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON copy_trade_notifications(notification_status);
CREATE INDEX IF NOT EXISTS idx_notifications_pending ON copy_trade_notifications(pending_trade_id);

-- Enable RLS
ALTER TABLE pending_copy_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_trade_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_trade_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for pending_copy_trades

-- Traders can view their own pending trades
CREATE POLICY "Traders can view own pending trades"
  ON pending_copy_trades FOR SELECT
  TO authenticated
  USING (trader_id = auth.uid());

-- Followers can view pending trades from traders they follow
CREATE POLICY "Followers can view pending trades from followed traders"
  ON pending_copy_trades FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM copy_relationships cr
      WHERE cr.follower_id = auth.uid()
      AND cr.trader_id = pending_copy_trades.trader_id
      AND cr.status = 'active'
      AND cr.is_active = true
    )
  );

-- Only traders can insert their own trades
CREATE POLICY "Traders can create pending trades"
  ON pending_copy_trades FOR INSERT
  TO authenticated
  WITH CHECK (trader_id = auth.uid());

-- System can update trade status
CREATE POLICY "System can update pending trades"
  ON pending_copy_trades FOR UPDATE
  TO authenticated
  USING (true);

-- Admins can view all pending trades
CREATE POLICY "Admins can view all pending trades"
  ON pending_copy_trades FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));

-- RLS Policies for copy_trade_responses

-- Followers can view their own responses
CREATE POLICY "Followers can view own responses"
  ON copy_trade_responses FOR SELECT
  TO authenticated
  USING (follower_id = auth.uid());

-- Traders can view responses to their trades
CREATE POLICY "Traders can view responses to their trades"
  ON copy_trade_responses FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM pending_copy_trades pct
      WHERE pct.id = copy_trade_responses.pending_trade_id
      AND pct.trader_id = auth.uid()
    )
  );

-- Followers can insert their own responses
CREATE POLICY "Followers can create responses"
  ON copy_trade_responses FOR INSERT
  TO authenticated
  WITH CHECK (follower_id = auth.uid());

-- System can update responses
CREATE POLICY "System can update responses"
  ON copy_trade_responses FOR UPDATE
  TO authenticated
  USING (true);

-- Admins can view all responses
CREATE POLICY "Admins can view all responses"
  ON copy_trade_responses FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));

-- RLS Policies for copy_trade_notifications

-- Users can view their own notifications
CREATE POLICY "Users can view own notifications"
  ON copy_trade_notifications FOR SELECT
  TO authenticated
  USING (follower_id = auth.uid());

-- System can insert notifications
CREATE POLICY "System can insert notifications"
  ON copy_trade_notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Users can update their own notifications
CREATE POLICY "Users can update own notifications"
  ON copy_trade_notifications FOR UPDATE
  TO authenticated
  USING (follower_id = auth.uid());

-- Users can delete their own notifications
CREATE POLICY "Users can delete own notifications"
  ON copy_trade_notifications FOR DELETE
  TO authenticated
  USING (follower_id = auth.uid());

-- Admins can view all notifications
CREATE POLICY "Admins can view all notifications"
  ON copy_trade_notifications FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));
