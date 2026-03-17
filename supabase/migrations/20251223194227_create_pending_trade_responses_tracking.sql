/*
  # Create Pending Trade Responses Tracking

  1. New Table
    - `pending_trade_responses`
      - Tracks which users have responded to which pending trades
      - Prevents showing same trade multiple times after response
  
  2. Changes
    - Create table to track user responses
    - Add RLS policies
    - Update respond_to_copy_trade to insert response record

  3. Security
    - Users can only view their own responses
*/

-- Create table to track responses
CREATE TABLE IF NOT EXISTS pending_trade_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pending_trade_id uuid NOT NULL REFERENCES pending_copy_trades(id) ON DELETE CASCADE,
  follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  response text NOT NULL CHECK (response IN ('accepted', 'declined')),
  decline_reason text,
  responded_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE(pending_trade_id, follower_id)
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_pending_trade_responses_follower 
  ON pending_trade_responses(follower_id, responded_at DESC);
CREATE INDEX IF NOT EXISTS idx_pending_trade_responses_trade 
  ON pending_trade_responses(pending_trade_id);

-- Enable RLS
ALTER TABLE pending_trade_responses ENABLE ROW LEVEL SECURITY;

-- Users can view their own responses
CREATE POLICY "Users can view own responses"
  ON pending_trade_responses
  FOR SELECT
  TO authenticated
  USING (follower_id = auth.uid());

-- Function can insert responses
CREATE POLICY "Function can insert responses"
  ON pending_trade_responses
  FOR INSERT
  TO authenticated
  WITH CHECK (follower_id = auth.uid());
