/*
  # Fix Favorites Table trader_id Type

  1. Changes
    - Drop existing favorites table
    - Recreate with correct trader_id type (uuid instead of integer)
    - Add proper foreign key constraint to traders table
    - Maintain RLS policies

  2. Security
    - Enable RLS
    - Users can only manage their own favorites
*/

-- Drop existing favorites table
DROP TABLE IF EXISTS favorites CASCADE;

-- Recreate favorites table with correct types
CREATE TABLE favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trader_id uuid REFERENCES traders(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, trader_id)
);

-- Enable RLS
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own favorites"
  ON favorites FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can add own favorites"
  ON favorites FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can remove own favorites"
  ON favorites FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Create index for faster lookups
CREATE INDEX idx_favorites_user_id ON favorites(user_id);
CREATE INDEX idx_favorites_trader_id ON favorites(trader_id);