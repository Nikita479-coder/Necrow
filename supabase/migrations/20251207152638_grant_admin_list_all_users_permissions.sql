/*
  # Grant permissions for admin_list_all_users function
  
  1. Security
    - Grant execute permission to authenticated users
    - Function internally checks if user is admin
*/

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION admin_list_all_users(text, integer, integer) TO authenticated;