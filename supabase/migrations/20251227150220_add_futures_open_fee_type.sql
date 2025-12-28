/*
  # Add futures_open Fee Type

  1. Changes
    - Add 'futures_open' to allowed fee types in fee_collections table
*/

ALTER TABLE fee_collections DROP CONSTRAINT IF EXISTS fee_collections_fee_type_check;

ALTER TABLE fee_collections ADD CONSTRAINT fee_collections_fee_type_check 
CHECK (fee_type = ANY (ARRAY['spread'::text, 'funding'::text, 'maker'::text, 'taker'::text, 'liquidation'::text, 'futures_open'::text, 'futures_close'::text]));