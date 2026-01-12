/*
  # Admin Managed Trader System

  1. New Tables
    - `admin_managed_traders` - Traders managed directly by admins (no auth account needed)
      - `id` (uuid, primary key)
      - `name` (text) - Display name
      - `avatar` (text) - Emoji avatar
      - `description` (text) - Bio/description
      - `is_active` (boolean) - Whether accepting new copiers
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
    
    - `admin_trader_positions` - Manual positions created by admins
      - `id` (uuid, primary key)
      - `trader_id` (uuid, references admin_managed_traders)
      - `pair` (text) - Trading pair
      - `side` (text) - long or short
      - `entry_price` (numeric)
      - `exit_price` (numeric, nullable)
      - `quantity` (numeric)
      - `leverage` (integer)
      - `margin_used` (numeric)
      - `realized_pnl` (numeric, nullable)
      - `pnl_percentage` (numeric, nullable)
      - `status` (text) - open, closed
      - `opened_at` (timestamptz)
      - `closed_at` (timestamptz, nullable)
      - `notes` (text, nullable) - Admin notes
      - `created_by` (uuid) - Admin who created it
      - `created_at` (timestamptz)

  2. Functions
    - `open_admin_trade()` - Opens a new trade and creates follower allocations
    - `close_admin_trade()` - Closes a trade and distributes P&L

  3. Security
    - Only admins can manage these traders and positions
    - Regular users can view and copy these traders
*/

-- Create admin_managed_traders table
CREATE TABLE IF NOT EXISTS admin_managed_traders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  avatar text DEFAULT '🤖',
  description text,
  is_active boolean DEFAULT true,
  total_followers integer DEFAULT 0,
  total_aum numeric DEFAULT 0,
  win_rate numeric DEFAULT 0,
  total_pnl numeric DEFAULT 0,
  roi_30d numeric DEFAULT 0,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create admin_trader_positions table
CREATE TABLE IF NOT EXISTS admin_trader_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trader_id uuid REFERENCES admin_managed_traders(id) ON DELETE CASCADE NOT NULL,
  pair text NOT NULL,
  side text NOT NULL CHECK (side IN ('long', 'short')),
  entry_price numeric NOT NULL,
  exit_price numeric,
  quantity numeric NOT NULL,
  leverage integer NOT NULL,
  margin_used numeric NOT NULL,
  realized_pnl numeric DEFAULT 0,
  pnl_percentage numeric DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  opened_at timestamptz DEFAULT now() NOT NULL,
  closed_at timestamptz,
  notes text,
  created_by uuid NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_admin_traders_active ON admin_managed_traders(is_active);
CREATE INDEX IF NOT EXISTS idx_admin_positions_trader ON admin_trader_positions(trader_id);
CREATE INDEX IF NOT EXISTS idx_admin_positions_status ON admin_trader_positions(status);

-- Enable RLS
ALTER TABLE admin_managed_traders ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_trader_positions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for admin_managed_traders
CREATE POLICY "Anyone can view active managed traders"
  ON admin_managed_traders FOR SELECT
  TO authenticated
  USING (is_active = true);

CREATE POLICY "Admins can view all managed traders"
  ON admin_managed_traders FOR SELECT
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE POLICY "Admins can insert managed traders"
  ON admin_managed_traders FOR INSERT
  TO authenticated
  WITH CHECK (is_admin(auth.uid()));

CREATE POLICY "Admins can update managed traders"
  ON admin_managed_traders FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE POLICY "Admins can delete managed traders"
  ON admin_managed_traders FOR DELETE
  TO authenticated
  USING (is_admin(auth.uid()));

-- RLS Policies for admin_trader_positions
CREATE POLICY "Anyone can view positions"
  ON admin_trader_positions FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can insert positions"
  ON admin_trader_positions FOR INSERT
  TO authenticated
  WITH CHECK (is_admin(auth.uid()));

CREATE POLICY "Admins can update positions"
  ON admin_trader_positions FOR UPDATE
  TO authenticated
  USING (is_admin(auth.uid()));

CREATE POLICY "Admins can delete positions"
  ON admin_trader_positions FOR DELETE
  TO authenticated
  USING (is_admin(auth.uid()));

