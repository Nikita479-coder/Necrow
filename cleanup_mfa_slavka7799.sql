-- Clean up stuck MFA factors for slavka7799@gmail.com
-- Run this in the Supabase SQL Editor at:
-- https://supabase.com/dashboard/project/xcfyfzhcgphmiqvdfhrf/sql

DELETE FROM auth.mfa_factors
WHERE user_id = (
  SELECT id FROM auth.users WHERE email = 'slavka7799@gmail.com'
)
AND status = 'unverified';

-- This query will return the number of factors deleted
-- After running this, ask the user to try enabling 2FA again
