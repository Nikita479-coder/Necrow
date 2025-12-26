import { useState, useEffect } from 'react';
import { Activity, TrendingUp, DollarSign, LogIn, LogOut, ArrowUpDown, Gift, Users } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
}

interface ActivityLog {
  id: string;
  activity_type: string;
  activity_details: any;
  ip_address: string;
  created_at: string;
}

export default function AdminUserActivity({ userId }: Props) {
  const [activities, setActivities] = useState<ActivityLog[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadActivities();
    const interval = setInterval(loadActivities, 5000);
    return () => clearInterval(interval);
  }, [userId]);

  const loadActivities = async () => {
    try {
      const { data, error } = await supabase.rpc('admin_get_user_activity', {
        p_user_id: userId,
        p_limit: 100
      });

      if (error) throw error;
      setActivities(data || []);
    } catch (error) {
      console.error('Error loading activities:', error);
    } finally {
      setLoading(false);
    }
  };

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'login':
        return <LogIn className="w-4 h-4 text-green-400" />;
      case 'logout':
        return <LogOut className="w-4 h-4 text-gray-400" />;
      case 'trade':
      case 'futures_order':
        return <TrendingUp className="w-4 h-4 text-blue-400" />;
      case 'deposit':
        return <DollarSign className="w-4 h-4 text-green-400" />;
      case 'withdraw':
        return <DollarSign className="w-4 h-4 text-red-400" />;
      case 'transfer':
      case 'wallet_transfer':
        return <ArrowUpDown className="w-4 h-4 text-yellow-400" />;
      case 'reward_claim':
        return <Gift className="w-4 h-4 text-purple-400" />;
      case 'copy_trading':
        return <Users className="w-4 h-4 text-cyan-400" />;
      case 'admin_position_edit':
        return <Activity className="w-4 h-4 text-orange-400" />;
      default:
        return <Activity className="w-4 h-4 text-gray-400" />;
    }
  };

  const formatActivityMessage = (activity: ActivityLog) => {
    const details = activity.activity_details || {};

    switch (activity.activity_type) {
      case 'login':
        return 'User logged in';
      case 'logout':
        return 'User logged out';
      case 'trade':
      case 'futures_order':
        return `Placed ${details.side || ''} order for ${details.pair || ''} at $${details.price || 0}`;
      case 'deposit':
        return `Deposited $${details.amount || 0} ${details.currency || ''}`;
      case 'withdraw':
        return `Withdrew $${details.amount || 0} ${details.currency || ''}`;
      case 'transfer':
      case 'wallet_transfer':
        return `Transferred $${details.amount || 0} from ${details.from_wallet || ''} to ${details.to_wallet || ''}`;
      case 'reward_claim':
        return `Claimed reward: $${details.amount || 0}`;
      case 'copy_trading':
        return `${details.action || 'Updated'} copy trading with ${details.trader_name || 'trader'}`;
      case 'admin_position_edit':
        return `Admin edited position - ${details.edit_type === 'pnl_to_entry' ? 'Set PnL to $' + details.new_pnl : 'Entry price updated to $' + details.new_entry_price}`;
      default:
        return activity.activity_type.replace(/_/g, ' ');
    }
  };

  const getTimeAgo = (timestamp: string) => {
    const now = new Date();
    const time = new Date(timestamp);
    const diffMs = now.getTime() - time.getTime();
    const diffSec = Math.floor(diffMs / 1000);
    const diffMin = Math.floor(diffSec / 60);
    const diffHour = Math.floor(diffMin / 60);
    const diffDay = Math.floor(diffHour / 24);

    if (diffSec < 60) return `${diffSec}s ago`;
    if (diffMin < 60) return `${diffMin}m ago`;
    if (diffHour < 24) return `${diffHour}h ago`;
    return `${diffDay}d ago`;
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-bold text-white">Live Activity Feed</h2>
        <span className="text-sm text-gray-400">Auto-refreshes every 5s</span>
      </div>

      {activities.length === 0 ? (
        <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
          <Activity className="w-12 h-12 text-gray-600 mx-auto mb-3" />
          <p className="text-gray-400">No activity recorded yet</p>
        </div>
      ) : (
        <div className="bg-[#0b0e11] rounded-xl border border-gray-800 divide-y divide-gray-800 max-h-[600px] overflow-y-auto">
          {activities.map((activity) => (
            <div key={activity.id} className="p-4 hover:bg-[#1a1d24]/30 transition-colors">
              <div className="flex items-start gap-3">
                <div className="mt-1 p-2 bg-[#1a1d24] rounded-lg">
                  {getActivityIcon(activity.activity_type)}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2 mb-1">
                    <p className="text-white font-medium text-sm">
                      {formatActivityMessage(activity)}
                    </p>
                    <span className="text-xs text-gray-500 whitespace-nowrap">
                      {getTimeAgo(activity.created_at)}
                    </span>
                  </div>
                  <div className="flex items-center gap-3 text-xs text-gray-400">
                    <span className="font-mono">{activity.activity_type}</span>
                    {activity.ip_address && (
                      <span>IP: {activity.ip_address}</span>
                    )}
                    <span>{new Date(activity.created_at).toLocaleString()}</span>
                  </div>
                  {activity.activity_details && Object.keys(activity.activity_details).length > 0 && (
                    <details className="mt-2">
                      <summary className="text-xs text-gray-500 cursor-pointer hover:text-gray-400">
                        View details
                      </summary>
                      <pre className="mt-2 p-2 bg-[#0b0e11] rounded text-xs text-gray-300 overflow-x-auto">
                        {JSON.stringify(activity.activity_details, null, 2)}
                      </pre>
                    </details>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
