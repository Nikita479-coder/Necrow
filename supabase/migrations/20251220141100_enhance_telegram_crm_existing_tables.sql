/*
  # Enhance Telegram CRM Tables

  Extends existing telegram tables with additional CRM features:
  - Bot configuration table (new)
  - Enhanced templates with parse_mode and use_count
  - Enhanced scheduled messages with priority and max_attempts
  - Helper functions for scheduling and processing
*/

-- Bot configuration table (new)
CREATE TABLE IF NOT EXISTS telegram_bot_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  bot_token text NOT NULL,
  bot_username text,
  channel_username text NOT NULL DEFAULT '@oldregular',
  channel_chat_id bigint,
  is_active boolean DEFAULT true,
  last_verified_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(created_by)
);

-- Add missing columns to telegram_templates if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'telegram_templates' AND column_name = 'parse_mode') THEN
    ALTER TABLE telegram_templates ADD COLUMN parse_mode text DEFAULT 'HTML';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'telegram_templates' AND column_name = 'use_count') THEN
    ALTER TABLE telegram_templates ADD COLUMN use_count integer DEFAULT 0;
  END IF;
END $$;

-- Add missing columns to telegram_scheduled_messages if not exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'telegram_scheduled_messages' AND column_name = 'priority') THEN
    ALTER TABLE telegram_scheduled_messages ADD COLUMN priority integer DEFAULT 5;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'telegram_scheduled_messages' AND column_name = 'max_attempts') THEN
    ALTER TABLE telegram_scheduled_messages ADD COLUMN max_attempts integer DEFAULT 3;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'telegram_scheduled_messages' AND column_name = 'parse_mode') THEN
    ALTER TABLE telegram_scheduled_messages ADD COLUMN parse_mode text DEFAULT 'HTML';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'telegram_scheduled_messages' AND column_name = 'disable_notification') THEN
    ALTER TABLE telegram_scheduled_messages ADD COLUMN disable_notification boolean DEFAULT false;
  END IF;
END $$;

-- Enable RLS on bot config
ALTER TABLE telegram_bot_config ENABLE ROW LEVEL SECURITY;

-- RLS Policy for bot config
DO $$ BEGIN
  DROP POLICY IF EXISTS "Admins can manage bot config" ON telegram_bot_config;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

CREATE POLICY "Admins can manage bot config"
  ON telegram_bot_config FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
      AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.id = auth.uid()
      AND up.is_admin = true
    )
  );

-- Function to render template with variables
CREATE OR REPLACE FUNCTION render_telegram_template(
  p_template_id uuid,
  p_variables jsonb DEFAULT '{}'::jsonb
)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  v_content text;
  v_key text;
  v_value text;
BEGIN
  SELECT content INTO v_content FROM telegram_templates WHERE id = p_template_id;
  
  IF v_content IS NULL THEN
    RETURN NULL;
  END IF;
  
  FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_variables) LOOP
    v_content := replace(v_content, '{{' || v_key || '}}', v_value);
  END LOOP;
  
  RETURN v_content;
END;
$$;

