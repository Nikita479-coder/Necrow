/*
  # Add Missing Foreign Key Indexes

  1. Performance Improvements
    - Adding indexes on foreign key columns that were missing indexes
    - This improves JOIN performance and DELETE cascades
    
  2. Tables Fixed
    - campaign_tracking_links
    - exclusive_affiliate_withdrawals
    - exclusive_affiliates
    - fee_voucher_usage
    - fee_vouchers
    - giveaway_campaigns
    - giveaway_draw_audit
    - giveaway_winners
    - pending_copy_trades
    - phone_reveal_requests
    - phone_reveals_granted
    - popup_banners
    - quick_reply_templates
    - staff_activity_logs
    - telegram_message_logs
    - telegram_scheduled_messages
    - telegram_templates
*/

-- campaign_tracking_links.created_by
CREATE INDEX IF NOT EXISTS idx_campaign_tracking_links_created_by 
  ON campaign_tracking_links(created_by);

-- exclusive_affiliate_withdrawals.processed_by
CREATE INDEX IF NOT EXISTS idx_exclusive_affiliate_withdrawals_processed_by 
  ON exclusive_affiliate_withdrawals(processed_by);

-- exclusive_affiliates.enrolled_by
CREATE INDEX IF NOT EXISTS idx_exclusive_affiliates_enrolled_by 
  ON exclusive_affiliates(enrolled_by);

-- fee_voucher_usage.transaction_id
CREATE INDEX IF NOT EXISTS idx_fee_voucher_usage_transaction_id 
  ON fee_voucher_usage(transaction_id);

-- fee_vouchers.campaign_id
CREATE INDEX IF NOT EXISTS idx_fee_vouchers_campaign_id 
  ON fee_vouchers(campaign_id);

-- giveaway_campaigns.created_by
CREATE INDEX IF NOT EXISTS idx_giveaway_campaigns_created_by 
  ON giveaway_campaigns(created_by);

-- giveaway_draw_audit foreign keys
CREATE INDEX IF NOT EXISTS idx_giveaway_draw_audit_drawn_by 
  ON giveaway_draw_audit(drawn_by);

CREATE INDEX IF NOT EXISTS idx_giveaway_draw_audit_prize_id 
  ON giveaway_draw_audit(prize_id);

CREATE INDEX IF NOT EXISTS idx_giveaway_draw_audit_winner_user_id 
  ON giveaway_draw_audit(winner_user_id);

CREATE INDEX IF NOT EXISTS idx_giveaway_draw_audit_winning_ticket_id 
  ON giveaway_draw_audit(winning_ticket_id);

-- giveaway_winners foreign keys
CREATE INDEX IF NOT EXISTS idx_giveaway_winners_prize_id 
  ON giveaway_winners(prize_id);

CREATE INDEX IF NOT EXISTS idx_giveaway_winners_ticket_id 
  ON giveaway_winners(ticket_id);

-- pending_copy_trades.trader_trade_id
CREATE INDEX IF NOT EXISTS idx_pending_copy_trades_trader_trade_id 
  ON pending_copy_trades(trader_trade_id);

-- phone_reveal_requests foreign keys
CREATE INDEX IF NOT EXISTS idx_phone_reveal_requests_reviewed_by 
  ON phone_reveal_requests(reviewed_by);

CREATE INDEX IF NOT EXISTS idx_phone_reveal_requests_target_user_id 
  ON phone_reveal_requests(target_user_id);

-- phone_reveals_granted foreign keys
CREATE INDEX IF NOT EXISTS idx_phone_reveals_granted_granted_by 
  ON phone_reveals_granted(granted_by);

CREATE INDEX IF NOT EXISTS idx_phone_reveals_granted_request_id 
  ON phone_reveals_granted(request_id);

-- popup_banners.created_by
CREATE INDEX IF NOT EXISTS idx_popup_banners_created_by 
  ON popup_banners(created_by);

-- quick_reply_templates.created_by
CREATE INDEX IF NOT EXISTS idx_quick_reply_templates_created_by 
  ON quick_reply_templates(created_by);

-- staff_activity_logs.target_user_id
CREATE INDEX IF NOT EXISTS idx_staff_activity_logs_target_user_id 
  ON staff_activity_logs(target_user_id);

-- telegram_message_logs.user_id
CREATE INDEX IF NOT EXISTS idx_telegram_message_logs_user_id 
  ON telegram_message_logs(user_id);

-- telegram_scheduled_messages.template_id
CREATE INDEX IF NOT EXISTS idx_telegram_scheduled_messages_template_id 
  ON telegram_scheduled_messages(template_id);

-- telegram_templates.created_by
CREATE INDEX IF NOT EXISTS idx_telegram_templates_created_by 
  ON telegram_templates(created_by);
