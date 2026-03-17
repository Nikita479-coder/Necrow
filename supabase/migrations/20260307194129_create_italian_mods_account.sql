/*
  # Create Italian Mods Account

  1. New Account
    - Email: italianmods@sharktrades.com
    - Password: ItalianMods2026!
    - Full name: Italian Mods
    - Regular user (no admin privileges)

  2. Notes
    - Account is created with email confirmed
    - Standard user wallets and profile will be auto-created by existing triggers
*/

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'italianmods@sharktrades.com') THEN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      gen_random_uuid(),
      'authenticated',
      'authenticated',
      'italianmods@sharktrades.com',
      crypt('ItalianMods2026!', gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      '{"full_name": "Italian Mods"}'::jsonb,
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  END IF;
END $$;
