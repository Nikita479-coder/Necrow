/*
  # Create Popup Banner System

  1. New Tables
    - `popup_banners`
      - `id` (uuid, primary key)
      - `title` (text) - Banner title
      - `description` (text, nullable) - Optional description
      - `image_url` (text) - URL to the uploaded image in storage
      - `image_path` (text) - Storage path for cleanup
      - `is_active` (boolean) - Whether banner is currently active
      - `created_at` (timestamptz)
      - `created_by` (uuid) - Admin who created it
      - `updated_at` (timestamptz)

    - `popup_banner_views`
      - `id` (uuid, primary key)
      - `popup_id` (uuid) - Reference to popup_banners
      - `user_id` (uuid) - User who viewed it
      - `viewed_at` (timestamptz)
      - Unique constraint on (popup_id, user_id)

  2. Storage
    - Create storage bucket for popup images
    - Set up public access policies for viewing
    - Set up admin-only upload policies

  3. Security
    - Enable RLS on both tables
    - Admins can manage all popup banners
    - Users can view active banners and track their own views
*/

-- Create popup_banners table
CREATE TABLE IF NOT EXISTS popup_banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  image_url text NOT NULL,
  image_path text NOT NULL,
  is_active boolean DEFAULT true,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create popup_banner_views tracking table
CREATE TABLE IF NOT EXISTS popup_banner_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  popup_id uuid REFERENCES popup_banners(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  viewed_at timestamptz DEFAULT now(),
  UNIQUE(popup_id, user_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_popup_banners_active ON popup_banners(is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_popup_banner_views_user ON popup_banner_views(user_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_popup_banner_views_popup ON popup_banner_views(popup_id);

-- Enable RLS
ALTER TABLE popup_banners ENABLE ROW LEVEL SECURITY;
ALTER TABLE popup_banner_views ENABLE ROW LEVEL SECURITY;

-- Policies for popup_banners
CREATE POLICY "Admins can manage all popup banners"
  ON popup_banners
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

CREATE POLICY "Users can view active popup banners"
  ON popup_banners
  FOR SELECT
  TO authenticated
  USING (is_active = true);

-- Policies for popup_banner_views
CREATE POLICY "Users can view their own popup views"
  ON popup_banner_views
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own popup views"
  ON popup_banner_views
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can view all popup views"
  ON popup_banner_views
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Create storage bucket for popup banners
INSERT INTO storage.buckets (id, name, public)
VALUES ('popup-banners', 'popup-banners', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: Allow public to view images
CREATE POLICY "Public can view popup banner images"
  ON storage.objects
  FOR SELECT
  USING (bucket_id = 'popup-banners');

-- Storage policies: Only admins can upload
CREATE POLICY "Admins can upload popup banner images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'popup-banners'
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Storage policies: Only admins can delete
CREATE POLICY "Admins can delete popup banner images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'popup-banners'
    AND EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Function to get unseen popups for current user
CREATE OR REPLACE FUNCTION get_unseen_popups()
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  image_url text,
  created_at timestamptz
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pb.id,
    pb.title,
    pb.description,
    pb.image_url,
    pb.created_at
  FROM popup_banners pb
  WHERE pb.is_active = true
  AND NOT EXISTS (
    SELECT 1 FROM popup_banner_views pbv
    WHERE pbv.popup_id = pb.id
    AND pbv.user_id = auth.uid()
  )
  ORDER BY pb.created_at DESC;
END;
$$;

-- Function to mark popup as viewed
CREATE OR REPLACE FUNCTION mark_popup_viewed(p_popup_id uuid)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO popup_banner_views (popup_id, user_id, viewed_at)
  VALUES (p_popup_id, auth.uid(), now())
  ON CONFLICT (popup_id, user_id) DO NOTHING;
END;
$$;

-- Function to get popup statistics (admin only)
CREATE OR REPLACE FUNCTION get_popup_statistics()
RETURNS TABLE (
  popup_id uuid,
  title text,
  image_url text,
  is_active boolean,
  created_at timestamptz,
  total_views bigint,
  unique_viewers bigint,
  view_percentage numeric
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_users bigint;
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Get total number of users
  SELECT COUNT(*) INTO v_total_users FROM user_profiles;

  RETURN QUERY
  SELECT
    pb.id,
    pb.title,
    pb.image_url,
    pb.is_active,
    pb.created_at,
    COUNT(pbv.id) as total_views,
    COUNT(DISTINCT pbv.user_id) as unique_viewers,
    CASE
      WHEN v_total_users > 0 THEN
        ROUND((COUNT(DISTINCT pbv.user_id)::numeric / v_total_users::numeric) * 100, 2)
      ELSE 0
    END as view_percentage
  FROM popup_banners pb
  LEFT JOIN popup_banner_views pbv ON pb.id = pbv.popup_id
  GROUP BY pb.id, pb.title, pb.image_url, pb.is_active, pb.created_at
  ORDER BY pb.created_at DESC;
END;
$$;

-- Function to delete popup and its image (admin only)
CREATE OR REPLACE FUNCTION delete_popup_banner(p_popup_id uuid)
RETURNS json
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_image_path text;
  v_result json;
BEGIN
  -- Check if user is admin
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Get image path
  SELECT image_path INTO v_image_path
  FROM popup_banners
  WHERE id = p_popup_id;

  IF v_image_path IS NULL THEN
    RAISE EXCEPTION 'Popup banner not found';
  END IF;

  -- Delete the banner record (views will cascade delete)
  DELETE FROM popup_banners WHERE id = p_popup_id;

  -- Return the image path so client can delete from storage
  v_result := json_build_object(
    'success', true,
    'image_path', v_image_path
  );

  -- Log the action
  INSERT INTO admin_activity_logs (
    admin_id,
    action_type,
    action_description,
    ip_address
  ) VALUES (
    auth.uid(),
    'popup_banner_deleted',
    'Deleted popup banner: ' || p_popup_id::text,
    current_setting('request.headers', true)::json->>'x-real-ip'
  );

  RETURN v_result;
END;
$$;

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_popup_banner_updated_at()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER popup_banner_updated_at
  BEFORE UPDATE ON popup_banners
  FOR EACH ROW
  EXECUTE FUNCTION update_popup_banner_updated_at();