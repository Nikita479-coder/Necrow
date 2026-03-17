import { X, Bell, ChevronRight } from 'lucide-react';
import { useEffect, useState, useRef, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';

interface Notification {
  id: string;
  type: string;
  title: string;
  message: string;
  data: any;
  read: boolean;
  created_at: string;
  redirect_url: string | null;
}

interface NotificationsPanelProps {
  isOpen: boolean;
  onClose: () => void;
  onNavigate?: (path: string) => void;
}

export default function NotificationsPanel({ isOpen, onClose }: NotificationsPanelProps) {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();
  const dropdownRef = useRef<HTMLDivElement>(null);

  const handleNotificationClick = useCallback((notification: Notification, e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();

    const url = notification.redirect_url;
    if (!url) {
      onClose();
      return;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      window.open(url, '_blank', 'noopener,noreferrer');
      onClose();
    } else {
      const path = url.startsWith('/') ? url.slice(1) : url;
      window.dispatchEvent(new CustomEvent('app-navigate', { detail: { page: path } }));
      setTimeout(() => onClose(), 50);
    }
  }, [onClose]);

  const getDefaultRedirectUrl = (type: string): string | null => {
    switch (type) {
      case 'referral_payout':
      case 'referral_commission':
        return 'referral';
      case 'affiliate_payout':
      case 'affiliate_commission':
        return 'affiliate';
      case 'trade_executed':
      case 'position_closed':
      case 'position_tp_hit':
      case 'position_sl_hit':
      case 'tp_triggered':
      case 'sl_triggered':
      case 'liquidation':
        return 'futures';
      case 'copy_trade':
      case 'pending_copy_trade':
      case 'copy_trade_closed':
        return 'copytrading';
      case 'kyc_update':
      case 'kyc_approved':
      case 'kyc_rejected':
        return 'kyc';
      case 'shark_card_application':
      case 'shark_card_approved':
      case 'shark_card_declined':
      case 'shark_card_issued':
        return 'wallet';
      case 'deposit_completed':
      case 'deposit_pending':
        return 'deposit';
      case 'withdrawal_approved':
      case 'withdrawal_rejected':
      case 'withdrawal_pending':
      case 'withdrawal_completed':
        return 'withdraw';
      case 'vip_upgrade':
      case 'vip_downgrade':
        return 'vip';
      case 'bonus':
      case 'reward':
        return 'rewardshub';
      case 'staking_complete':
      case 'staking_reward':
        return 'earn';
      case 'account_update':
        return 'profile';
      default:
        return null;
    }
  };

  useEffect(() => {
    if (isOpen && user) {
      loadNotifications();
      markAllAsRead();

      const subscription = supabase
        .channel('notifications')
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user.id}`
        }, (payload) => {
          setNotifications(prev => [payload.new as Notification, ...prev]);
        })
        .subscribe();

      return () => {
        subscription.unsubscribe();
      };
    }
  }, [isOpen, user]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Node;
      const notificationButton = document.querySelector('[data-notification-button]');
      const notificationButtonMobile = document.querySelector('[data-notification-button-mobile]');

      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(target) &&
        (!notificationButton || !notificationButton.contains(target)) &&
        (!notificationButtonMobile || !notificationButtonMobile.contains(target))
      ) {
        onClose();
      }
    };

    if (isOpen) {
      setTimeout(() => {
        document.addEventListener('mousedown', handleClickOutside);
      }, 0);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen, onClose]);

  const loadNotifications = async () => {
    if (!user) return;

    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(20);

      if (error) throw error;
      setNotifications(data || []);
    } catch (error) {
      console.error('Error loading notifications:', error);
    } finally {
      setLoading(false);
    }
  };

  const markAllAsRead = async () => {
    if (!user) return;

    try {
      const { error } = await supabase
        .from('notifications')
        .update({ read: true })
        .eq('user_id', user.id)
        .eq('read', false);

      if (error) throw error;

      setNotifications(prev =>
        prev.map(n => ({ ...n, read: true }))
      );
    } catch (error) {
      console.error('Error marking all as read:', error);
    }
  };

  const deleteNotification = async (notificationId: string) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);

      if (error) throw error;

      setNotifications(prev => prev.filter(n => n.id !== notificationId));
    } catch (error) {
      console.error('Error deleting notification:', error);
    }
  };

  const formatTime = (timestamp: string) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) return 'Just now';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
    if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d ago`;

    return date.toLocaleDateString();
  };

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'referral_payout':
      case 'referral_commission':
        return '💰';
      case 'reward':
      case 'bonus':
        return '🎁';
      case 'affiliate_payout':
      case 'affiliate_commission':
        return '💵';
      case 'trade_executed':
        return '📈';
      case 'kyc_update':
      case 'kyc_approved':
        return '✅';
      case 'kyc_rejected':
        return '❌';
      case 'shark_card_application':
        return '💳';
      case 'shark_card_approved':
        return '✅';
      case 'shark_card_declined':
        return '❌';
      case 'shark_card_issued':
        return '🎉';
      case 'deposit_completed':
        return '💵';
      case 'withdrawal_approved':
      case 'withdrawal_completed':
        return '✅';
      case 'vip_upgrade':
        return '👑';
      case 'system':
        return '📢';
      default:
        return '🔔';
    }
  };

  if (!isOpen) return null;

  return (
    <div
      ref={dropdownRef}
      className="fixed md:absolute top-[60px] md:top-12 right-2 md:right-0 left-2 md:left-auto w-auto md:w-96 max-h-[calc(100vh-80px)] md:max-h-[600px] bg-[#0b0e11] md:bg-[#0b0e11]/95 md:backdrop-blur-xl border border-[#f0b90b]/20 rounded-lg shadow-2xl overflow-hidden z-[100] animate-fade-in flex flex-col"
    >
      <div className="flex items-center justify-between p-4 border-b border-[#f0b90b]/20 bg-[#0b0e11] flex-shrink-0">
        <div className="flex items-center gap-2">
          <Bell className="w-5 h-5 text-[#f0b90b]" />
          <h3 className="text-white font-semibold">Notifications</h3>
        </div>
        <button
          onClick={onClose}
          className="md:hidden text-gray-400 hover:text-white p-1 transition-colors"
        >
          <X className="w-5 h-5" />
        </button>
      </div>

      <div className="flex-1 max-h-[calc(100vh-140px)] md:max-h-[500px] overflow-y-auto overscroll-contain">
        {loading ? (
          <div className="flex items-center justify-center py-8">
            <div className="w-6 h-6 border-2 border-[#f0b90b] border-t-transparent rounded-full animate-spin" />
          </div>
        ) : notifications.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-8 text-center px-4">
            <Bell className="w-12 h-12 text-gray-600 mb-3" />
            <p className="text-gray-400 text-sm">No notifications yet</p>
            <p className="text-gray-500 text-xs mt-1">You'll be notified about important events</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-800/50">
            {notifications.map((notification) => {
              const redirectUrl = notification.redirect_url || getDefaultRedirectUrl(notification.type);
              const isClickable = !!redirectUrl;

              return (
                <div
                  key={notification.id}
                  role={isClickable ? "button" : undefined}
                  tabIndex={isClickable ? 0 : undefined}
                  onMouseDown={(e) => {
                    if (isClickable) {
                      e.stopPropagation();
                    }
                  }}
                  onClick={(e) => {
                    if (isClickable) {
                      handleNotificationClick({ ...notification, redirect_url: redirectUrl }, e);
                    }
                  }}
                  className={`p-3 transition-all hover:bg-white/5 ${isClickable ? 'cursor-pointer' : ''}`}
                >
                  <div className="flex items-start gap-3">
                    <span className="text-2xl flex-shrink-0">
                      {getNotificationIcon(notification.type)}
                    </span>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-2">
                        <h4 className="text-white text-sm font-semibold">
                          {notification.title}
                        </h4>
                        {isClickable && (
                          <ChevronRight className="w-4 h-4 text-gray-500 flex-shrink-0" />
                        )}
                      </div>
                      <p className="text-gray-400 text-xs mt-1 whitespace-pre-wrap">
                        {notification.message}
                      </p>
                      <div className="flex items-center justify-between mt-2">
                        <span className="text-gray-500 text-xs">
                          {formatTime(notification.created_at)}
                        </span>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            deleteNotification(notification.id);
                          }}
                          className="text-gray-500 hover:text-red-400 p-1 transition-colors"
                          title="Delete"
                        >
                          <X className="w-3 h-3" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
