/*
  # Create Featured Traders for Copy Trading

  1. New Tables
    - `traders`
      - `id` (uuid, primary key)
      - `name` (text) - Trader display name
      - `avatar` (text) - Avatar emoji/icon
      - `rank` (integer) - Current rank
      - `total_rank` (integer) - Total possible rank
      - `api_verified` (boolean) - API verification status
      - `pnl_30d` (numeric) - 30-day profit/loss
      - `roi_30d` (numeric) - 30-day ROI percentage
      - `aum` (numeric) - Assets under management
      - `mdd_30d` (numeric) - Maximum drawdown 30 days
      - `sharpe_ratio` (numeric) - Sharpe ratio, nullable
      - `is_featured` (boolean) - Whether trader is featured
      - `followers_count` (integer) - Number of followers
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `traders` table
    - Add policy for public read access
    - Add policy for admin updates (future)

  3. Seed Data
    - Insert featured traders
*/

-- Create traders table
CREATE TABLE IF NOT EXISTS traders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  avatar text NOT NULL DEFAULT '👤',
  rank integer NOT NULL DEFAULT 0,
  total_rank integer NOT NULL DEFAULT 1000,
  api_verified boolean DEFAULT false,
  pnl_30d numeric(20,2) NOT NULL DEFAULT 0,
  roi_30d numeric(10,2) NOT NULL DEFAULT 0,
  aum numeric(20,2) NOT NULL DEFAULT 0,
  mdd_30d numeric(10,2) NOT NULL DEFAULT 0,
  sharpe_ratio numeric(10,2),
  is_featured boolean DEFAULT true,
  followers_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE traders ENABLE ROW LEVEL SECURITY;

-- Policy for public read access
CREATE POLICY "Traders are viewable by everyone"
  ON traders
  FOR SELECT
  TO public
  USING (true);

-- Policy for authenticated users to view
CREATE POLICY "Authenticated users can view traders"
  ON traders
  FOR SELECT
  TO authenticated
  USING (true);

-- Insert featured traders
INSERT INTO traders (name, avatar, rank, total_rank, api_verified, pnl_30d, roi_30d, aum, mdd_30d, sharpe_ratio, is_featured, followers_count)
VALUES
  ('JeromeLoo 老王', '👨‍💼', 300, 300, true, 502837.89, 43.34, 2228069.98, 7.76, 1.13, true, 1247),
  ('Patrick429', '👤', 500, 1000, true, 319194.18, 102.19, 1104677.82, 19.81, 3.71, true, 892),
  ('skythai', '🌟', 241, 400, false, 193898.71, 37.81, 621403.21, 16.89, 0.11, true, 654),
  ('TogetherWin', '🤝', 545, 1000, true, 174683.13, 30.08, 3103011.28, 31.41, 6.21, true, 1521),
  ('c1ultra', '⚡', 100, 400, true, 147101.00, 37.45, 780337.06, 22.67, 2.00, true, 987),
  ('2nd is the biggest loser', '🎲', 752, 1000, false, 137695.25, 37.88, 1901610.71, 52.83, 3.80, true, 445),
  ('vipxmb', '💎', 442, 600, true, 130045.96, 21.22, 855744.78, 15.57, 1.09, true, 723),
  ('Ryan Pro', '🚀', 45, 400, true, 124183.21, 24.83, 639374.49, 20.79, NULL, true, 1098),
  ('Eenis的绝对思', '🎯', 182, 200, false, 111203.71, 52.03, 807704.01, 6.70, 0.76, true, 834),
  ('CryptoMaster88', '🎓', 125, 500, true, 98450.33, 28.92, 945123.45, 12.34, 1.85, true, 1156),
  ('MoonWhale', '🐋', 67, 300, true, 215678.90, 61.45, 1234567.89, 18.23, 4.12, true, 1678),
  ('SatoshiFan', '💰', 399, 800, false, 87234.56, 19.87, 543210.98, 25.67, 1.45, true, 567)
ON CONFLICT DO NOTHING;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_traders_featured ON traders(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_traders_roi ON traders(roi_30d DESC);
CREATE INDEX IF NOT EXISTS idx_traders_pnl ON traders(pnl_30d DESC);
