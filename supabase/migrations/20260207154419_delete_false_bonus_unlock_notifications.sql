/*
  # Delete False "Bonus Ready to Unlock!" Notifications

  ## Problem
  Users received "Bonus Ready to Unlock!" notifications because their bonuses had 
  $0 volume requirement. Now that we've fixed the requirements, these notifications
  are incorrect and misleading.

  ## Solution
  Delete all "Bonus Ready to Unlock!" notifications where the associated bonus
  hasn't actually met the REAL requirements (original_amount * 500).

  Note: We also keep notifications for bonuses that are already unlocked or 
  where the user has genuinely completed the proper volume requirement.
*/

DELETE FROM notifications
WHERE title = 'Bonus Ready to Unlock!'
  AND (data->>'locked_bonus_id')::uuid IN (
    SELECT lb.id
    FROM locked_bonuses lb
    WHERE lb.bonus_trading_volume_completed < (lb.original_amount * 500)
      AND lb.is_unlocked = false
  );