-- Function to open an admin trade and create follower allocations
CREATE OR REPLACE FUNCTION open_admin_trade(
  p_trader_id uuid,
  p_pair text,
  p_side text,
  p_entry_price numeric,
  p_quantity numeric,
  p_leverage integer,
  p_margin_used numeric,
  p_notes text,
  p_admin_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position_id uuid;
  v_follower RECORD;
  v_allocated_amount numeric;
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can create trades';
  END IF;

  -- Create the position
  INSERT INTO admin_trader_positions (
    trader_id, pair, side, entry_price, quantity, leverage, margin_used,
    status, notes, created_by, opened_at
  ) VALUES (
    p_trader_id, p_pair, p_side, p_entry_price, p_quantity, p_leverage, p_margin_used,
    'open', p_notes, p_admin_id, NOW()
  ) RETURNING id INTO v_position_id;

  -- Create allocations for all followers of this admin trader
  FOR v_follower IN
    SELECT 
      cr.id as relationship_id,
      cr.follower_id,
      cr.copy_amount,
      cr.leverage as follower_leverage,
      cr.is_mock
    FROM copy_relationships cr
    WHERE cr.trader_id = p_trader_id
    AND cr.status = 'active'
  LOOP
    -- Calculate allocation (proportional to margin used)
    v_allocated_amount := v_follower.copy_amount * (p_margin_used / 1000.0);
    
    IF v_allocated_amount >= 1 THEN
      -- Check follower has sufficient balance
      DECLARE
        v_wallet_type text;
        v_current_balance numeric;
      BEGIN
        v_wallet_type := CASE WHEN v_follower.is_mock THEN 'mock' ELSE 'spot' END;
        
        SELECT balance INTO v_current_balance
        FROM wallets
        WHERE user_id = v_follower.follower_id
        AND currency = 'USDT'
        AND wallet_type = v_wallet_type;
        
        IF v_current_balance IS NOT NULL AND v_current_balance >= v_allocated_amount THEN
          -- Create allocation
          INSERT INTO copy_trade_allocations (
            trader_trade_id, follower_id, copy_relationship_id,
            allocated_amount, follower_leverage, entry_price, status
          ) VALUES (
            v_position_id, v_follower.follower_id, v_follower.relationship_id,
            v_allocated_amount, p_leverage * v_follower.follower_leverage, p_entry_price, 'open'
          );
          
          -- Deduct from wallet
          UPDATE wallets
          SET balance = balance - v_allocated_amount,
              updated_at = NOW()
          WHERE user_id = v_follower.follower_id
          AND currency = 'USDT'
          AND wallet_type = v_wallet_type;
        END IF;
      END;
    END IF;
  END LOOP;

  RETURN v_position_id;
END;
$$;

-- Function to close an admin trade and distribute P&L
CREATE OR REPLACE FUNCTION close_admin_trade(
  p_position_id uuid,
  p_exit_price numeric,
  p_pnl_percentage numeric,
  p_admin_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_position RECORD;
  v_allocation RECORD;
  v_follower_pnl numeric;
  v_return_amount numeric;
  v_wallet_type text;
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Only admins can close trades';
  END IF;

  -- Get position details
  SELECT * INTO v_position
  FROM admin_trader_positions
  WHERE id = p_position_id;

  IF v_position IS NULL THEN
    RAISE EXCEPTION 'Position not found';
  END IF;

  -- Calculate realized PNL
  DECLARE
    v_realized_pnl numeric;
  BEGIN
    v_realized_pnl := v_position.margin_used * (p_pnl_percentage / 100.0);
    
    -- Update position
    UPDATE admin_trader_positions
    SET 
      exit_price = p_exit_price,
      realized_pnl = v_realized_pnl,
      pnl_percentage = p_pnl_percentage,
      status = 'closed',
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = p_position_id;
  END;

  -- Update all follower allocations
  FOR v_allocation IN
    SELECT 
      cta.*,
      cr.is_mock
    FROM copy_trade_allocations cta
    JOIN copy_relationships cr ON cr.id = cta.copy_relationship_id
    WHERE cta.trader_trade_id = p_position_id
    AND cta.status = 'open'
  LOOP
    -- Calculate follower P&L
    v_follower_pnl := v_allocation.allocated_amount * (p_pnl_percentage / 100.0);
    v_return_amount := v_allocation.allocated_amount + v_follower_pnl;
    v_wallet_type := CASE WHEN v_allocation.is_mock THEN 'mock' ELSE 'spot' END;

    -- Update allocation
    UPDATE copy_trade_allocations
    SET 
      exit_price = p_exit_price,
      realized_pnl = v_follower_pnl,
      pnl_percentage = p_pnl_percentage,
      status = 'closed',
      closed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_allocation.id;

    -- Return funds to wallet
    UPDATE wallets
    SET 
      balance = balance + v_return_amount,
      updated_at = NOW()
    WHERE user_id = v_allocation.follower_id
    AND currency = 'USDT'
    AND wallet_type = v_wallet_type;

    -- Record transaction
    INSERT INTO transactions (
      user_id, type, currency, amount, status, description
    ) VALUES (
      v_allocation.follower_id,
      'copy_trade_pnl',
      'USDT',
      v_follower_pnl,
      'completed',
      format('Admin trade P&L: %s %s%%', v_position.pair, ROUND(p_pnl_percentage, 2))
    );
  END LOOP;
END;
$$;
