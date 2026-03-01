/*
  # Create Events and Terms System

  ## Summary
  Creates a comprehensive system for managing promotional events and terms pages
  that are referenced in email templates.

  ## New Tables
  
  1. `promotional_events`
     - Stores information about trading events and challenges
     - Includes full rules, requirements, and prize details
  
  2. `terms_pages`
     - Stores terms and conditions for various promotions
     - Supports dynamic content generation
  
  ## Security
  - Public read access for all events and terms
  - Admin-only write access
  - RLS policies for data protection
*/

-- Create promotional_events table
CREATE TABLE IF NOT EXISTS promotional_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  title text NOT NULL,
  subtitle text,
  description text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('challenge', 'competition', 'leaderboard', 'lottery', 'skill_test')),
  start_date timestamptz,
  end_date timestamptz,
  prize_pool numeric(20, 2),
  requirements jsonb DEFAULT '{}'::jsonb,
  rules jsonb DEFAULT '[]'::jsonb,
  prizes jsonb DEFAULT '[]'::jsonb,
  disqualifications jsonb DEFAULT '[]'::jsonb,
  how_to_participate jsonb DEFAULT '[]'::jsonb,
  is_active boolean DEFAULT true,
  is_recurring boolean DEFAULT false,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create terms_pages table
CREATE TABLE IF NOT EXISTS terms_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  title text NOT NULL,
  content text NOT NULL,
  category text NOT NULL CHECK (category IN ('challenge', 'event', 'promotion', 'general', 'legal')),
  related_event_id uuid REFERENCES promotional_events(id) ON DELETE SET NULL,
  version integer DEFAULT 1,
  is_active boolean DEFAULT true,
  effective_date timestamptz DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_events_slug ON promotional_events(slug);
CREATE INDEX IF NOT EXISTS idx_events_active ON promotional_events(is_active);
CREATE INDEX IF NOT EXISTS idx_events_dates ON promotional_events(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_terms_slug ON terms_pages(slug);
CREATE INDEX IF NOT EXISTS idx_terms_category ON terms_pages(category);

-- Enable RLS
ALTER TABLE promotional_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE terms_pages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for promotional_events
CREATE POLICY "Anyone can view active events"
  ON promotional_events
  FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage events"
  ON promotional_events
  FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true')
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- RLS Policies for terms_pages
CREATE POLICY "Anyone can view active terms"
  ON terms_pages
  FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage terms"
  ON terms_pages
  FOR ALL
  TO authenticated
  USING ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true')
  WITH CHECK ((auth.jwt()->>'app_metadata')::jsonb->>'is_admin' = 'true');

-- Create update trigger
CREATE OR REPLACE FUNCTION update_events_terms_updated_at()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_promotional_events_updated_at
  BEFORE UPDATE ON promotional_events
  FOR EACH ROW
  EXECUTE FUNCTION update_events_terms_updated_at();

CREATE TRIGGER update_terms_pages_updated_at
  BEFORE UPDATE ON terms_pages
  FOR EACH ROW
  EXECUTE FUNCTION update_events_terms_updated_at();
