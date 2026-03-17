/*
  # Allocate Antonio's Unallocated $40 to Copy Relationship

  1. Problem
    - User antonio.carrese7979@gmail.com (c964c821-1160-4821-b6ec-756a98439d96)
    - Transferred $40 from main to copy wallet on 2026-02-28 11:56:35
    - Copy wallet was correctly credited, but the $40 was NOT allocated to the active copy relationship
    - Relationship still shows initial_balance = $110 instead of $150

  2. Fix
    - Update copy relationship initial_balance from $110 to $150
    - Update copy relationship current_balance by adding $40
    - No wallet changes needed (wallet balance is already correct)

  3. Verification
    - Copy wallet stays at $123.17 (already correct)
    - Expected relationship initial_balance: $150
*/

-- Update Antonio's copy relationship to include the additional $40
UPDATE copy_relationships
SET initial_balance = initial_balance + 40.00,
    current_balance = current_balance + 40.00,
    updated_at = now()
WHERE id = '90044dd5-a5fe-49e1-b45d-f2f692af43e7'
  AND follower_id = 'c964c821-1160-4821-b6ec-756a98439d96';
