/*
  # Remove Duplicate Indexes

  ## Description
  Removes duplicate indexes that are redundant with unique constraints or other indexes.
  Keeps the unique constraint indexes and removes the manually created duplicates.
*/

-- trader_trades duplicates
DROP INDEX IF EXISTS idx_trader_trades_pending_trade;
DROP INDEX IF EXISTS idx_trader_trades_trader;

-- copy_trade_daily_performance duplicates
DROP INDEX IF EXISTS idx_copy_trade_daily_perf_copy_rel_id;
DROP INDEX IF EXISTS idx_copy_trade_daily_perf_trader_id;

-- copy_trade_responses duplicates
DROP INDEX IF EXISTS idx_copy_trade_responses_copy_rel_id;

-- copy_traders (keep unique constraint)
DROP INDEX IF EXISTS idx_copy_traders_user_id;

-- copy_trading_stats duplicates
DROP INDEX IF EXISTS idx_copy_trading_stats_follower;
DROP INDEX IF EXISTS idx_copy_trading_stats_trader;

-- crm_analytics_snapshots (keep unique constraint)
DROP INDEX IF EXISTS idx_crm_analytics_snapshots_date;

-- crypto_deposits (keep unique constraint)
DROP INDEX IF EXISTS idx_crypto_deposits_nowpayments_id;

-- frenzy_lottery_tickets duplicates
DROP INDEX IF EXISTS idx_frenzy_lottery_tickets_user;

-- frenzy_participants duplicates
DROP INDEX IF EXISTS idx_frenzy_participants_user;

-- kyc_verifications duplicates
DROP INDEX IF EXISTS idx_kyc_verifications_otto_session;

-- liquidation_queue duplicates
DROP INDEX IF EXISTS idx_liquidation_queue_user;

-- locked_bonuses duplicates
DROP INDEX IF EXISTS idx_locked_bonuses_bonus_type;

-- lucky_draw_winners duplicates
DROP INDEX IF EXISTS idx_lucky_draw_winners_user;

-- mock_trading_accounts (keep unique constraint)
DROP INDEX IF EXISTS idx_mock_trading_accounts_user_id;

-- otto_verification_sessions (keep unique constraint)
DROP INDEX IF EXISTS idx_otto_sessions_session_id;

-- pending_copy_trades duplicates
DROP INDEX IF EXISTS idx_pending_copy_trades_admin_trader;

-- position_modifications duplicates
DROP INDEX IF EXISTS idx_position_modifications_position;

-- promotional_events (keep unique constraint)
DROP INDEX IF EXISTS idx_events_slug;

-- referral_commissions duplicates
DROP INDEX IF EXISTS idx_referral_commissions_transaction;

-- referral_rebates duplicates
DROP INDEX IF EXISTS idx_referral_rebates_transaction;

-- referral_stats (keep unique constraint)
DROP INDEX IF EXISTS idx_referral_stats_user_id;

-- risk_alerts duplicates
DROP INDEX IF EXISTS idx_risk_alerts_acknowledged_by;

-- risk_rules duplicates
DROP INDEX IF EXISTS idx_risk_rules_created_by;

-- risk_scores (keep unique constraint)
DROP INDEX IF EXISTS idx_risk_scores_user_id;

-- shark_cards duplicates
DROP INDEX IF EXISTS idx_shark_cards_application;

-- staff_permission_overrides duplicates
DROP INDEX IF EXISTS idx_staff_permission_overrides_permission;

-- support_attachments duplicates
DROP INDEX IF EXISTS idx_support_attachments_message;

-- support_canned_responses duplicates
DROP INDEX IF EXISTS idx_support_canned_responses_category;
DROP INDEX IF EXISTS idx_support_canned_responses_created_by;

-- support_messages duplicates
DROP INDEX IF EXISTS idx_support_messages_sender;

-- support_tickets duplicates
DROP INDEX IF EXISTS idx_support_tickets_category;

-- telegram_linking_codes (keep unique constraint)
DROP INDEX IF EXISTS idx_telegram_linking_codes_code;

-- terms_and_conditions (keep unique constraint)
DROP INDEX IF EXISTS idx_terms_version;

-- terms_pages duplicates and (keep unique constraint for slug)
DROP INDEX IF EXISTS idx_terms_pages_related_event;
DROP INDEX IF EXISTS idx_terms_slug;

-- trades duplicates
DROP INDEX IF EXISTS idx_trades_order;

-- user_bonuses duplicates
DROP INDEX IF EXISTS idx_user_bonuses_bonus_type;
DROP INDEX IF EXISTS idx_user_bonuses_locked_bonus;

-- user_fee_rebates (keep unique constraint)
DROP INDEX IF EXISTS idx_user_fee_rebates_user_id;

-- user_profiles (keep unique constraints)
DROP INDEX IF EXISTS idx_user_profiles_referral_code;
DROP INDEX IF EXISTS idx_user_profiles_username;

-- user_rewards duplicates (keep unique constraint)
DROP INDEX IF EXISTS idx_user_rewards_task_id;

-- user_risk_flags duplicates
DROP INDEX IF EXISTS idx_user_risk_flags_flagged_by;

-- user_segment_members duplicates
DROP INDEX IF EXISTS idx_user_segment_members_user;

-- user_sessions (keep unique constraint)
DROP INDEX IF EXISTS idx_user_sessions_user_id;

-- user_stakes duplicates
DROP INDEX IF EXISTS idx_user_stakes_product;

-- user_trusted_ips (keep unique constraint)
DROP INDEX IF EXISTS idx_user_trusted_ips_lookup;

-- user_vip_status (keep unique constraint)
DROP INDEX IF EXISTS idx_user_vip_status_user;

-- vip_daily_snapshots (keep unique constraint)
DROP INDEX IF EXISTS idx_vip_snapshots_user_date;

-- vip_levels (keep unique constraint)
DROP INDEX IF EXISTS idx_vip_levels_volume;

-- vip_refill_distributions duplicates
DROP INDEX IF EXISTS idx_vip_refill_distributions_transaction;

-- vip_retention_campaigns duplicates
DROP INDEX IF EXISTS idx_vip_retention_campaigns_email_template;

-- withdrawal_approvals duplicates
DROP INDEX IF EXISTS idx_withdrawal_approvals_reviewed_by;

-- admin_impersonation_sessions (keep unique constraint)
DROP INDEX IF EXISTS idx_impersonation_token;
