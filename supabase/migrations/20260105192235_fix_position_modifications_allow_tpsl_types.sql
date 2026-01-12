/*
  # Fix position_modifications check constraint

  1. Changes
    - Add 'take_profit' and 'stop_loss' to allowed modification_type values
    - These are needed by the TP/SL trigger when positions are closed automatically
*/

ALTER TABLE position_modifications 
DROP CONSTRAINT IF EXISTS position_modifications_modification_type_check;

ALTER TABLE position_modifications 
ADD CONSTRAINT position_modifications_modification_type_check 
CHECK (modification_type = ANY (ARRAY[
  'margin_added', 
  'margin_removed', 
  'tp_sl_updated', 
  'partial_close', 
  'leverage_changed',
  'take_profit',
  'stop_loss',
  'liquidation'
]));
