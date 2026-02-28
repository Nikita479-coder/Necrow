import { useState, useEffect, useCallback } from 'react';
import { MessageCircle, RefreshCw, CheckCircle, XCircle, AlertCircle, Ban, Send, ChevronDown, ChevronUp } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface NotificationStats {
  total_sent: number;
  total_failed: number;
  total_blocked: number;
  total_pending: number;
}

interface NotificationDetail {
  id: string;
  user_id: string;
  username: string;
  telegram_username: string | null;
  status: string;
  error_message: string | null;
  retry_count: number;
  created_at: string;
  sent_at: string | null;
}

interface TelegramNotificationStatusProps {
  pendingTradeId: string;
  onResendComplete?: () => void;
}

export default function TelegramNotificationStatus({
  pendingTradeId,
  onResendComplete
}: TelegramNotificationStatusProps) {
  const [stats, setStats] = useState<NotificationStats | null>(null);
  const [details, setDetails] = useState<NotificationDetail[]>([]);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState(false);
  const [resending, setResending] = useState<string | null>(null);
  const [resendingAll, setResendingAll] = useState(false);

  const loadNotificationData = useCallback(async () => {
    try {
      const { data: statsData } = await supabase.rpc('get_telegram_notification_stats', {
        p_pending_trade_id: pendingTradeId,
      });

      if (statsData && statsData.length > 0) {
        setStats(statsData[0]);
      }

      const { data: detailsData } = await supabase.rpc('get_telegram_notification_details', {
        p_pending_trade_id: pendingTradeId,
      });

      if (detailsData) {
        setDetails(detailsData);
      }
    } catch (err) {
      console.error('Error loading notification data:', err);
    } finally {
      setLoading(false);
    }
  }, [pendingTradeId]);

  useEffect(() => {
    loadNotificationData();
  }, [loadNotificationData]);

  const resendNotification = async (notificationId: string, userId?: string) => {
    setResending(notificationId);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/telegram-resend-notification`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            notification_id: notificationId,
            pending_trade_id: pendingTradeId,
            user_id: userId,
          }),
        }
      );

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to resend');
      }

      await loadNotificationData();
      onResendComplete?.();
    } catch (err) {
      console.error('Error resending notification:', err);
    } finally {
      setResending(null);
    }
  };

  const resendAllFailed = async () => {
    setResendingAll(true);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/telegram-resend-notification`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            pending_trade_id: pendingTradeId,
          }),
        }
      );

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to resend');
      }

      await loadNotificationData();
      onResendComplete?.();
    } catch (err) {
      console.error('Error resending all notifications:', err);
    } finally {
      setResendingAll(false);
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'sent':
        return <CheckCircle className="w-4 h-4 text-green-500" />;
      case 'failed':
        return <XCircle className="w-4 h-4 text-red-500" />;
      case 'blocked':
        return <Ban className="w-4 h-4 text-orange-500" />;
      case 'pending':
        return <AlertCircle className="w-4 h-4 text-yellow-500" />;
      default:
        return <AlertCircle className="w-4 h-4 text-gray-500" />;
    }
  };

  const getStatusBadge = (status: string) => {
    const colors: Record<string, string> = {
      sent: 'bg-green-500/20 text-green-400',
      failed: 'bg-red-500/20 text-red-400',
      blocked: 'bg-orange-500/20 text-orange-400',
      pending: 'bg-yellow-500/20 text-yellow-400',
    };

    return (
      <span className={`px-2 py-0.5 rounded text-xs font-medium ${colors[status] || 'bg-gray-500/20 text-gray-400'}`}>
        {status.charAt(0).toUpperCase() + status.slice(1)}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="bg-[#1e2329] rounded-xl p-4">
        <div className="animate-pulse space-y-3">
          <div className="h-5 bg-gray-700 rounded w-1/3" />
          <div className="h-4 bg-gray-700 rounded w-1/2" />
        </div>
      </div>
    );
  }

  if (!stats || (stats.total_sent === 0 && stats.total_failed === 0 && stats.total_blocked === 0 && stats.total_pending === 0)) {
    return (
      <div className="bg-[#1e2329] rounded-xl p-4">
        <div className="flex items-center gap-2 text-gray-400">
          <MessageCircle className="w-5 h-5" />
          <span>No Telegram notifications for this trade</span>
        </div>
      </div>
    );
  }

  const failedCount = stats.total_failed;
  const canResend = failedCount > 0;

  return (
    <div className="bg-[#1e2329] rounded-xl overflow-hidden">
      <div className="p-4">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <MessageCircle className="w-5 h-5 text-[#0088cc]" />
            <h3 className="font-semibold">Telegram Notifications</h3>
          </div>
          <button
            onClick={() => loadNotificationData()}
            className="p-1.5 text-gray-400 hover:text-white rounded transition-colors"
            title="Refresh"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>

        <div className="grid grid-cols-4 gap-3 mb-4">
          <div className="bg-[#2b3139] rounded-lg p-3 text-center">
            <div className="text-2xl font-bold text-green-400">{stats.total_sent}</div>
            <div className="text-xs text-gray-400">Sent</div>
          </div>
          <div className="bg-[#2b3139] rounded-lg p-3 text-center">
            <div className="text-2xl font-bold text-red-400">{stats.total_failed}</div>
            <div className="text-xs text-gray-400">Failed</div>
          </div>
          <div className="bg-[#2b3139] rounded-lg p-3 text-center">
            <div className="text-2xl font-bold text-orange-400">{stats.total_blocked}</div>
            <div className="text-xs text-gray-400">Blocked</div>
          </div>
          <div className="bg-[#2b3139] rounded-lg p-3 text-center">
            <div className="text-2xl font-bold text-yellow-400">{stats.total_pending}</div>
            <div className="text-xs text-gray-400">Pending</div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {canResend && (
            <button
              onClick={resendAllFailed}
              disabled={resendingAll}
              className="flex items-center gap-2 px-4 py-2 bg-[#0088cc] hover:bg-[#0077b5] text-white rounded-lg text-sm font-medium transition-colors disabled:opacity-50"
            >
              {resendingAll ? (
                <RefreshCw className="w-4 h-4 animate-spin" />
              ) : (
                <Send className="w-4 h-4" />
              )}
              Resend Failed ({failedCount})
            </button>
          )}

          <button
            onClick={() => setExpanded(!expanded)}
            className="flex items-center gap-2 px-4 py-2 bg-[#2b3139] hover:bg-[#363d47] text-white rounded-lg text-sm font-medium transition-colors ml-auto"
          >
            {expanded ? 'Hide' : 'Show'} Details
            {expanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>
        </div>
      </div>

      {expanded && details.length > 0 && (
        <div className="border-t border-gray-700">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-[#2b3139]">
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-400">User</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-400">Telegram</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-400">Status</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-400">Error</th>
                  <th className="px-4 py-2 text-left text-xs font-medium text-gray-400">Retries</th>
                  <th className="px-4 py-2 text-right text-xs font-medium text-gray-400">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-700">
                {details.map((detail) => (
                  <tr key={detail.id} className="hover:bg-[#2b3139]/50">
                    <td className="px-4 py-3 text-sm">
                      {detail.username || detail.user_id.slice(0, 8)}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-400">
                      {detail.telegram_username ? `@${detail.telegram_username}` : '-'}
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {getStatusIcon(detail.status)}
                        {getStatusBadge(detail.status)}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-400 max-w-xs truncate" title={detail.error_message || ''}>
                      {detail.error_message || '-'}
                    </td>
                    <td className="px-4 py-3 text-sm text-center">
                      {detail.retry_count}
                    </td>
                    <td className="px-4 py-3 text-right">
                      {(detail.status === 'failed' && detail.retry_count < 3) && (
                        <button
                          onClick={() => resendNotification(detail.id, detail.user_id)}
                          disabled={resending === detail.id}
                          className="flex items-center gap-1 px-2 py-1 text-xs bg-[#0088cc] hover:bg-[#0077b5] text-white rounded transition-colors disabled:opacity-50 ml-auto"
                        >
                          {resending === detail.id ? (
                            <RefreshCw className="w-3 h-3 animate-spin" />
                          ) : (
                            <Send className="w-3 h-3" />
                          )}
                          Resend
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
