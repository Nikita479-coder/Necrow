/*
  # Create Email Templates and Logging System

  ## Summary
  Creates a comprehensive email template and logging system for CRM communications.
  Admins can create reusable email templates with variable placeholders and track
  all emails sent to users.

  ## New Tables

  ### 1. email_templates
  Stores reusable email templates with variable support
  - `id` (uuid, primary key)
  - `name` (text, unique) - Template name for admin reference
  - `subject` (text) - Email subject line (supports variables)
  - `body` (text) - Email body HTML/text (supports variables)
  - `category` (text) - Template category (welcome, kyc, bonus, promotion, alert, trading)
  - `variables` (jsonb) - Array of supported variables
  - `is_active` (boolean) - Whether template is active
  - `created_by` (uuid) - Admin who created it
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. email_logs
  Tracks all emails sent to users
  - `id` (uuid, primary key)
  - `user_id` (uuid) - Recipient user
  - `template_id` (uuid) - Template used (nullable if custom)
  - `template_name` (text) - Template name at time of sending
  - `subject` (text) - Actual subject sent
  - `body` (text) - Actual body content sent
  - `status` (text) - sent, failed, pending
  - `error_message` (text) - Error if failed
  - `sent_by` (uuid) - Admin who sent it
  - `sent_at` (timestamptz)
  - `metadata` (jsonb) - Additional data

  ## Security
  - RLS enabled on both tables
  - Only admins can access email templates
  - Only admins can view email logs
  - Audit trail for all email communications

  ## Variables Supported
  User data: {{username}}, {{email}}, {{full_name}}, {{kyc_level}}, {{kyc_status}}
  Financial: {{balance}}, {{bonus_amount}}, {{trading_volume}}
  Platform: {{platform_name}}, {{support_email}}, {{website_url}}
  Dynamic: {{custom_message}}, {{action_url}}, {{expiry_date}}
*/

-- Email Templates Table
CREATE TABLE IF NOT EXISTS email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  category text NOT NULL CHECK (category IN ('welcome', 'kyc', 'bonus', 'promotion', 'alert', 'trading', 'general')),
  variables jsonb DEFAULT '[]'::jsonb,
  is_active boolean DEFAULT true NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Email Logs Table
CREATE TABLE IF NOT EXISTS email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  template_id uuid REFERENCES email_templates(id) ON DELETE SET NULL,
  template_name text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  error_message text,
  sent_by uuid REFERENCES auth.users(id) ON DELETE SET NULL NOT NULL,
  sent_at timestamptz DEFAULT now() NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Policies for email_templates (admin only)
CREATE POLICY "Admins can view all email templates"
  ON email_templates FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can create email templates"
  ON email_templates FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can update email templates"
  ON email_templates FOR UPDATE
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true)
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can delete email templates"
  ON email_templates FOR DELETE
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

-- Policies for email_logs (admin only)
CREATE POLICY "Admins can view all email logs"
  ON email_logs FOR SELECT
  TO authenticated
  USING ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

CREATE POLICY "Admins can insert email logs"
  ON email_logs FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT is_admin FROM user_profiles WHERE id = auth.uid()) = true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_email_templates_category ON email_templates(category);
CREATE INDEX IF NOT EXISTS idx_email_templates_is_active ON email_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_email_logs_user_id ON email_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_email_logs_sent_at ON email_logs(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_logs_status ON email_logs(status);

-- Function to get user email history
CREATE OR REPLACE FUNCTION get_user_email_history(
  p_user_id uuid,
  p_limit integer DEFAULT 10,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  template_name text,
  subject text,
  status text,
  sent_at timestamptz,
  sent_by_username text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    el.id,
    el.template_name,
    el.subject,
    el.status,
    el.sent_at,
    COALESCE(up.username, 'System') as sent_by_username
  FROM email_logs el
  LEFT JOIN user_profiles up ON up.id = el.sent_by
  WHERE el.user_id = p_user_id
  ORDER BY el.sent_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;
