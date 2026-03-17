/*
  # Add Indexes for Unindexed Foreign Keys

  ## Summary
  Adds indexes for all foreign key columns that were missing indexes.
  This improves JOIN performance and query optimization.

  ## Changes
  - Creates indexes for 55+ foreign key columns across various tables
  - Uses IF NOT EXISTS to prevent errors if indexes already exist
*/

-- admin_role_permissions
CREATE INDEX IF NOT EXISTS idx_admin_role_permissions_permission_id 
ON admin_role_permissions(permission_id);

-- admin_staff
CREATE INDEX IF NOT EXISTS idx_admin_staff_created_by 
ON admin_staff(created_by);

-- affiliate_settings
CREATE INDEX IF NOT EXISTS idx_affiliate_settings_updated_by 
ON affiliate_settings(updated_by);

-- affiliate_tiers
CREATE INDEX IF NOT EXISTS idx_affiliate_tiers_direct_referrer_id 
ON affiliate_tiers(direct_referrer_id);

-- bonus_types
CREATE INDEX IF NOT EXISTS idx_bonus_types_created_by 
ON bonus_types(created_by);

-- copy_position_history
CREATE INDEX IF NOT EXISTS idx_copy_position_history_relationship_id 
ON copy_position_history(relationship_id);

-- copy_trade_daily_performance
CREATE INDEX IF NOT EXISTS idx_copy_trade_daily_performance_relationship_id 
ON copy_trade_daily_performance(copy_relationship_id);

CREATE INDEX IF NOT EXISTS idx_copy_trade_daily_performance_trader 
ON copy_trade_daily_performance(trader_id);

-- copy_trade_responses
CREATE INDEX IF NOT EXISTS idx_copy_trade_responses_relationship_id 
ON copy_trade_responses(copy_relationship_id);

-- copy_trading_stats
CREATE INDEX IF NOT EXISTS idx_copy_trading_stats_follower 
ON copy_trading_stats(follower_id);

CREATE INDEX IF NOT EXISTS idx_copy_trading_stats_trader 
ON copy_trading_stats(trader_id);

-- email_logs
CREATE INDEX IF NOT EXISTS idx_email_logs_sent_by 
ON email_logs(sent_by);

CREATE INDEX IF NOT EXISTS idx_email_logs_template_id 
ON email_logs(template_id);

-- email_templates
CREATE INDEX IF NOT EXISTS idx_email_templates_created_by 
ON email_templates(created_by);

-- fee_collections
CREATE INDEX IF NOT EXISTS idx_fee_collections_position_id 
ON fee_collections(position_id);

-- frenzy_lottery_tickets
CREATE INDEX IF NOT EXISTS idx_frenzy_lottery_tickets_user 
ON frenzy_lottery_tickets(user_id);

-- frenzy_participants
CREATE INDEX IF NOT EXISTS idx_frenzy_participants_user 
ON frenzy_participants(user_id);

-- kyc_verifications
CREATE INDEX IF NOT EXISTS idx_kyc_verifications_otto_session 
ON kyc_verifications(otto_session_id);

-- liquidation_queue
CREATE INDEX IF NOT EXISTS idx_liquidation_queue_user 
ON liquidation_queue(user_id);

-- locked_bonuses
CREATE INDEX IF NOT EXISTS idx_locked_bonuses_awarded_by 
ON locked_bonuses(awarded_by);

CREATE INDEX IF NOT EXISTS idx_locked_bonuses_bonus_type 
ON locked_bonuses(bonus_type_id);

-- lucky_draw_winners
CREATE INDEX IF NOT EXISTS idx_lucky_draw_winners_user 
ON lucky_draw_winners(user_id);

-- pending_copy_trades
CREATE INDEX IF NOT EXISTS idx_pending_copy_trades_admin_trader 
ON pending_copy_trades(admin_trader_id);

-- position_modifications
CREATE INDEX IF NOT EXISTS idx_position_modifications_position 
ON position_modifications(position_id);

-- referral_commissions
CREATE INDEX IF NOT EXISTS idx_referral_commissions_transaction 
ON referral_commissions(transaction_id);

-- referral_rebates
CREATE INDEX IF NOT EXISTS idx_referral_rebates_transaction 
ON referral_rebates(transaction_id);

-- risk_alerts
CREATE INDEX IF NOT EXISTS idx_risk_alerts_acknowledged_by 
ON risk_alerts(acknowledged_by_admin_id);

