/*
  # Create Support Ticket System

  ## Description
  Comprehensive customer support and ticketing system integrated into user profiles.
  Enables users to create and track support tickets with real-time messaging.

  ## New Tables

  ### 1. support_categories
  Predefined ticket categories with SLA settings
  - `id` (uuid, primary key)
  - `name` (text) - Category name
  - `description` (text) - Category description
  - `sla_response_minutes` (integer) - Expected response time
  - `color_code` (text) - UI color for category
  - `is_active` (boolean) - Active status
  - `created_at` (timestamptz)

  ### 2. support_tickets
  Main ticket records
  - `id` (uuid, primary key)
  - `user_id` (uuid) - Ticket creator
  - `subject` (text) - Ticket subject
  - `category_id` (uuid) - Ticket category
  - `priority` (text) - low, medium, high, urgent
  - `status` (text) - open, in_progress, waiting_user, waiting_admin, resolved, closed
  - `assigned_admin_id` (uuid) - Assigned admin
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)
  - `first_response_at` (timestamptz)
  - `resolved_at` (timestamptz)

  ### 3. support_messages
  Messages within tickets
  - `id` (uuid, primary key)
  - `ticket_id` (uuid) - Parent ticket
  - `sender_id` (uuid) - Message sender
  - `sender_type` (text) - user or admin
  - `message` (text) - Message content
  - `is_internal_note` (boolean) - Admin-only notes
  - `created_at` (timestamptz)
  - `read_at` (timestamptz)

  ### 4. support_attachments
  File attachments for messages
  - `id` (uuid, primary key)
  - `message_id` (uuid) - Parent message
  - `file_name` (text) - Original filename
  - `file_url` (text) - Storage URL
  - `file_size` (bigint) - File size in bytes
  - `mime_type` (text) - File MIME type
  - `uploaded_by` (uuid) - Uploader user ID
  - `created_at` (timestamptz)

  ### 5. support_canned_responses
  Predefined admin responses
  - `id` (uuid, primary key)
  - `title` (text) - Response title
  - `content` (text) - Response template
  - `category_id` (uuid) - Related category
  - `created_by_admin_id` (uuid) - Creator admin
  - `usage_count` (integer) - Times used
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Users can view/update only their own tickets
  - Admins have full access
  - Internal notes visible only to admins

  ## Indexes
  - Optimized for ticket listing and filtering
  - Fast message retrieval
*/

-- Support Categories Table
CREATE TABLE IF NOT EXISTS support_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  sla_response_minutes integer NOT NULL DEFAULT 240,
  color_code text NOT NULL DEFAULT '#3b82f6',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Support Tickets Table
CREATE TABLE IF NOT EXISTS support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  subject text NOT NULL,
  category_id uuid REFERENCES support_categories(id),
  priority text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'open',
  assigned_admin_id uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  first_response_at timestamptz,
  resolved_at timestamptz,
  CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  CHECK (status IN ('open', 'in_progress', 'waiting_user', 'waiting_admin', 'resolved', 'closed'))
);

-- Support Messages Table
CREATE TABLE IF NOT EXISTS support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES support_tickets(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  sender_type text NOT NULL,
  message text NOT NULL,
  is_internal_note boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  read_at timestamptz,
  CHECK (sender_type IN ('user', 'admin'))
);

-- Support Attachments Table
CREATE TABLE IF NOT EXISTS support_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES support_messages(id) ON DELETE CASCADE NOT NULL,
  file_name text NOT NULL,
  file_url text NOT NULL,
  file_size bigint NOT NULL,
  mime_type text NOT NULL,
  uploaded_by uuid REFERENCES auth.users(id) NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Support Canned Responses Table
CREATE TABLE IF NOT EXISTS support_canned_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  content text NOT NULL,
  category_id uuid REFERENCES support_categories(id),
  created_by_admin_id uuid REFERENCES auth.users(id) NOT NULL,
  usage_count integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_assigned_admin ON support_tickets(assigned_admin_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created_at ON support_tickets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_messages_ticket_id ON support_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at);

-- Enable RLS
ALTER TABLE support_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_canned_responses ENABLE ROW LEVEL SECURITY;

-- Support Categories Policies (everyone can read active categories)
CREATE POLICY "Anyone can view active support categories"
  ON support_categories FOR SELECT
  TO authenticated
  USING (is_active = true);

CREATE POLICY "Admins can manage support categories"
  ON support_categories FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Support Tickets Policies
CREATE POLICY "Users can view own support tickets"
  ON support_tickets FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid() OR
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Users can create support tickets"
  ON support_tickets FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own support tickets"
  ON support_tickets FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can manage all support tickets"
  ON support_tickets FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Support Messages Policies
CREATE POLICY "Users can view messages from own tickets"
  ON support_messages FOR SELECT
  TO authenticated
  USING (
    (
      ticket_id IN (SELECT id FROM support_tickets WHERE user_id = auth.uid())
      AND is_internal_note = false
    ) OR
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Users can create messages on own tickets"
  ON support_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    ticket_id IN (SELECT id FROM support_tickets WHERE user_id = auth.uid())
    AND sender_id = auth.uid()
    AND is_internal_note = false
  );

CREATE POLICY "Admins can create all messages"
  ON support_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can update messages"
  ON support_messages FOR UPDATE
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Support Attachments Policies
CREATE POLICY "Users can view attachments from own tickets"
  ON support_attachments FOR SELECT
  TO authenticated
  USING (
    message_id IN (
      SELECT m.id FROM support_messages m
      JOIN support_tickets t ON m.ticket_id = t.id
      WHERE t.user_id = auth.uid()
    ) OR
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Users can upload attachments to own tickets"
  ON support_attachments FOR INSERT
  TO authenticated
  WITH CHECK (uploaded_by = auth.uid());

CREATE POLICY "Admins can manage all attachments"
  ON support_attachments FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Canned Responses Policies (admin only)
CREATE POLICY "Admins can view canned responses"
  ON support_canned_responses FOR SELECT
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

CREATE POLICY "Admins can manage canned responses"
  ON support_canned_responses FOR ALL
  TO authenticated
  USING (
    (auth.jwt()->>'is_admin')::boolean = true OR
    (SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true
  );

-- Insert default categories
INSERT INTO support_categories (name, description, sla_response_minutes, color_code) VALUES
  ('Account', 'Account-related issues', 240, '#3b82f6'),
  ('Trading', 'Trading and orders issues', 120, '#10b981'),
  ('Deposit', 'Deposit questions and issues', 180, '#f59e0b'),
  ('Withdrawal', 'Withdrawal requests and issues', 180, '#ef4444'),
  ('KYC', 'KYC verification issues', 480, '#8b5cf6'),
  ('Technical', 'Technical problems and bugs', 120, '#ec4899'),
  ('Other', 'General inquiries', 360, '#6b7280')
ON CONFLICT (name) DO NOTHING;

-- Function to auto-update ticket updated_at
CREATE OR REPLACE FUNCTION update_ticket_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

CREATE TRIGGER update_support_ticket_timestamp
  BEFORE UPDATE ON support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION update_ticket_timestamp();

-- Function to set first_response_at when admin responds
CREATE OR REPLACE FUNCTION set_first_response_time()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.sender_type = 'admin' THEN
    UPDATE support_tickets
    SET first_response_at = COALESCE(first_response_at, now())
    WHERE id = NEW.ticket_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

CREATE TRIGGER set_ticket_first_response
  AFTER INSERT ON support_messages
  FOR EACH ROW
  EXECUTE FUNCTION set_first_response_time();