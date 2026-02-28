/*
  # Create Favorites Table for Copy Trading
  
  1. New Tables
    - `favorites`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `trader_id` (integer, the trader's ID)
      - `created_at` (timestamp)
      
  2. Security
    - Enable RLS on `favorites` table
    - Add policy for users to read their own favorites
    - Add policy for users to insert their own favorites
    - Add policy for users to delete their own favorites
*/

CREATE TABLE IF NOT EXISTS favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trader_id integer NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, trader_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own favorites"
  ON favorites
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites"
  ON favorites
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites"
  ON favorites
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
