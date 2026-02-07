/*
  # Single Active Support Ticket Constraint

  1. New Functions
    - `user_has_active_ticket(p_user_id uuid)` - Returns true if user has any ticket
      that is not resolved or closed

  2. Triggers
    - `check_single_active_ticket_trigger` - Prevents users from creating multiple
      active tickets simultaneously

  3. Security
    - Users can only have one active support ticket at a time
    - Active tickets are defined as any status except 'resolved' or 'closed'
    - This prevents ticket spam and ensures focused support conversations
*/

CREATE OR REPLACE FUNCTION user_has_active_ticket(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM support_tickets
    WHERE user_id = p_user_id
    AND status NOT IN ('resolved', 'closed')
  );
END;
$$;

CREATE OR REPLACE FUNCTION check_single_active_ticket()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF user_has_active_ticket(NEW.user_id) THEN
    RAISE EXCEPTION 'You already have an active support ticket. Please wait for it to be resolved before creating a new one.';
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS check_single_active_ticket_trigger ON support_tickets;

CREATE TRIGGER check_single_active_ticket_trigger
  BEFORE INSERT ON support_tickets
  FOR EACH ROW
  EXECUTE FUNCTION check_single_active_ticket();