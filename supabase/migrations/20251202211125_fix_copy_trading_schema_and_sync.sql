/*
  # Fix Copy Trading Schema and Synchronization
  
  ## Changes
  1. Fix field naming inconsistencies (pair vs symbol)
  2. Add proper linking between admin trades and trader_trades
  3. Add source tracking for allocations
  4. Add cumulative PNL tracking to copy_relationships
  
  ## Tables Modified
  - trader_trades: Ensure consistent field names
  - copy_trade_allocations: Add source_type field
  - copy_relationships: Add cumulative PNL tracking
  - admin_trader_positions: Add trader_trade_id for proper linking
*/

-- Add trader_trade_id to admin_trader_positions for proper linking
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'admin_trader_positions' AND column_name = 'trader_trade_id'
  ) THEN
    ALTER TABLE admin_trader_positions ADD COLUMN trader_trade_id uuid REFERENCES trader_trades(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add source_type to copy_trade_allocations to track where the allocation came from
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_trade_allocations' AND column_name = 'source_type'
  ) THEN
    ALTER TABLE copy_trade_allocations ADD COLUMN source_type text DEFAULT 'auto' CHECK (source_type IN ('instant', 'pending_accepted', 'auto'));
  END IF;
END $$;

-- Add cumulative PNL tracking to copy_relationships
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_relationships' AND column_name = 'cumulative_pnl'
  ) THEN
    ALTER TABLE copy_relationships ADD COLUMN cumulative_pnl numeric DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'copy_relationships' AND column_name = 'total_trades_copied'
  ) THEN
    ALTER TABLE copy_relationships ADD COLUMN total_trades_copied integer DEFAULT 0;
  END IF;
END $$;

-- Add symbol field to trader_trades if using 'pair' (ensure consistency)
DO $$
BEGIN
  -- Check if we're using 'pair' field
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trader_trades' AND column_name = 'pair'
  ) THEN
    -- Rename pair to symbol for consistency
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'trader_trades' AND column_name = 'symbol'
    ) THEN
      ALTER TABLE trader_trades RENAME COLUMN pair TO symbol;
    END IF;
  END IF;
END $$;

-- Add margin_used to trader_trades if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'trader_trades' AND column_name = 'margin_used'
  ) THEN
    ALTER TABLE trader_trades ADD COLUMN margin_used numeric DEFAULT 0;
  END IF;
END $$;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_admin_positions_trader_trade ON admin_trader_positions(trader_trade_id);
CREATE INDEX IF NOT EXISTS idx_allocations_source_type ON copy_trade_allocations(source_type);
CREATE INDEX IF NOT EXISTS idx_copy_relationships_trader_active ON copy_relationships(trader_id, is_active) WHERE is_active = true;

-- Update existing allocations to set source_type based on context
UPDATE copy_trade_allocations
SET source_type = 'instant'
WHERE source_type = 'auto'
AND trader_trade_id IN (
  SELECT tt.id 
  FROM trader_trades tt
  INNER JOIN admin_trader_positions atp ON atp.opened_at = tt.opened_at
  WHERE atp.trader_id = tt.trader_id
);
