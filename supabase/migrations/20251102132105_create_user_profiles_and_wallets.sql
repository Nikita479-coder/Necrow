/*
  # Create User Profiles and Wallet System

  ## Description
  This migration creates the core user profile and multi-currency wallet system
  for the crypto exchange platform.

  ## New Tables

  ### 1. user_profiles
  Extended user information beyond auth.users
  - `id` (uuid, primary key, references auth.users)
  - `username` (text, unique) - Display name
  - `full_name` (text) - Full legal name
  - `phone` (text) - Phone number
  - `country` (text) - Country code
  - `kyc_status` (text) - unverified, pending, verified, rejected
  - `kyc_level` (integer) - 0, 1, 2 (verification levels)
  - `referral_code` (text, unique) - User's referral code
  - `referred_by` (uuid) - User who referred them
  - `avatar_url` (text) - Profile picture URL
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 2. wallets
  Multi-currency wallet balances for each user
  - `id` (uuid, primary key)
  - `user_id` (uuid, references auth.users)
  - `currency` (text) - BTC, ETH, USDT, etc.
  - `balance` (numeric) - Available balance
  - `locked_balance` (numeric) - Balance locked in orders/positions
  - `total_deposited` (numeric) - Lifetime deposits
  - `total_withdrawn` (numeric) - Lifetime withdrawals
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### 3. wallet_addresses
  Deposit addresses for each currency
  - `id` (uuid, primary key)
  - `user_id` (uuid, references auth.users)
  - `currency` (text) - Currency code
  - `address` (text) - Blockchain address
  - `network` (text) - Network type (ERC20, TRC20, etc.)
  - `created_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Users can only read/update their own data
  - Wallet addresses are read-only for users

  ## Indexes
  - Optimized for frequent balance lookups
  - Username and referral code uniqueness
*/

-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text UNIQUE,
  full_name text,
  phone text,
  country text,
  kyc_status text NOT NULL DEFAULT 'unverified',
  kyc_level integer NOT NULL DEFAULT 0,
  referral_code text UNIQUE NOT NULL,
  referred_by uuid REFERENCES auth.users(id),
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (kyc_status IN ('unverified', 'pending', 'verified', 'rejected')),
  CHECK (kyc_level >= 0 AND kyc_level <= 2)
);

-- Wallets Table
CREATE TABLE IF NOT EXISTS wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  currency text NOT NULL,
  balance numeric(20,8) NOT NULL DEFAULT 0,
  locked_balance numeric(20,8) NOT NULL DEFAULT 0,
  total_deposited numeric(20,8) NOT NULL DEFAULT 0,
  total_withdrawn numeric(20,8) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, currency),
  CHECK (balance >= 0),
  CHECK (locked_balance >= 0)
);

-- Wallet Addresses Table
CREATE TABLE IF NOT EXISTS wallet_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  currency text NOT NULL,
  address text NOT NULL,
  network text NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, currency, network)
);

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_addresses ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
CREATE POLICY "Users can read own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Wallets Policies
CREATE POLICY "Users can read own wallets"
  ON wallets
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wallets"
  ON wallets
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Wallet Addresses Policies
CREATE POLICY "Users can read own wallet addresses"
  ON wallet_addresses
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON user_profiles(username);
CREATE INDEX IF NOT EXISTS idx_user_profiles_referral_code ON user_profiles(referral_code);
CREATE INDEX IF NOT EXISTS idx_user_profiles_referred_by ON user_profiles(referred_by);
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_currency ON wallets(currency);
CREATE INDEX IF NOT EXISTS idx_wallet_addresses_user_id ON wallet_addresses(user_id);

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS text AS $$
DECLARE
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i integer;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-create profile on user signup
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, referral_code)
  VALUES (NEW.id, generate_referral_code());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-create profile
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();