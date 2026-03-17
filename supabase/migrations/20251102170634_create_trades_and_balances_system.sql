/*
  # Create Trades and Balance Tracking System

  1. New Tables
    - `trader_trades` - Stores all trades made by traders
      - `id` (uuid, primary key)
      - `trader_id` (uuid, references traders)
      - `symbol` (text) - Trading pair (e.g., BTCUSDT)
      - `side` (text) - buy or sell
      - `entry_price` (numeric)
      - `exit_price` (numeric, nullable for open trades)
      - `quantity` (numeric)
      - `leverage` (integer)
      - `pnl` (numeric, nullable)
      - `pnl_percent` (numeric, nullable)
      - `status` (text) - open, closed, liquidated
      - `opened_at` (timestamptz)
      - `closed_at` (timestamptz, nullable)
      - `created_at` (timestamptz)

  2. Changes to Existing Tables
    - Add `initial_balance` to copy_relationships
    - Add `current_balance` to copy_relationships
    - Add `total_pnl` to copy_relationships

  3. Security
    - Enable RLS on trader_trades
    - Public can view trades (for transparency)
    - Only system can insert/update trades
*/

-- Create trader_trades table
CREATE TABLE IF NOT EXISTS trader_trades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trader_id uuid REFERENCES traders(id) ON DELETE CASCADE NOT NULL,
  symbol text NOT NULL,
  side text NOT NULL CHECK (side IN ('buy', 'sell')),
  entry_price numeric NOT NULL,
  exit_price numeric,
  quantity numeric NOT NULL,
  leverage integer DEFAULT 1,
  pnl numeric,
  pnl_percent numeric,
  status text DEFAULT 'open' CHECK (status IN ('open', 'closed', 'liquidated')),
  opened_at timestamptz DEFAULT now(),
  closed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Add balance tracking to copy_relationships
ALTER TABLE copy_relationships
ADD COLUMN IF NOT EXISTS initial_balance numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS current_balance numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_pnl numeric DEFAULT 0;

-- Enable RLS
ALTER TABLE trader_trades ENABLE ROW LEVEL SECURITY;

-- RLS Policies - Anyone can view trades (transparency)
CREATE POLICY "Anyone can view trader trades"
  ON trader_trades FOR SELECT
  TO authenticated
  USING (true);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_trader_trades_trader_id ON trader_trades(trader_id);
CREATE INDEX IF NOT EXISTS idx_trader_trades_status ON trader_trades(status);
CREATE INDEX IF NOT EXISTS idx_trader_trades_closed_at ON trader_trades(closed_at DESC);

-- Function to generate random trades for a trader
CREATE OR REPLACE FUNCTION generate_random_trades(
  p_trader_id uuid,
  p_num_trades integer DEFAULT 20
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_symbols text[] := ARRAY['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT', 'ADAUSDT', 'DOGEUSDT', 'XRPUSDT', 'DOTUSDT', 'MATICUSDT', 'LTCUSDT'];
  v_symbol text;
  v_side text;
  v_entry_price numeric;
  v_exit_price numeric;
  v_quantity numeric;
  v_leverage integer;
  v_pnl numeric;
  v_pnl_percent numeric;
  v_opened_at timestamptz;
  v_closed_at timestamptz;
  v_price_change numeric;
  i integer;
BEGIN
  FOR i IN 1..p_num_trades LOOP
    -- Random symbol
    v_symbol := v_symbols[1 + floor(random() * array_length(v_symbols, 1))::int];
    
    -- Random side
    v_side := CASE WHEN random() > 0.5 THEN 'buy' ELSE 'sell' END;
    
    -- Random entry price based on symbol
    v_entry_price := CASE 
      WHEN v_symbol LIKE 'BTC%' THEN 40000 + (random() * 20000)
      WHEN v_symbol LIKE 'ETH%' THEN 2000 + (random() * 1000)
      WHEN v_symbol LIKE 'BNB%' THEN 300 + (random() * 200)
      WHEN v_symbol LIKE 'SOL%' THEN 80 + (random() * 60)
      ELSE 0.5 + (random() * 2)
    END;
    
    -- Random quantity (smaller amounts)
    v_quantity := 0.001 + (random() * 0.05);
    
    -- Random leverage
    v_leverage := (ARRAY[1, 2, 3, 5, 10])[1 + floor(random() * 5)::int];
    
    -- Random opened time (within last 30 days)
    v_opened_at := now() - (random() * interval '30 days');
    
    -- 80% chance trade is closed
    IF random() < 0.8 THEN
      v_closed_at := v_opened_at + (random() * interval '2 days');
      
      -- Random price change (-10% to +15% for realism)
      v_price_change := -0.10 + (random() * 0.25);
      
      -- Calculate exit price based on side
      IF v_side = 'buy' THEN
        v_exit_price := v_entry_price * (1 + v_price_change);
        v_pnl_percent := v_price_change * 100 * v_leverage;
      ELSE
        v_exit_price := v_entry_price * (1 - v_price_change);
        v_pnl_percent := -v_price_change * 100 * v_leverage;
      END IF;
      
      -- Calculate PNL
      v_pnl := (v_exit_price - v_entry_price) * v_quantity * v_leverage;
      IF v_side = 'sell' THEN
        v_pnl := -v_pnl;
      END IF;
      
      -- Insert closed trade
      INSERT INTO trader_trades (
        trader_id, symbol, side, entry_price, exit_price, 
        quantity, leverage, pnl, pnl_percent, status, 
        opened_at, closed_at
      ) VALUES (
        p_trader_id, v_symbol, v_side, v_entry_price, v_exit_price,
        v_quantity, v_leverage, v_pnl, v_pnl_percent, 'closed',
        v_opened_at, v_closed_at
      );
    ELSE
      -- Insert open trade
      INSERT INTO trader_trades (
        trader_id, symbol, side, entry_price, 
        quantity, leverage, status, opened_at
      ) VALUES (
        p_trader_id, v_symbol, v_side, v_entry_price,
        v_quantity, v_leverage, 'open', v_opened_at
      );
    END IF;
  END LOOP;
END;
$$;

-- Generate trades for all existing traders
DO $$
DECLARE
  trader_record RECORD;
BEGIN
  FOR trader_record IN SELECT id FROM traders LOOP
    PERFORM generate_random_trades(trader_record.id, 25);
  END LOOP;
END $$;