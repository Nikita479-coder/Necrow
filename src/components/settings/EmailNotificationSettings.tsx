import { useState, useEffect } from 'react';
import { Mail, Bell } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface EmailPreference {
  notification_type: string;
  email_enabled: boolean;
}

export default function EmailNotificationSettings() {
  const [emailPreferences, setEmailPreferences] = useState<EmailPreference[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();

  useEffect(() => {
    if (user) {
      loadEmailPreferences();
    }
  }, [user]);

  const loadEmailPreferences = async () => {
    if (!user) return;

    try {
      setLoading(true);
      const { data, error } = await supabase
        .rpc('get_email_notification_preferences', { p_user_id: user.id });

      if (error) throw error;
      setEmailPreferences(data || []);
    } catch (error) {
      console.error('Error loading email preferences:', error);
    } finally {
      setLoading(false);
    }
  };

  const toggleEmailPreference = async (notificationType: string, currentValue: boolean) => {
    if (!user) return;

    try {
      const { error } = await supabase
        .rpc('update_email_notification_preference', {
          p_user_id: user.id,
          p_notification_type: notificationType,
          p_email_enabled: !currentValue
        });

      if (error) throw error;

      setEmailPreferences(prev =>
        prev.map(pref =>
          pref.notification_type === notificationType
            ? { ...pref, email_enabled: !currentValue }
            : pref
        )
      );
    } catch (error) {
      console.error('Error updating email preference:', error);
    }
  };

  const notificationCategories = {
    'Trading': [
      { type: 'trade_executed', label: 'Trade Executed' },
      { type: 'position_closed', label: 'Position Closed' },
      { type: 'position_tp_hit', label: 'Take Profit Hit' },
      { type: 'position_sl_hit', label: 'Stop Loss Hit' },
      { type: 'liquidation', label: 'Liquidation' }
    ],
    'Copy Trading': [
      { type: 'pending_trade', label: 'Pending Trade Request' },
      { type: 'trade_accepted', label: 'Trade Accepted' },
      { type: 'trade_rejected', label: 'Trade Rejected' }
    ],
    'Account': [
      { type: 'kyc_update', label: 'KYC Update' },
      { type: 'account_update', label: 'Account Update' },
      { type: 'vip_upgrade', label: 'VIP Upgrade' },
      { type: 'vip_downgrade', label: 'VIP Downgrade' }
    ],
    'Financial': [
      { type: 'withdrawal_approved', label: 'Withdrawal Approved' },
      { type: 'withdrawal_rejected', label: 'Withdrawal Rejected' },
      { type: 'withdrawal_completed', label: 'Withdrawal Completed' },
      { type: 'withdrawal_blocked', label: 'Withdrawal Blocked' },
      { type: 'withdrawal_unblocked', label: 'Withdrawal Unblocked' },
      { type: 'deposit_completed', label: 'Deposit Completed' },
      { type: 'referral_payout', label: 'Referral Payout' }
    ],
    'Shark Card & VIP': [
      { type: 'shark_card_application', label: 'Shark Card Application' },
      { type: 'shark_card_approved', label: 'Shark Card Approved' },
      { type: 'shark_card_declined', label: 'Shark Card Declined' },
      { type: 'shark_card_issued', label: 'Shark Card Issued' },
      { type: 'vip_refill', label: 'VIP Weekly Refill' }
    ],
    'System': [
      { type: 'system', label: 'System Notifications' }
    ]
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="w-8 h-8 border-2 border-[#f0b90b] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-start gap-3 p-4 bg-blue-500/10 border border-blue-500/20 rounded-lg">
        <Mail className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
        <div>
          <h3 className="text-white font-semibold mb-1">Email Notification Preferences</h3>
          <p className="text-sm text-gray-300">
            Choose which notifications you want to receive via email. In-app notifications will always be sent regardless of these settings.
          </p>
        </div>
      </div>

      {Object.entries(notificationCategories).map(([category, types]) => (
        <div key={category} className="space-y-3">
          <div className="flex items-center gap-2">
            <Bell className="w-4 h-4 text-[#f0b90b]" />
            <h4 className="text-white font-semibold text-sm">{category}</h4>
          </div>
          <div className="space-y-2 pl-6">
            {types.map(({ type, label }) => {
              const preference = emailPreferences.find(p => p.notification_type === type);
              const isEnabled = preference?.email_enabled ?? true;

              return (
                <div
                  key={type}
                  className="flex items-center justify-between p-3 bg-white/5 rounded-lg hover:bg-white/10 transition-colors border border-gray-800/50"
                >
                  <span className="text-sm text-gray-300">{label}</span>
                  <button
                    onClick={() => toggleEmailPreference(type, isEnabled)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                      isEnabled ? 'bg-[#f0b90b]' : 'bg-gray-600'
                    }`}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                        isEnabled ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
