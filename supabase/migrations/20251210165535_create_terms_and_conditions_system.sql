/*
  # Terms and Conditions System

  1. New Tables
    - `terms_and_conditions`
      - `id` (uuid, primary key)
      - `version` (text, semantic version)
      - `title` (text)
      - `content` (text, full T&C content)
      - `effective_date` (timestamp)
      - `is_active` (boolean)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `user_terms_acceptance`
      - `id` (uuid, primary key)
      - `user_id` (uuid, references auth.users)
      - `terms_id` (uuid, references terms_and_conditions)
      - `version` (text)
      - `accepted_at` (timestamp)
      - `ip_address` (text)
      - `user_agent` (text)
  
  2. Security
    - Enable RLS on all tables
    - Users can view active terms
    - Users can record their own acceptance
    - Admins can manage terms
*/

-- Terms and Conditions table
CREATE TABLE IF NOT EXISTS terms_and_conditions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version text NOT NULL UNIQUE,
  title text NOT NULL,
  content text NOT NULL,
  effective_date timestamptz NOT NULL DEFAULT now(),
  is_active boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- User acceptance tracking
CREATE TABLE IF NOT EXISTS user_terms_acceptance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  terms_id uuid REFERENCES terms_and_conditions(id) ON DELETE CASCADE NOT NULL,
  version text NOT NULL,
  accepted_at timestamptz DEFAULT now(),
  ip_address text,
  user_agent text,
  UNIQUE(user_id, terms_id)
);

-- Enable RLS
ALTER TABLE terms_and_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_terms_acceptance ENABLE ROW LEVEL SECURITY;

-- RLS Policies for terms_and_conditions
CREATE POLICY "Anyone can view active terms"
  ON terms_and_conditions FOR SELECT
  TO authenticated
  USING (is_active = true);

CREATE POLICY "Admins can view all terms"
  ON terms_and_conditions FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

CREATE POLICY "Admins can insert terms"
  ON terms_and_conditions FOR INSERT
  TO authenticated
  WITH CHECK (is_user_admin(auth.uid()));

CREATE POLICY "Admins can update terms"
  ON terms_and_conditions FOR UPDATE
  TO authenticated
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

-- RLS Policies for user_terms_acceptance
CREATE POLICY "Users can view own acceptances"
  ON user_terms_acceptance FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can record own acceptance"
  ON user_terms_acceptance FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all acceptances"
  ON user_terms_acceptance FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_terms_version ON terms_and_conditions(version);
CREATE INDEX IF NOT EXISTS idx_terms_active ON terms_and_conditions(is_active);
CREATE INDEX IF NOT EXISTS idx_user_terms_user_id ON user_terms_acceptance(user_id);
CREATE INDEX IF NOT EXISTS idx_user_terms_terms_id ON user_terms_acceptance(terms_id);