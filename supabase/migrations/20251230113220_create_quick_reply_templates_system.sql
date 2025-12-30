/*
  # Create Quick Reply Templates System

  1. New Tables
    - `quick_reply_templates`
      - `id` (uuid, primary key)
      - `command` (text) - The slash command trigger (e.g., "/hello")
      - `label` (text) - Short description shown in dropdown
      - `message` (text) - The actual template message
      - `template_type` (text) - Either 'admin' or 'user'
      - `is_active` (boolean) - Whether template is currently active
      - `sort_order` (integer) - Display order
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
      - `created_by` (uuid) - Admin who created the template

  2. Security
    - Enable RLS
    - Admins can manage all templates
    - Users can only read active user templates

  3. Initial Data
    - Seed with existing hardcoded templates
*/

-- Create quick_reply_templates table
CREATE TABLE IF NOT EXISTS quick_reply_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  command text NOT NULL,
  label text NOT NULL,
  message text NOT NULL,
  template_type text NOT NULL CHECK (template_type IN ('admin', 'user')),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

-- Create unique constraint on command + template_type
CREATE UNIQUE INDEX IF NOT EXISTS idx_quick_reply_templates_command_type 
  ON quick_reply_templates(command, template_type);

-- Create index for active templates lookup
CREATE INDEX IF NOT EXISTS idx_quick_reply_templates_active 
  ON quick_reply_templates(template_type, is_active) WHERE is_active = true;

-- Enable RLS
ALTER TABLE quick_reply_templates ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can do everything
CREATE POLICY "Admins can manage quick reply templates"
  ON quick_reply_templates
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Policy: Users can read active user templates
CREATE POLICY "Users can read active user templates"
  ON quick_reply_templates
  FOR SELECT
  TO authenticated
  USING (template_type = 'user' AND is_active = true);

-- Insert default user templates
INSERT INTO quick_reply_templates (command, label, message, template_type, sort_order) VALUES
('/hello', 'Greeting', 'Hello! I need assistance with my account.', 'user', 1),
('/deposit', 'Deposit Issue', 'I have a question about my recent deposit. The transaction ID is: [Please provide transaction ID]', 'user', 2),
('/withdraw', 'Withdrawal Issue', 'I need help with my withdrawal request. The amount is: [Please specify amount]', 'user', 3),
('/kyc', 'KYC Question', 'I have a question about the KYC verification process.', 'user', 4),
('/trading', 'Trading Issue', 'I''m experiencing an issue with trading: [Please describe the issue]', 'user', 5),
('/account', 'Account Issue', 'I need help with my account settings or security.', 'user', 6)
ON CONFLICT (command, template_type) DO NOTHING;

-- Insert default admin templates
INSERT INTO quick_reply_templates (command, label, message, template_type, sort_order) VALUES
('/hello', 'Greeting', 'Hello! Thank you for contacting SharkFund support. How can I assist you today?', 'admin', 1),
('/processing', 'Processing', 'Thank you for your patience. Your request is currently being processed and should be completed within 24-48 hours.', 'admin', 2),
('/deposit-confirm', 'Deposit Confirmed', 'Great news! Your deposit has been confirmed and credited to your account. You can now see the updated balance in your wallet.', 'admin', 3),
('/withdraw-processing', 'Withdrawal Processing', 'Your withdrawal request has been approved and is now being processed. Please allow 1-3 business days for the funds to arrive in your account.', 'admin', 4),
('/kyc-approved', 'KYC Approved', 'Congratulations! Your KYC verification has been approved. You now have full access to all platform features.', 'admin', 5),
('/kyc-docs', 'KYC Documents Needed', 'To complete your verification, please submit the following documents:\n1. Government-issued ID (passport, driver''s license, or national ID)\n2. Proof of address (utility bill or bank statement, less than 3 months old)\n3. A selfie holding your ID', 'admin', 6),
('/resolved', 'Issue Resolved', 'I''m glad I could help resolve this issue for you. Is there anything else you need assistance with?', 'admin', 7),
('/escalate', 'Escalating', 'I understand this is important to you. I''m escalating this to our senior support team who will review your case and get back to you within 24 hours.', 'admin', 8),
('/thanks', 'Thank You', 'Thank you for contacting SharkFund support. If you have any other questions in the future, don''t hesitate to reach out. Have a great day!', 'admin', 9)
ON CONFLICT (command, template_type) DO NOTHING;

-- Create function to get templates by type
CREATE OR REPLACE FUNCTION get_quick_reply_templates(p_template_type text)
RETURNS TABLE (
  id uuid,
  command text,
  label text,
  message text,
  sort_order integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    qrt.id,
    qrt.command,
    qrt.label,
    qrt.message,
    qrt.sort_order
  FROM quick_reply_templates qrt
  WHERE qrt.template_type = p_template_type
    AND qrt.is_active = true
  ORDER BY qrt.sort_order, qrt.created_at;
END;
$$;
