import { X, Bell } from 'lucide-react';
import { useEffect, useState, useRef } from 'react';
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
}

interface NotificationsPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function NotificationsPanel({ isOpen, onClose }: NotificationsPanelProps) {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();
  const dropdownRef = useRef<HTMLDivElement>(null);

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

      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(target) &&
        notificationButton &&
        !notificationButton.contains(target)
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
        return '💰';
      case 'trade_executed':
        return '📈';
      case 'kyc_update':
        return '✅';
      case 'shark_card_application':
        return '💳';
      case 'shark_card_approved':
        return '✅';
      case 'shark_card_declined':
        return '❌';
      case 'shark_card_issued':
        return '🎉';
      default:
        return '🔔';
    }
  };

  if (!isOpen) return null;

  return (
    <div
      ref={dropdownRef}
      className="absolute top-12 right-0 w-96 max-h-[600px] bg-[#0b0e11]/95 backdrop-blur-xl border border-[#f0b90b]/20 rounded-lg shadow-2xl overflow-hidden z-50 animate-fade-in"
    >
      <div className="flex items-center justify-between p-4 border-b border-[#f0b90b]/20">
        <div className="flex items-center gap-2">
          <Bell className="w-5 h-5 text-[#f0b90b]" />
          <h3 className="text-white font-semibold">Notifications</h3>
        </div>
      </div>

      <div className="max-h-[500px] overflow-y-auto">
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
            {notifications.map((notification) => (
              <div
                key={notification.id}
                className="p-3 transition-all hover:bg-white/5"
              >
                <div className="flex items-start gap-3">
                  <span className="text-2xl flex-shrink-0">
                    {getNotificationIcon(notification.type)}
                  </span>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-2">
                      <h4 className="text-white text-sm font-semibold truncate">
                        {notification.title}
                      </h4>
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
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
