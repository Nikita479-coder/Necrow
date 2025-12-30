/*
  # Migrate Old KYC Bonus from Main Wallet to Locked Bonus

  ## Summary
  Users who received KYC bonus under the old system have $20 in their main wallet.
  This migration moves that amount to locked bonus for consistency with the new system.

  ## Migration Logic
  1. Find users with `kyc_bonus_awarded = true` in `signup_bonus_tracking`
  2. Who do NOT have an existing "KYC Verification Bonus" locked bonus
  3. Who have sufficient USDT balance in main wallet
  4. Deduct the kyc_bonus_amount from their main wallet
  5. Create a new locked_bonus record with fresh 7-day expiry
  6. Create a notification explaining the migration
  7. Create a transaction record for audit trail

  ## Security
  - This is a one-time migration run with elevated privileges
  - All changes are atomic within the DO block
  - Skip users who don't have sufficient balance (log them for review)
*/

DO $$
DECLARE
  v_user RECORD;
  v_wallet RECORD;
  v_bonus_type_id uuid;
  v_locked_bonus_id uuid;
  v_migrated_count integer := 0;
  v_skipped_count integer := 0;
  v_kyc_bonus_amount numeric := 20;
BEGIN
  -- Get the KYC Verification Bonus type ID
  SELECT id INTO v_bonus_type_id
  FROM bonus_types
  WHERE name = 'KYC Verification Bonus'
  LIMIT 1;

  IF v_bonus_type_id IS NULL THEN
    RAISE NOTICE 'KYC Verification Bonus type not found, skipping migration';
    RETURN;
  END IF;

  -- Find users who:
  -- 1. Have kyc_bonus_awarded = true
  -- 2. Do NOT have an existing KYC Verification Bonus in locked_bonuses
  FOR v_user IN
    SELECT 
      sbt.user_id,
      sbt.kyc_bonus_amount,
      up.username,
      up.full_name
    FROM signup_bonus_tracking sbt
    JOIN user_profiles up ON up.id = sbt.user_id
    WHERE sbt.kyc_bonus_awarded = true
      AND sbt.kyc_bonus_amount IS NOT NULL
      AND sbt.kyc_bonus_amount > 0
      AND NOT EXISTS (
        SELECT 1 FROM locked_bonuses lb
        WHERE lb.user_id = sbt.user_id
          AND lb.bonus_type_name = 'KYC Verification Bonus'
      )
  LOOP
    -- Check if user has sufficient USDT balance in main wallet
    SELECT * INTO v_wallet
    FROM wallets
    WHERE user_id = v_user.user_id
      AND currency = 'USDT'
      AND wallet_type = 'main'
    FOR UPDATE;

    IF v_wallet IS NULL OR v_wallet.balance < v_user.kyc_bonus_amount THEN
      -- Skip this user - insufficient balance
      RAISE NOTICE 'Skipping user % (%) - insufficient balance (wallet: %, needed: %)',
        v_user.full_name, v_user.username, 
        COALESCE(v_wallet.balance, 0), v_user.kyc_bonus_amount;
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- Deduct from main wallet
    UPDATE wallets
    SET 
      balance = balance - v_user.kyc_bonus_amount,
      updated_at = now()
    WHERE id = v_wallet.id;

    -- Create locked bonus with fresh 7-day expiry
    INSERT INTO locked_bonuses (
      user_id,
      original_amount,
      current_amount,
      bonus_type_id,
      bonus_type_name,
      awarded_by,
      notes,
      status,
      expires_at,
      bonus_trading_volume_required,
      bonus_trading_volume_completed,
      minimum_position_duration_minutes
    ) VALUES (
      v_user.user_id,
      v_user.kyc_bonus_amount,
      v_user.kyc_bonus_amount,
      v_bonus_type_id,
      'KYC Verification Bonus',
      v_user.user_id,
      'Migrated from main wallet - original KYC bonus received under old system',
      'active',
      now() + interval '7 days',
      v_user.kyc_bonus_amount * 500,
      0,
      60
    )
    RETURNING id INTO v_locked_bonus_id;

    -- Create transaction record for audit trail
    INSERT INTO transactions (
      user_id,
      transaction_type,
      currency,
      amount,
      status,
      details
    ) VALUES (
      v_user.user_id,
      'admin_debit',
      'USDT',
      v_user.kyc_bonus_amount,
      'completed',
      jsonb_build_object(
        'reason', 'KYC bonus migration from main wallet to locked bonus',
        'locked_bonus_id', v_locked_bonus_id,
        'migration_date', now()::text
      )
    );

    -- Create notification
    INSERT INTO notifications (user_id, type, title, message)
    VALUES (
      v_user.user_id,
      'system',
      'KYC Bonus Updated',
      'Your $' || v_user.kyc_bonus_amount || ' KYC verification bonus has been converted to locked trading credit. This bonus is valid for 7 days and can be used for futures trading. Only profits can be withdrawn after completing the volume requirement.'
    );

    v_migrated_count := v_migrated_count + 1;
    RAISE NOTICE 'Migrated user % (%) - $% moved to locked bonus',
      v_user.full_name, v_user.username, v_user.kyc_bonus_amount;
  END LOOP;

  RAISE NOTICE '=== Migration Complete ===';
  RAISE NOTICE 'Migrated: % users', v_migrated_count;
  RAISE NOTICE 'Skipped (insufficient balance): % users', v_skipped_count;
END $$;
