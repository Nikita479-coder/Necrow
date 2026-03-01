/*
  # Create Copy Trading and KYC Systems
  
  1. Copy Trading Tables
    - copy_traders: Master traders that can be copied
    - copy_relationships: User follower relationships
    - copy_configurations: Copy trading settings per relationship
    
  2. KYC Tables
    - kyc_documents: User verification documents
    
  3. Transaction Tables
    - transactions: All deposit/withdrawal history
*/

CREATE TABLE IF NOT EXISTS copy_traders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  display_name text NOT NULL,
  bio text,
  total_followers integer DEFAULT 0,
  total_copiers integer DEFAULT 0,
  win_rate numeric(5,2) DEFAULT 0,
  total_pnl numeric(20,2) DEFAULT 0,
  roi_30d numeric(10,2) DEFAULT 0,
  total_trades integer DEFAULT 0,
  is_verified boolean DEFAULT false,
  is_active boolean DEFAULT true,
  min_copy_amount numeric(20,2) DEFAULT 100,
  max_copiers integer DEFAULT 1000,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (win_rate >= 0 AND win_rate <= 100)
);

CREATE TABLE IF NOT EXISTS copy_relationships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  trader_id uuid REFERENCES copy_traders(user_id) ON DELETE CASCADE NOT NULL,
  is_active boolean DEFAULT true,
  copy_amount numeric(20,2) NOT NULL,
  leverage integer DEFAULT 1,
  stop_loss_percent numeric(5,2),
  take_profit_percent numeric(5,2),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(follower_id, trader_id),
  CHECK (copy_amount >= 0),
  CHECK (leverage >= 1 AND leverage <= 125)
);

CREATE TABLE IF NOT EXISTS copy_configurations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid REFERENCES copy_relationships(id) ON DELETE CASCADE NOT NULL UNIQUE,
  copy_mode text NOT NULL DEFAULT 'fixed',
  amount_per_trade numeric(20,2),
  max_open_positions integer DEFAULT 10,
  copy_stop_loss boolean DEFAULT true,
  copy_take_profit boolean DEFAULT true,
  updated_at timestamptz DEFAULT now(),
  CHECK (copy_mode IN ('fixed', 'proportional'))
);

CREATE TABLE IF NOT EXISTS kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  document_type text NOT NULL,
  document_url text NOT NULL,
  verification_level integer NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  rejection_reason text,
  verified_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (document_type IN ('id_card', 'passport', 'drivers_license', 'proof_of_address')),
  CHECK (verification_level >= 1 AND verification_level <= 2),
  CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  transaction_type text NOT NULL,
  currency text NOT NULL,
  amount numeric(20,8) NOT NULL,
  fee numeric(20,8) DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  tx_hash text,
  address text,
  network text,
  confirmed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CHECK (transaction_type IN ('deposit', 'withdrawal')),
  CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  CHECK (amount > 0)
);

ALTER TABLE copy_traders ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE copy_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active copy traders"
  ON copy_traders FOR SELECT TO authenticated
  USING (is_active = true);

CREATE POLICY "Traders can update own profile"
  ON copy_traders FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Traders can insert own profile"
  ON copy_traders FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own copy relationships"
  ON copy_relationships FOR SELECT TO authenticated
  USING (auth.uid() = follower_id);

CREATE POLICY "Users can insert own copy relationships"
  ON copy_relationships FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can update own copy relationships"
  ON copy_relationships FOR UPDATE TO authenticated
  USING (auth.uid() = follower_id)
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can delete own copy relationships"
  ON copy_relationships FOR DELETE TO authenticated
  USING (auth.uid() = follower_id);

CREATE POLICY "Users can read own copy configs"
  ON copy_configurations FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM copy_relationships
    WHERE copy_relationships.id = copy_configurations.relationship_id
    AND copy_relationships.follower_id = auth.uid()
  ));

CREATE POLICY "Users can update own copy configs"
  ON copy_configurations FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM copy_relationships
    WHERE copy_relationships.id = copy_configurations.relationship_id
    AND copy_relationships.follower_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM copy_relationships
    WHERE copy_relationships.id = copy_configurations.relationship_id
    AND copy_relationships.follower_id = auth.uid()
  ));

CREATE POLICY "Users can insert own copy configs"
  ON copy_configurations FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM copy_relationships
    WHERE copy_relationships.id = copy_configurations.relationship_id
    AND copy_relationships.follower_id = auth.uid()
  ));

CREATE POLICY "Users can read own KYC documents"
  ON kyc_documents FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own KYC documents"
  ON kyc_documents FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own transactions"
  ON transactions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions"
  ON transactions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_copy_traders_user_id ON copy_traders(user_id);
CREATE INDEX IF NOT EXISTS idx_copy_traders_is_active ON copy_traders(is_active);
CREATE INDEX IF NOT EXISTS idx_copy_relationships_follower_id ON copy_relationships(follower_id);
CREATE INDEX IF NOT EXISTS idx_copy_relationships_trader_id ON copy_relationships(trader_id);
CREATE INDEX IF NOT EXISTS idx_kyc_documents_user_id ON kyc_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);