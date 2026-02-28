/*
  # Add Dynamic Trade-Driven Metrics Columns to Traders Table

  1. New Columns
    - `starting_capital` (numeric) - Baseline AUM for ROI calculations (default: 10000000)
    - `metrics_last_updated` (timestamptz) - Timestamp of last metric calculation
    - `protected_trader` (boolean) - Flag to identify special traders like "Satoshi Academy" who should maintain positive performance
    - `linked_admin_trader_id` (uuid) - Link to admin_managed_traders if this is a managed trader

  2. Purpose
    - Enable dynamic calculation of metrics based on actual trade data
    - Track when metrics were last recalculated
    - Protect specific traders from showing negative performance
    - Link regular traders to their admin counterparts for synchronization

  3. Notes
    - Starting capital represents the initial AUM baseline for ROI calculations
    - Protected traders will have their metrics capped at 0 minimum (no negative values)
    - Metrics will be recalculated automatically when trades close
*/

-- Add new columns to traders table
ALTER TABLE traders ADD COLUMN IF NOT EXISTS starting_capital numeric DEFAULT 10000000;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS metrics_last_updated timestamptz;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS protected_trader boolean DEFAULT false;
ALTER TABLE traders ADD COLUMN IF NOT EXISTS linked_admin_trader_id uuid REFERENCES admin_managed_traders(id) ON DELETE SET NULL;

-- Create index for faster protected trader queries
CREATE INDEX IF NOT EXISTS idx_traders_protected ON traders(protected_trader) WHERE protected_trader = true;

-- Create index for metrics update timestamp
CREATE INDEX IF NOT EXISTS idx_traders_metrics_updated ON traders(metrics_last_updated);

-- Create index for linked admin traders
CREATE INDEX IF NOT EXISTS idx_traders_linked_admin ON traders(linked_admin_trader_id) WHERE linked_admin_trader_id IS NOT NULL;
