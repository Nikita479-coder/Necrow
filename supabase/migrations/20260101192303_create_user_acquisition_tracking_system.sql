/*
  # User Acquisition Tracking System
  
  Track where users come from (TikTok, Instagram, Facebook, Google, etc.)
  using UTM parameters, referrer data, and landing page information.
  
  1. New Tables
    - `user_acquisition_sources` - Stores acquisition data for each user
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to auth.users)
      - `utm_source` (text) - Traffic source (facebook, tiktok, instagram, google, etc.)
      - `utm_medium` (text) - Marketing medium (cpc, social, email, organic, etc.)
      - `utm_campaign` (text) - Campaign name
      - `utm_content` (text) - Ad content identifier
      - `utm_term` (text) - Paid search keywords
      - `referrer_url` (text) - Full referrer URL
      - `referrer_domain` (text) - Extracted domain from referrer
      - `landing_page` (text) - First page user landed on
      - `device_type` (text) - mobile, tablet, desktop
      - `browser` (text) - Browser name
      - `os` (text) - Operating system
      - `country` (text) - Country from IP
      - `city` (text) - City from IP
      - `ip_address` (text) - User's IP address
      - `created_at` (timestamptz)
      
    - `acquisition_events` - Track important conversion events
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key)
      - `event_type` (text) - signup, first_deposit, first_trade, kyc_completed, etc.
      - `event_data` (jsonb) - Additional event data
      - `created_at` (timestamptz)
      
    - `campaign_tracking_links` - Admin-created tracking links
      - `id` (uuid, primary key)
      - `name` (text) - Link name
      - `utm_source` (text)
      - `utm_medium` (text)
      - `utm_campaign` (text)
      - `utm_content` (text)
      - `utm_term` (text)
      - `short_code` (text, unique) - Short link code
      - `clicks` (integer) - Click count
      - `is_active` (boolean)
      - `created_at` (timestamptz)
      - `created_by` (uuid)
      
  2. Security
    - RLS enabled on all tables
    - Users can only see their own acquisition data
    - Admins can see all data
*/

-- User acquisition sources table
CREATE TABLE IF NOT EXISTS user_acquisition_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  referrer_url text,
  referrer_domain text,
  landing_page text,
  device_type text,
  browser text,
  os text,
  country text,
  city text,
  ip_address text,
  session_id text,
  created_at timestamptz DEFAULT now(),
  
  CONSTRAINT unique_user_acquisition UNIQUE (user_id)
);

-- Acquisition events table
CREATE TABLE IF NOT EXISTS acquisition_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  event_data jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- Campaign tracking links table
CREATE TABLE IF NOT EXISTS campaign_tracking_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  utm_source text NOT NULL,
  utm_medium text,
  utm_campaign text,
  utm_content text,
  utm_term text,
  short_code text UNIQUE NOT NULL,
  destination_url text DEFAULT '/',
  clicks integer DEFAULT 0,
  conversions integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_acquisition_user_id ON user_acquisition_sources(user_id);
CREATE INDEX IF NOT EXISTS idx_acquisition_utm_source ON user_acquisition_sources(utm_source);
CREATE INDEX IF NOT EXISTS idx_acquisition_utm_medium ON user_acquisition_sources(utm_medium);
CREATE INDEX IF NOT EXISTS idx_acquisition_utm_campaign ON user_acquisition_sources(utm_campaign);
CREATE INDEX IF NOT EXISTS idx_acquisition_created_at ON user_acquisition_sources(created_at);
CREATE INDEX IF NOT EXISTS idx_acquisition_referrer_domain ON user_acquisition_sources(referrer_domain);

CREATE INDEX IF NOT EXISTS idx_acquisition_events_user ON acquisition_events(user_id);
CREATE INDEX IF NOT EXISTS idx_acquisition_events_type ON acquisition_events(event_type);
CREATE INDEX IF NOT EXISTS idx_acquisition_events_created ON acquisition_events(created_at);

CREATE INDEX IF NOT EXISTS idx_campaign_links_short_code ON campaign_tracking_links(short_code);
CREATE INDEX IF NOT EXISTS idx_campaign_links_active ON campaign_tracking_links(is_active);

-- Enable RLS
ALTER TABLE user_acquisition_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE acquisition_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_tracking_links ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_acquisition_sources
CREATE POLICY "Users can view own acquisition data"
  ON user_acquisition_sources FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own acquisition data"
  ON user_acquisition_sources FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all acquisition data"
  ON user_acquisition_sources FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- RLS Policies for acquisition_events
CREATE POLICY "Users can view own events"
  ON acquisition_events FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own events"
  ON acquisition_events FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all events"
  ON acquisition_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- RLS Policies for campaign_tracking_links
CREATE POLICY "Anyone can view active campaign links"
  ON campaign_tracking_links FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins can manage campaign links"
  ON campaign_tracking_links FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );
