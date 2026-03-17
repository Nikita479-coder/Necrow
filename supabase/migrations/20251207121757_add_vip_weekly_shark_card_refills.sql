/*
  # Add VIP Weekly Shark Card Refills

  1. Changes
    - Add weekly_refill_amount column to vip_levels table
    - Update VIP 1 (level 4): $50 USD weekly shark card refill
    - Update VIP 2 (level 5): $100 USD weekly shark card refill
    - Update Diamond (level 6): $500 USD weekly shark card refill
    - Create table to track refill distributions
    - Create function to distribute weekly refills

  2. New Tables
    - vip_refill_distributions: Track when refills are distributed to users

  3. Security
    - Enable RLS on new table
    - Users can view their own refill history
    - Admin can view all refill distributions
*/

-- Add weekly refill amount column to vip_levels
ALTER TABLE vip_levels 
ADD COLUMN IF NOT EXISTS weekly_refill_amount numeric DEFAULT 0;

-- Update VIP levels with weekly refill amounts
UPDATE vip_levels SET weekly_refill_amount = 50 WHERE level_number = 4;  -- VIP 1: $50
UPDATE vip_levels SET weekly_refill_amount = 100 WHERE level_number = 5; -- VIP 2: $100
UPDATE vip_levels SET weekly_refill_amount = 500 WHERE level_number = 6; -- Diamond: $500

-- Update benefits to mention weekly refills
UPDATE vip_levels 
SET benefits = 'Advanced traders enjoy boosted rates + $50 weekly shark card refill'
WHERE level_number = 4;

UPDATE vip_levels 
SET benefits = 'Top-tier — maximum commissions, exclusive perks + $100 weekly shark card refill'
WHERE level_number = 5;

UPDATE vip_levels 
SET benefits = 'Diamond Elite — highest rewards, priority support + $500 weekly shark card refill'
WHERE level_number = 6;

-- Create table to track refill distributions
CREATE TABLE IF NOT EXISTS vip_refill_distributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  vip_level integer NOT NULL,
  refill_amount numeric NOT NULL,
  distributed_at timestamptz DEFAULT NOW(),
  transaction_id uuid REFERENCES transactions(id),
  created_at timestamptz DEFAULT NOW()
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_vip_refills_user_id ON vip_refill_distributions(user_id);
CREATE INDEX IF NOT EXISTS idx_vip_refills_distributed_at ON vip_refill_distributions(distributed_at);

-- Enable RLS
ALTER TABLE vip_refill_distributions ENABLE ROW LEVEL SECURITY;

-- Users can view their own refill history
CREATE POLICY "Users can view own refill distributions"
  ON vip_refill_distributions
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Admin can view all refill distributions
CREATE POLICY "Admin can view all refill distributions"
  ON vip_refill_distributions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );

-- Function to distribute weekly refills to eligible VIP users
CREATE OR REPLACE FUNCTION distribute_vip_weekly_refills()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_record RECORD;
  v_vip_level_record RECORD;
  v_refill_amount numeric;
  v_transaction_id uuid;
  v_distributed_count integer := 0;
  v_total_amount numeric := 0;
BEGIN
  -- Loop through all users with VIP status that have weekly refills
  FOR v_user_record IN
    SELECT uvs.user_id, uvs.current_level
    FROM user_vip_status uvs
    INNER JOIN vip_levels vl ON vl.level_number = uvs.current_level
    WHERE vl.weekly_refill_amount > 0
  LOOP
    -- Get VIP level details
    SELECT * INTO v_vip_level_record
    FROM vip_levels
    WHERE level_number = v_user_record.current_level;

    v_refill_amount := v_vip_level_record.weekly_refill_amount;

    -- Check if user already received refill this week
    IF EXISTS (
      SELECT 1 FROM vip_refill_distributions
      WHERE user_id = v_user_record.user_id
        AND distributed_at >= NOW() - INTERVAL '7 days'
    ) THEN
      CONTINUE; -- Skip this user, already received refill this week
    END IF;

    -- Ensure wallet exists
    INSERT INTO wallets (user_id, currency, balance, wallet_type)
    VALUES (v_user_record.user_id, 'USDT', 0, 'main')
    ON CONFLICT (user_id, currency, wallet_type) 
    DO NOTHING;

    -- Add refill to user's main wallet
    UPDATE wallets
    SET 
      balance = balance + v_refill_amount,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id
      AND currency = 'USDT'
      AND wallet_type = 'main';

    -- Create transaction record
    INSERT INTO transactions (
      user_id,
      transaction_type,
      amount,
      currency,
      status,
      metadata
    ) VALUES (
      v_user_record.user_id,
      'vip_refill',
      v_refill_amount,
      'USDT',
      'completed',
      jsonb_build_object(
        'vip_level', v_user_record.current_level,
        'level_name', v_vip_level_record.level_name,
        'refill_type', 'weekly_shark_card'
      )
    ) RETURNING id INTO v_transaction_id;

    -- Record the refill distribution
    INSERT INTO vip_refill_distributions (
      user_id,
      vip_level,
      refill_amount,
      transaction_id,
      distributed_at
    ) VALUES (
      v_user_record.user_id,
      v_user_record.current_level,
      v_refill_amount,
      v_transaction_id,
      NOW()
    );

    -- Create notification
    INSERT INTO notifications (
      user_id,
      type,
      title,
      message,
      is_read
    ) VALUES (
      v_user_record.user_id,
      'vip_refill',
      'Weekly VIP Shark Card Refill',
      format('You received $%s USDT as your weekly %s shark card refill!', 
        v_refill_amount, v_vip_level_record.level_name),
      false
    );

    v_distributed_count := v_distributed_count + 1;
    v_total_amount := v_total_amount + v_refill_amount;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'distributed_count', v_distributed_count,
    'total_amount', v_total_amount,
    'timestamp', NOW()
  );
END;
$$;

-- Add vip_refill to transaction types if not already there
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints 
    WHERE constraint_name = 'transactions_transaction_type_check'
    AND constraint_schema = 'public'
  ) THEN
    -- No constraint exists, we're good
    NULL;
  END IF;
END $$;