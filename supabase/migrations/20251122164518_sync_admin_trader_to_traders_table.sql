/*
  # Sync Admin Managed Traders to Traders Table

  1. Functions
    - Creates/updates traders table entry when admin_managed_traders changes
    - Keeps both tables in sync automatically

  2. Features
    - Automatic sync on insert/update
    - Allows copying admin-managed traders
    - Maintains consistency
*/

-- Function to sync admin trader to traders table
CREATE OR REPLACE FUNCTION sync_admin_trader_to_traders()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert or update in traders table
  INSERT INTO traders (
    id, name, avatar, api_verified, is_featured,
    pnl_30d, roi_30d, aum, win_rate, followers_count,
    created_at, updated_at
  )
  VALUES (
    NEW.id, NEW.name, NEW.avatar, true, true,
    NEW.total_pnl, NEW.roi_30d, NEW.total_aum, NEW.win_rate, NEW.total_followers,
    NEW.created_at, NEW.updated_at
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    avatar = EXCLUDED.avatar,
    pnl_30d = EXCLUDED.pnl_30d,
    roi_30d = EXCLUDED.roi_30d,
    aum = EXCLUDED.aum,
    win_rate = EXCLUDED.win_rate,
    followers_count = EXCLUDED.followers_count,
    updated_at = EXCLUDED.updated_at;

  RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS sync_admin_trader_trigger ON admin_managed_traders;
CREATE TRIGGER sync_admin_trader_trigger
  AFTER INSERT OR UPDATE ON admin_managed_traders
  FOR EACH ROW
  EXECUTE FUNCTION sync_admin_trader_to_traders();
