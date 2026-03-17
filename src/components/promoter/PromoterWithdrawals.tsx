import { useState, useEffect } from 'react';
import { ArrowUpFromLine, Filter, X } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Withdrawal {
  id: string;
  user_id: string;
  email: string;
  username: string | null;
  full_name: string | null;
  currency: string;
  amount: number;
  fee: number;
  receive_amount: number;
  status: string;
  address: string;
  network: string | null;
  tx_hash: string | null;
  created_at: string;
  updated_at: string;
  confirmed_at: string | null;
}

export default function PromoterWithdrawals() {
  const [withdrawals, setWithdrawals] = useState<Withdrawal[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState('all');
  const [showFilters, setShowFilters] = useState(false);
  const [total, setTotal] = useState(0);

  useEffect(() => {
    loadWithdrawals();
  }, [filterStatus]);

  const loadWithdrawals = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('promoter_get_withdrawals', {
        p_status: filterStatus === 'all' ? null : filterStatus,
        p_limit: 200,
        p_offset: 0,
      });
      if (error) throw error;
      if (data?.success) {
        setWithdrawals(data.withdrawals || []);
        setTotal(data.total || 0);
      }
    } catch (err) {
      console.error('Failed to load withdrawals:', err);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'bg-emerald-500/20 text-emerald-400';
      case 'processing': return 'bg-blue-500/20 text-blue-400';
      case 'pending': return 'bg-yellow-500/20 text-yellow-400';
      case 'failed':
      case 'rejected': return 'bg-red-500/20 text-red-400';
      default: return 'bg-gray-500/20 text-gray-400';
    }
  };

  const completedWithdrawals = withdrawals.filter(w => w.status === 'completed');
  const totalCompleted = completedWithdrawals.reduce((sum, w) => sum + Number(w.amount), 0);
  const pendingCount = withdrawals.filter(w => w.status === 'pending' || w.status === 'processing').length;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-white">Withdrawals</h2>
          <p className="text-sm text-gray-400">{total} total withdrawals from your tree users</p>
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-colors ${
            showFilters ? 'bg-[#f0b90b] text-black' : 'bg-[#1a1d24] text-gray-400 hover:text-white border border-gray-800'
          }`}
        >
          {showFilters ? <X className="w-4 h-4" /> : <Filter className="w-4 h-4" />}
          Filters
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Completed</p>
          <p className="text-lg font-bold text-emerald-400">${totalCompleted.toFixed(2)}</p>
          <p className="text-xs text-gray-500">{completedWithdrawals.length} withdrawals</p>
        </div>
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Pending/Processing</p>
          <p className="text-lg font-bold text-yellow-400">{pendingCount}</p>
          <p className="text-xs text-gray-500">awaiting action</p>
        </div>
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Total Records</p>
          <p className="text-lg font-bold text-white">{total}</p>
          <p className="text-xs text-gray-500">all statuses</p>
        </div>
      </div>

      {showFilters && (
        <div className="bg-[#1a1d24] border border-gray-800 rounded-xl p-4">
          <label className="text-xs text-gray-400 mb-1 block">Status</label>
          <select
            value={filterStatus}
            onChange={e => setFilterStatus(e.target.value)}
            className="w-full max-w-xs bg-[#0b0e11] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
          >
            <option value="all">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="processing">Processing</option>
            <option value="completed">Completed</option>
            <option value="failed">Failed</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>
      )}

      {loading ? (
        <div className="text-center py-12">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
        </div>
      ) : withdrawals.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <ArrowUpFromLine className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No withdrawals found</p>
        </div>
      ) : (
        <div className="bg-[#1a1d24] rounded-xl border border-gray-800 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-800">
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">User</th>
                  <th className="text-right py-3 px-4 text-xs font-medium text-gray-400 uppercase">Amount</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Currency</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Status</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Address</th>
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Date</th>
                </tr>
              </thead>
              <tbody>
                {withdrawals.map(w => (
                  <tr key={w.id} className="border-b border-gray-800/50 hover:bg-[#0b0e11] transition-colors">
                    <td className="py-3 px-4">
                      <div className="text-sm text-white">{w.full_name || w.username || 'N/A'}</div>
                      <div className="text-xs text-gray-500">{w.email}</div>
                    </td>
                    <td className="py-3 px-4 text-right">
                      <span className="text-sm font-medium text-white">${Number(w.amount).toFixed(2)}</span>
                      {Number(w.fee) > 0 && (
                        <div className="text-xs text-gray-500">fee: ${Number(w.fee).toFixed(2)}</div>
                      )}
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-xs text-gray-300 uppercase">{w.currency}</span>
                    </td>
                    <td className="py-3 px-4">
                      <span className={`text-xs px-2 py-1 rounded-md font-medium ${getStatusColor(w.status)}`}>
                        {w.status}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-xs text-gray-400 font-mono truncate block max-w-[120px]" title={w.address}>
                        {w.address ? w.address.slice(0, 8) + '...' + w.address.slice(-6) : '-'}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-xs text-gray-400">{new Date(w.created_at).toLocaleString()}</span>
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
