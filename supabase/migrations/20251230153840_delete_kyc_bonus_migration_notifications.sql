/*
  # Delete KYC Bonus Migration Notifications

  Removes the notifications sent during the KYC bonus migration.
*/

DELETE FROM notifications
WHERE title = 'KYC Bonus Updated'
  AND message LIKE '%KYC verification bonus has been converted to locked trading credit%';