-- Function to schedule a message
CREATE OR REPLACE FUNCTION schedule_telegram_message(
  p_created_by uuid,
  p_template_id uuid,
  p_variables jsonb DEFAULT '{}'::jsonb,
  p_scheduled_for timestamptz DEFAULT now(),
  p_channel_username text DEFAULT '@oldregular',
  p_priority integer DEFAULT 5
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_content text;
  v_parse_mode text;
  v_message_id uuid;
BEGIN
  SELECT content, COALESCE(parse_mode, 'HTML') INTO v_content, v_parse_mode
  FROM telegram_templates WHERE id = p_template_id AND is_active = true;
  
  IF v_content IS NULL THEN
    RAISE EXCEPTION 'Template not found or inactive';
  END IF;
  
  v_content := render_telegram_template(p_template_id, p_variables);
  
  INSERT INTO telegram_scheduled_messages (
    created_by, template_id, final_content, channel_username, 
    scheduled_for, priority, parse_mode, status
  ) VALUES (
    p_created_by, p_template_id, v_content, p_channel_username,
    p_scheduled_for, p_priority, v_parse_mode, 'pending'
  )
  RETURNING id INTO v_message_id;
  
  UPDATE telegram_templates SET use_count = COALESCE(use_count, 0) + 1 WHERE id = p_template_id;
  
  INSERT INTO telegram_message_logs (created_by, scheduled_message_id, action, details)
  VALUES (p_created_by, v_message_id, 'scheduled', jsonb_build_object(
    'template_id', p_template_id,
    'scheduled_for', p_scheduled_for,
    'channel', p_channel_username
  ));
  
  RETURN v_message_id;
END;
$$;

-- Function to get pending messages for processing
CREATE OR REPLACE FUNCTION get_pending_telegram_messages(p_limit integer DEFAULT 10)
RETURNS TABLE (
  message_id uuid,
  msg_user_id uuid,
  msg_content text,
  msg_channel text,
  msg_parse_mode text,
  msg_disable_notification boolean,
  msg_bot_token text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.id AS message_id,
    m.created_by AS msg_user_id,
    m.final_content AS msg_content,
    m.channel_username AS msg_channel,
    COALESCE(m.parse_mode, 'HTML') AS msg_parse_mode,
    COALESCE(m.disable_notification, false) AS msg_disable_notification,
    b.bot_token AS msg_bot_token
  FROM telegram_scheduled_messages m
  JOIN telegram_bot_config b ON b.created_by = m.created_by AND b.is_active = true
  WHERE m.status = 'pending'
    AND m.scheduled_for <= now()
    AND m.attempts < COALESCE(m.max_attempts, 3)
  ORDER BY COALESCE(m.priority, 5) ASC, m.scheduled_for ASC
  LIMIT p_limit;
END;
$$;

-- Function to mark message as processing
CREATE OR REPLACE FUNCTION mark_telegram_message_processing(p_message_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  UPDATE telegram_scheduled_messages
  SET status = 'processing', 
      attempts = COALESCE(attempts, 0) + 1,
      last_attempt = now(),
      updated_at = now()
  WHERE id = p_message_id AND status IN ('pending', 'failed');
  
  RETURN FOUND;
END;
$$;

-- Function to mark message as sent
CREATE OR REPLACE FUNCTION mark_telegram_message_sent(
  p_message_id uuid,
  p_telegram_message_id text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  UPDATE telegram_scheduled_messages
  SET status = 'sent',
      sent_at = now(),
      message_id = p_telegram_message_id,
      error_message = NULL,
      updated_at = now()
  WHERE id = p_message_id
  RETURNING created_by INTO v_user_id;
  
  IF FOUND THEN
    INSERT INTO telegram_message_logs (created_by, scheduled_message_id, action, details)
    VALUES (v_user_id, p_message_id, 'sent', jsonb_build_object(
      'telegram_message_id', p_telegram_message_id
    ));
  END IF;
  
  RETURN FOUND;
END;
$$;

-- Function to mark message as failed
CREATE OR REPLACE FUNCTION mark_telegram_message_failed(
  p_message_id uuid,
  p_error text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid;
  v_attempts integer;
  v_max_attempts integer;
  v_new_status text;
BEGIN
  SELECT COALESCE(attempts, 0), COALESCE(max_attempts, 3), created_by 
  INTO v_attempts, v_max_attempts, v_user_id
  FROM telegram_scheduled_messages WHERE id = p_message_id;
  
  IF v_attempts >= v_max_attempts THEN
    v_new_status := 'failed';
  ELSE
    v_new_status := 'pending';
  END IF;
  
  UPDATE telegram_scheduled_messages
  SET status = v_new_status,
      error_message = p_error,
      updated_at = now()
  WHERE id = p_message_id;
  
  IF FOUND THEN
    INSERT INTO telegram_message_logs (created_by, scheduled_message_id, action, details)
    VALUES (v_user_id, p_message_id, 'failed', jsonb_build_object(
      'error', p_error,
      'attempt', v_attempts,
      'will_retry', v_new_status = 'pending'
    ));
  END IF;
  
  RETURN FOUND;
END;
$$;

-- Function to get CRM stats
CREATE OR REPLACE FUNCTION get_telegram_crm_stats(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_stats jsonb;
BEGIN
  SELECT jsonb_build_object(
    'total_templates', (SELECT count(*) FROM telegram_templates WHERE created_by = p_user_id),
    'active_templates', (SELECT count(*) FROM telegram_templates WHERE created_by = p_user_id AND is_active = true),
    'pending_messages', (SELECT count(*) FROM telegram_scheduled_messages WHERE created_by = p_user_id AND status = 'pending'),
    'processing_messages', (SELECT count(*) FROM telegram_scheduled_messages WHERE created_by = p_user_id AND status = 'processing'),
    'sent_today', (SELECT count(*) FROM telegram_scheduled_messages WHERE created_by = p_user_id AND status = 'sent' AND sent_at >= CURRENT_DATE),
    'sent_this_week', (SELECT count(*) FROM telegram_scheduled_messages WHERE created_by = p_user_id AND status = 'sent' AND sent_at >= CURRENT_DATE - INTERVAL '7 days'),
    'sent_this_month', (SELECT count(*) FROM telegram_scheduled_messages WHERE created_by = p_user_id AND status = 'sent' AND sent_at >= CURRENT_DATE - INTERVAL '30 days'),
    'failed_messages', (SELECT count(*) FROM telegram_scheduled_messages WHERE created_by = p_user_id AND status = 'failed'),
    'bot_configured', (SELECT EXISTS(SELECT 1 FROM telegram_bot_config WHERE created_by = p_user_id AND is_active = true))
  ) INTO v_stats;
  
  RETURN v_stats;
END;
$$;