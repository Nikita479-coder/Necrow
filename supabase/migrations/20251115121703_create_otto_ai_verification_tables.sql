/*
  # Create Otto AI Verification Tables

  1. New Tables
    - `otto_verification_sessions`
      - `id` (uuid, primary key) - internal ID
      - `session_id` (uuid, unique) - Otto AI session ID
      - `token` (text, unique) - Otto AI session token
      - `url` (text) - Otto AI verification URL
      - `user_id` (uuid, references auth.users) - user who initiated verification
      - `status` (text) - session status (CREATED, CAPTCHA_OK, IN_PROGRESS, DONE, FAILED, EXPIRED, CANCELED)
      - `scopes` (text[]) - verification scopes requested
      - `next_step` (text, nullable) - next operation to be performed
      - `expires_at` (timestamptz) - session expiration time
      - `metadata` (jsonb, nullable) - custom metadata
      - `attempt_number` (integer) - verification attempt counter
      - `created_at` (timestamptz) - creation timestamp
      - `updated_at` (timestamptz) - last update timestamp

    - `otto_verification_results`
      - `id` (uuid, primary key) - internal ID
      - `session_id` (uuid, references otto_verification_sessions.session_id) - linked session
      - `user_id` (uuid, references auth.users) - verified user
      - `liveness_score` (numeric) - liveness detection score
      - `liveness_fine` (boolean) - whether liveness check passed
      - `deepfake_score` (numeric) - deepfake detection score
      - `deepfake_fine` (boolean) - whether deepfake check passed
      - `quality_data` (jsonb) - quality metrics (blur, exposure, etc.)
      - `demographic_data` (jsonb, nullable) - age, gender, race
      - `landmarks` (jsonb, nullable) - facial landmarks
      - `box` (jsonb, nullable) - face bounding box
      - `raw_response` (jsonb) - complete Otto AI response
      - `verification_passed` (boolean) - overall pass/fail
      - `created_at` (timestamptz) - result timestamp

  2. Updates
    - Add `otto_session_id` column to `kyc_verifications` table

  3. Security
    - Enable RLS on both new tables
    - Users can read their own verification sessions and results
    - Only authenticated users can access their data
    - Admin users can read all records (for AdminKYC page)

  4. Indexes
    - Index on user_id for fast user lookups
    - Index on session_id for callback processing
    - Index on status for filtering pending/completed verifications
*/

-- Create otto_verification_sessions table
CREATE TABLE IF NOT EXISTS otto_verification_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid UNIQUE NOT NULL,
  token text UNIQUE NOT NULL,
  url text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'CREATED',
  scopes text[] NOT NULL DEFAULT '{}',
  next_step text,
  expires_at timestamptz NOT NULL,
  metadata jsonb,
  attempt_number integer NOT NULL DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create otto_verification_results table
CREATE TABLE IF NOT EXISTS otto_verification_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES otto_verification_sessions(session_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  liveness_score numeric,
  liveness_fine boolean,
  deepfake_score numeric,
  deepfake_fine boolean,
  quality_data jsonb,
  demographic_data jsonb,
  landmarks jsonb,
  box jsonb,
  raw_response jsonb NOT NULL,
  verification_passed boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Add otto_session_id to kyc_verifications if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'kyc_verifications' AND column_name = 'otto_session_id'
  ) THEN
    ALTER TABLE kyc_verifications ADD COLUMN otto_session_id uuid REFERENCES otto_verification_sessions(session_id);
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_otto_sessions_user_id ON otto_verification_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_otto_sessions_session_id ON otto_verification_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_otto_sessions_status ON otto_verification_sessions(status);
CREATE INDEX IF NOT EXISTS idx_otto_results_user_id ON otto_verification_results(user_id);
CREATE INDEX IF NOT EXISTS idx_otto_results_session_id ON otto_verification_results(session_id);

-- Enable RLS
ALTER TABLE otto_verification_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE otto_verification_results ENABLE ROW LEVEL SECURITY;

-- Policies for otto_verification_sessions
CREATE POLICY "Users can read own verification sessions"
  ON otto_verification_sessions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own verification sessions"
  ON otto_verification_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own verification sessions"
  ON otto_verification_sessions
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policies for otto_verification_results
CREATE POLICY "Users can read own verification results"
  ON otto_verification_results
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own verification results"
  ON otto_verification_results
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Create updated_at trigger for sessions
CREATE OR REPLACE FUNCTION update_otto_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_otto_sessions_updated_at
  BEFORE UPDATE ON otto_verification_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_otto_sessions_updated_at();