-- risk_rules
CREATE INDEX IF NOT EXISTS idx_risk_rules_created_by 
ON risk_rules(created_by_admin_id);

-- shark_card_applications
CREATE INDEX IF NOT EXISTS idx_shark_card_applications_reviewed_by 
ON shark_card_applications(reviewed_by);

-- shark_cards
CREATE INDEX IF NOT EXISTS idx_shark_cards_application 
ON shark_cards(application_id);

-- staff_permission_overrides
CREATE INDEX IF NOT EXISTS idx_staff_permission_overrides_created_by 
ON staff_permission_overrides(created_by);

CREATE INDEX IF NOT EXISTS idx_staff_permission_overrides_permission 
ON staff_permission_overrides(permission_id);

-- support_attachments
CREATE INDEX IF NOT EXISTS idx_support_attachments_message 
ON support_attachments(message_id);

CREATE INDEX IF NOT EXISTS idx_support_attachments_uploaded_by 
ON support_attachments(uploaded_by);

-- support_canned_responses
CREATE INDEX IF NOT EXISTS idx_support_canned_responses_category 
ON support_canned_responses(category_id);

CREATE INDEX IF NOT EXISTS idx_support_canned_responses_created_by 
ON support_canned_responses(created_by_admin_id);

-- support_messages
CREATE INDEX IF NOT EXISTS idx_support_messages_sender 
ON support_messages(sender_id);

-- support_tickets
CREATE INDEX IF NOT EXISTS idx_support_tickets_category 
ON support_tickets(category_id);

-- system_audit_logs
CREATE INDEX IF NOT EXISTS idx_system_audit_logs_triggered_by 
ON system_audit_logs(triggered_by);

-- terms_pages
CREATE INDEX IF NOT EXISTS idx_terms_pages_related_event 
ON terms_pages(related_event_id);

-- trader_trades
CREATE INDEX IF NOT EXISTS idx_trader_trades_pending_trade 
ON trader_trades(pending_trade_id);

-- trades
CREATE INDEX IF NOT EXISTS idx_trades_order 
ON trades(order_id);

-- user_bonuses
CREATE INDEX IF NOT EXISTS idx_user_bonuses_awarded_by 
ON user_bonuses(awarded_by);

CREATE INDEX IF NOT EXISTS idx_user_bonuses_bonus_type 
ON user_bonuses(bonus_type_id);

CREATE INDEX IF NOT EXISTS idx_user_bonuses_locked_bonus 
ON user_bonuses(locked_bonus_id);

-- user_profiles
CREATE INDEX IF NOT EXISTS idx_user_profiles_withdrawal_blocked_by 
ON user_profiles(withdrawal_blocked_by);

-- user_risk_flags
CREATE INDEX IF NOT EXISTS idx_user_risk_flags_flagged_by 
ON user_risk_flags(flagged_by_admin_id);

-- user_segment_members
CREATE INDEX IF NOT EXISTS idx_user_segment_members_added_by 
ON user_segment_members(added_by);

CREATE INDEX IF NOT EXISTS idx_user_segment_members_user 
ON user_segment_members(user_id);

-- user_segments
CREATE INDEX IF NOT EXISTS idx_user_segments_created_by 
ON user_segments(created_by);

-- user_stakes
CREATE INDEX IF NOT EXISTS idx_user_stakes_product 
ON user_stakes(product_id);

-- user_tag_assignments
CREATE INDEX IF NOT EXISTS idx_user_tag_assignments_assigned_by 
ON user_tag_assignments(assigned_by);

-- user_tags
CREATE INDEX IF NOT EXISTS idx_user_tags_created_by 
ON user_tags(created_by);

-- vip_refill_distributions
CREATE INDEX IF NOT EXISTS idx_vip_refill_distributions_transaction 
ON vip_refill_distributions(transaction_id);

-- vip_retention_campaigns
CREATE INDEX IF NOT EXISTS idx_vip_retention_campaigns_created_by 
ON vip_retention_campaigns(created_by);

CREATE INDEX IF NOT EXISTS idx_vip_retention_campaigns_email_template 
ON vip_retention_campaigns(email_template_id);

-- vip_tier_downgrades
CREATE INDEX IF NOT EXISTS idx_vip_tier_downgrades_actioned_by 
ON vip_tier_downgrades(actioned_by);

-- withdrawal_approvals
CREATE INDEX IF NOT EXISTS idx_withdrawal_approvals_reviewed_by 
ON withdrawal_approvals(reviewed_by_admin_id);
