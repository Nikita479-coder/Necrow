import { useState, useEffect } from 'react';
import { Users, Copy, Gift } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
}

export default function AdminUserCopyTrading({ userId }: Props) {
  const [copying, setCopying] = useState<any[]>([]);
  const [copiers, setCopiers] = useState<any[]>([]);
  const [userCredits, setUserCredits] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadCopyTradingData();
    loadUserCredits();
  }, [userId]);

  const loadUserCredits = async () => {
    try {
      const { data } = await supabase.rpc('get_user_copy_trading_credits', {
        p_user_id: userId
      });
      setUserCredits(data);
    } catch (err) {
      console.error('Error loading credits:', err);
    }
  };

  const loadCopyTradingData = async () => {
    setLoading(true);
    try {
      const [copyingRes, copiersRes] = await Promise.all([
        supabase
          .from('copy_relationships')
          .select(`
            *,
            traders (
              name,
              avatar
            )
          `)
          .eq('follower_id', userId)
          .eq('status', 'active'),
        supabase
          .from('copy_relationships')
          .select(`
            *,
            user_profiles!copy_relationships_follower_id_fkey (
              username,
              full_name
            )
          `)
          .eq('trader_id', userId)
          .eq('status', 'active')
      ]);

      console.log('Copying:', copyingRes);
      console.log('Copiers:', copiersRes);

      setCopying(copyingRes.data || []);
      setCopiers(copiersRes.data || []);
    } catch (error) {
      console.error('Error loading copy trading data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center gap-3 mb-4">
          <Gift className="w-6 h-6 text-[#0ecb81]" />
          <h2 className="text-xl font-bold text-white">Copy Trading Credits</h2>
        </div>

        {userCredits && (userCredits.available_credit > 0 || userCredits.locked_credit > 0) ? (
          <div className="bg-[#0b0e11] rounded-xl p-5 border border-gray-800 mb-4">
            <div className="grid grid-cols-3 gap-4">
              <div>
                <p className="text-xs text-gray-400 mb-1">Available Credit</p>
                <p className="text-[#0ecb81] font-bold text-lg">${(userCredits.available_credit || 0).toFixed(2)}</p>
              </div>
              <div>
                <p className="text-xs text-gray-400 mb-1">Locked in Copy Trading</p>
                <p className="text-[#f0b90b] font-bold text-lg">${(userCredits.locked_credit || 0).toFixed(2)}</p>
              </div>
              <div>
                <p className="text-xs text-gray-400 mb-1">Total Credits</p>
                <p className="text-white font-bold text-lg">${(userCredits.total_credit || 0).toFixed(2)}</p>
              </div>
            </div>
            {userCredits.credits && userCredits.credits.length > 0 && (
              <div className="mt-3 pt-3 border-t border-gray-800 space-y-2">
                {userCredits.credits.map((credit: any, i: number) => (
                  <div key={i} className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-medium ${
                        credit.status === 'available' ? 'bg-green-500/20 text-green-400' :
                        credit.status === 'locked_in_relationship' ? 'bg-yellow-500/20 text-yellow-400' :
                        credit.status === 'forfeited' ? 'bg-red-500/20 text-red-400' :
                        'bg-gray-500/20 text-gray-400'
                      }`}>
                        {credit.status.replace(/_/g, ' ')}
                      </span>
                      <span className="text-white">${credit.remaining_amount.toFixed(2)} / ${credit.amount.toFixed(2)}</span>
                    </div>
                    <span className="text-gray-500">
                      {credit.notes || 'No notes'} | Lock: {credit.lock_days}d
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div className="bg-[#0b0e11] rounded-xl p-5 border border-gray-800 text-center mb-4">
            <p className="text-gray-400 text-sm">No copy trading credits</p>
          </div>
        )}
      </div>

      <div>
        <div className="flex items-center gap-3 mb-4">
          <Copy className="w-6 h-6 text-[#f0b90b]" />
          <h2 className="text-xl font-bold text-white">Traders Being Copied</h2>
        </div>

        {copying.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">User is not copying any traders</p>
          </div>
        ) : (
          <div className="space-y-3">
            {copying.map((relationship) => (
              <div key={relationship.id} className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="text-2xl">{relationship.traders?.avatar || '👤'}</span>
                      <h3 className="text-lg font-bold text-white">
                        {relationship.traders?.name || 'Unknown Trader'}
                      </h3>
                    </div>
                  </div>
                  <span className={`px-3 py-1 rounded-lg text-sm font-medium ${
                    relationship.is_mock
                      ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                      : 'bg-green-500/20 text-green-400 border border-green-500/30'
                  }`}>
                    {relationship.is_mock ? 'Mock Trading' : 'Real Trading'}
                  </span>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Allocation</p>
                    <p className="text-white font-bold">
                      {relationship.allocation_percentage}%
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Leverage</p>
                    <p className="text-white font-bold">{relationship.leverage}x</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Total P&L</p>
                    <p className={`font-bold ${parseFloat(relationship.total_pnl) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                      {parseFloat(relationship.total_pnl) >= 0 ? '+' : ''}${parseFloat(relationship.total_pnl).toFixed(2)}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Started</p>
                    <p className="text-white text-sm">
                      {new Date(relationship.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div>
        <div className="flex items-center gap-3 mb-4">
          <Users className="w-6 h-6 text-[#f0b90b]" />
          <h2 className="text-xl font-bold text-white">Users Copying This User</h2>
        </div>

        {copiers.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">No users are copying this trader</p>
          </div>
        ) : (
          <div className="space-y-3">
            {copiers.map((relationship) => (
              <div key={relationship.id} className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="text-lg font-bold text-white mb-1">
                      {relationship.user_profiles?.username || 'Unknown User'}
                    </h3>
                    <p className="text-sm text-gray-400">
                      {relationship.user_profiles?.full_name || 'N/A'}
                    </p>
                  </div>
                  <span className={`px-3 py-1 rounded-lg text-sm font-medium ${
                    relationship.is_mock
                      ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                      : 'bg-green-500/20 text-green-400 border border-green-500/30'
                  }`}>
                    {relationship.is_mock ? 'Mock Trading' : 'Real Trading'}
                  </span>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Allocation</p>
                    <p className="text-white font-bold">
                      {relationship.allocation_percentage}%
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Leverage</p>
                    <p className="text-white font-bold">{relationship.leverage}x</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Their P&L</p>
                    <p className={`font-bold ${parseFloat(relationship.total_pnl) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                      {parseFloat(relationship.total_pnl) >= 0 ? '+' : ''}${parseFloat(relationship.total_pnl).toFixed(2)}
                    </p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-400 mb-1">Started</p>
                    <p className="text-white text-sm">
                      {new Date(relationship.created_at).toLocaleDateString()}
                    </p>
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
