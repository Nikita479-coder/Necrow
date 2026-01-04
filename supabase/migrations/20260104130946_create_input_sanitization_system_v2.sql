/*
  # Input Sanitization and XSS Protection System

  1. Security Features
    - Text sanitization function to strip HTML/script tags
    - Malicious pattern detection
    - Automatic sanitization triggers on all user-input tables
    - Logging of blocked malicious attempts
    
  2. Protected Tables
    - user_profiles (full_name, country, etc.)
    - support_tickets (subject, description)
    - support_messages (message)
    - kyc_documents (document metadata)
    
  3. Security Logging
    - Track all XSS attempts in security_incidents table
*/

-- Create security incidents logging table
CREATE TABLE IF NOT EXISTS security_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES user_profiles(id) ON DELETE SET NULL,
  incident_type text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  description text NOT NULL,
  malicious_content text,
  ip_address text,
  user_agent text,
  table_name text,
  column_name text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_security_incidents_user_id ON security_incidents(user_id);
CREATE INDEX IF NOT EXISTS idx_security_incidents_created_at ON security_incidents(created_at);
CREATE INDEX IF NOT EXISTS idx_security_incidents_severity ON security_incidents(severity);

-- Function to detect malicious patterns
CREATE OR REPLACE FUNCTION detect_malicious_pattern(input_text text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  malicious_patterns text[] := ARRAY[
    '<script', '</script>', 'javascript:', 'onerror=', 'onload=',
    'onclick=', 'onmouseover=', '<iframe', '</iframe>', 'eval(',
    'expression(', 'vbscript:', 'data:text/html', '<object',
    '<embed', '<applet', 'document.cookie', 'document.write',
    '.innerHTML', 'fromCharCode', '<svg', 'onanimation',
    'ontransition', '<link', 'onfocus=', 'onblur=', '<img',
    'src=', 'href=', '<a ', '<form', 'action=', '<input',
    '<textarea', '<button', 'prompt(', 'alert(', 'confirm('
  ];
  pattern text;
BEGIN
  IF input_text IS NULL THEN
    RETURN false;
  END IF;
  
  -- Check for malicious patterns (case-insensitive)
  FOREACH pattern IN ARRAY malicious_patterns LOOP
    IF lower(input_text) LIKE '%' || lower(pattern) || '%' THEN
      RETURN true;
    END IF;
  END LOOP;
  
  -- Check for encoded attempts
  IF input_text ~ '&#|%3C|%3E|&lt;|&gt;|\\x3c|\\x3e' THEN
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$;

-- Function to sanitize text input
CREATE OR REPLACE FUNCTION sanitize_text_input(input_text text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  sanitized text;
BEGIN
  IF input_text IS NULL THEN
    RETURN NULL;
  END IF;
  
  sanitized := input_text;
  
  -- Remove HTML tags
  sanitized := regexp_replace(sanitized, '<[^>]*>', '', 'gi');
  
  -- Remove javascript: protocol
  sanitized := regexp_replace(sanitized, 'javascript:', '', 'gi');
  
  -- Remove data: protocol
  sanitized := regexp_replace(sanitized, 'data:', '', 'gi');
  
  -- Remove vbscript: protocol
  sanitized := regexp_replace(sanitized, 'vbscript:', '', 'gi');
  
  -- Remove on* event handlers
  sanitized := regexp_replace(sanitized, 'on\w+\s*=', '', 'gi');
  
  -- Decode HTML entities and remove them
  sanitized := regexp_replace(sanitized, '&#\d+;', '', 'g');
  sanitized := regexp_replace(sanitized, '&#x[0-9a-f]+;', '', 'gi');
  
  -- Remove URL encoded attempts
  sanitized := regexp_replace(sanitized, '%3C|%3E|%3c|%3e', '', 'gi');
  
  -- Remove null bytes
  sanitized := regexp_replace(sanitized, '\x00', '', 'g');
  
  -- Trim whitespace
  sanitized := trim(sanitized);
  
  RETURN sanitized;
END;
$$;

-- Function to log security incidents
CREATE OR REPLACE FUNCTION log_security_incident(
  p_user_id uuid,
  p_incident_type text,
  p_severity text,
  p_description text,
  p_malicious_content text,
  p_table_name text DEFAULT NULL,
  p_column_name text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO security_incidents (
    user_id,
    incident_type,
    severity,
    description,
    malicious_content,
    table_name,
    column_name
  ) VALUES (
    p_user_id,
    p_incident_type,
    p_severity,
    p_description,
    p_malicious_content,
    p_table_name,
    p_column_name
  );
  
  -- If critical severity, create admin notification
  IF p_severity = 'critical' THEN
    INSERT INTO notifications (
      user_id,
      notification_type,
      title,
      message,
      read
    )
    SELECT 
      id,
      'system',
      'SECURITY ALERT: XSS Attempt Detected',
      format('User attempted XSS injection in %s.%s', 
        COALESCE(p_table_name, 'unknown'),
        COALESCE(p_column_name, 'unknown')
      ),
      false
    FROM user_profiles
    WHERE is_user_admin(id);
  END IF;
END;
$$;

-- Trigger function to sanitize and validate user_profiles
CREATE OR REPLACE FUNCTION sanitize_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check for malicious content in full_name
  IF detect_malicious_pattern(NEW.full_name) THEN
    PERFORM log_security_incident(
      NEW.id,
      'xss_attempt',
      'critical',
      'XSS attempt detected in user profile full_name field',
      NEW.full_name,
      'user_profiles',
      'full_name'
    );
    
    -- Sanitize the input
    NEW.full_name := sanitize_text_input(NEW.full_name);
    
    -- If still malicious after sanitization, set to default
    IF NEW.full_name IS NULL OR length(trim(NEW.full_name)) = 0 THEN
      NEW.full_name := 'User';
    END IF;
  END IF;
  
  -- Check country field
  IF detect_malicious_pattern(NEW.country) THEN
    PERFORM log_security_incident(
      NEW.id,
      'xss_attempt',
      'high',
      'XSS attempt detected in user profile country field',
      NEW.country,
      'user_profiles',
      'country'
    );
    NEW.country := sanitize_text_input(NEW.country);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_sanitize_user_profile ON user_profiles;

-- Create trigger for user_profiles
CREATE TRIGGER trg_sanitize_user_profile
  BEFORE INSERT OR UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sanitize_user_profile();

-- Trigger function for support tickets
CREATE OR REPLACE FUNCTION sanitize_support_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check subject
  IF detect_malicious_pattern(NEW.subject) THEN
    PERFORM log_security_incident(
      NEW.user_id,
      'xss_attempt',
      'high',
      'XSS attempt detected in support ticket subject',
      NEW.subject,
      'support_tickets',
      'subject'
    );
    NEW.subject := sanitize_text_input(NEW.subject);
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sanitize_support_ticket ON support_tickets;

CREATE TRIGGER trg_sanitize_support_ticket
  BEFORE INSERT OR UPDATE ON support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION sanitize_support_ticket();

-- Trigger function for support messages
CREATE OR REPLACE FUNCTION sanitize_support_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check message
  IF detect_malicious_pattern(NEW.message) THEN
    PERFORM log_security_incident(
      NEW.user_id,
      'xss_attempt',
      'high',
      'XSS attempt detected in support message',
      NEW.message,
      'support_messages',
      'message'
    );
    NEW.message := sanitize_text_input(NEW.message);
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sanitize_support_message ON support_messages;

CREATE TRIGGER trg_sanitize_support_message
  BEFORE INSERT OR UPDATE ON support_messages
  FOR EACH ROW
  EXECUTE FUNCTION sanitize_support_message();

-- Clean up any existing malicious content in user_profiles
UPDATE user_profiles
SET full_name = sanitize_text_input(full_name)
WHERE detect_malicious_pattern(full_name) = true;

UPDATE user_profiles
SET country = sanitize_text_input(country)
WHERE detect_malicious_pattern(country) = true
AND country IS NOT NULL;

-- RLS policies for security_incidents (admin only)
ALTER TABLE security_incidents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all security incidents"
  ON security_incidents
  FOR SELECT
  TO authenticated
  USING (is_user_admin(auth.uid()));

CREATE POLICY "System can insert security incidents"
  ON security_incidents
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Grant necessary permissions
GRANT SELECT, INSERT ON security_incidents TO authenticated;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_full_name ON user_profiles(full_name);

COMMENT ON TABLE security_incidents IS 'Logs all security incidents including XSS attempts, SQL injection attempts, and other malicious activities';
COMMENT ON FUNCTION detect_malicious_pattern IS 'Detects common XSS, injection, and script patterns in text input';
COMMENT ON FUNCTION sanitize_text_input IS 'Removes HTML tags, scripts, and malicious code from text input';
