/*
  # Make locked_bonuses.awarded_by nullable

  ## Summary
  The awarded_by column needs to be nullable for system-generated bonuses
  like the first deposit bonus which aren't awarded by an admin user.

  ## Changes
  - Alter awarded_by column to allow NULL values
*/

ALTER TABLE locked_bonuses 
ALTER COLUMN awarded_by DROP NOT NULL;
