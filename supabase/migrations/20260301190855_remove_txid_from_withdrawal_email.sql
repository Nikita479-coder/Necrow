/*
  # Remove TXID from withdrawal email template

  1. Changes
    - Remove the TXID row from the "Withdrawal Completed" email template body
    - The withdrawal address border-bottom on the last detail row is preserved
*/

UPDATE email_templates
SET body = REPLACE(
  body,
  E'<tr>\n<td colspan="2" style="padding-top:12px;">\n<div style="font-family: Arial, Helvetica, sans-serif; font-size:12px; color:#94a3b8;">TXID</div>\n<div class="mono-wrap" style="margin-top:6px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, Liberation Mono, Courier New, monospace; font-size: 13px; line-height: 18px; color: #e7eef7; background: #0a0e13; border: 1px solid #1b2430; border-radius: 10px; padding: 10px 12px; word-break: break-word;">{{tx_hash}}</div>\n</td>\n</tr>',
  ''
),
updated_at = now()
WHERE name = 'Withdrawal Completed';