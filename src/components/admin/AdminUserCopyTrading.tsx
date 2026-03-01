import { useState, useEffect } from 'react';
import { Users, TrendingUp, TrendingDown, Copy } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Props {
  userId: string;
}

export default function AdminUserCopyTrading({ userId }: Props) {
  const [copying, setCopying] = useState<any[]>([]);
  const [copiers, setCopiers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadCopyTradingData();
  }, [userId]);

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
