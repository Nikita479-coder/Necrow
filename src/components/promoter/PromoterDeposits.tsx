import { useState, useEffect } from 'react';
import { ArrowDownToLine, Filter, X } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Deposit {
  payment_id: string;
  user_id: string;
  user_email: string;
  user_name: string;
  price_amount: number;
  price_currency: string;
  pay_amount: number;
  pay_currency: string;
  status: string;
  actually_paid: number;
  outcome_amount: number;
  created_at: string;
  completed_at: string | null;
  wallet_type: string;
}

const STATUS_OPTIONS = [
  { value: 'all', label: 'All Statuses' },
  { value: 'waiting', label: 'Waiting' },
  { value: 'confirming', label: 'Confirming' },
  { value: 'sending', label: 'Sending' },
  { value: 'finished', label: 'Finished' },
  { value: 'completed', label: 'Completed' },
  { value: 'partially_paid', label: 'Partially Paid' },
  { value: 'overpaid', label: 'Overpaid' },
  { value: 'failed', label: 'Failed' },
  { value: 'expired', label: 'Expired' },
];

export default function PromoterDeposits() {
  const [deposits, setDeposits] = useState<Deposit[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState('all');
  const [showFilters, setShowFilters] = useState(false);
  const [total, setTotal] = useState(0);

  useEffect(() => {
    loadDeposits();
  }, [filterStatus]);

  const loadDeposits = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('promoter_get_deposits', {
        p_status: filterStatus === 'all' ? null : filterStatus,
        p_limit: 200,
        p_offset: 0,
      });
      if (error) throw error;
      if (data?.success) {
        setDeposits(data.deposits || []);
        setTotal(data.total || 0);
      }
    } catch (err) {
      console.error('Failed to load deposits:', err);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'finished':
      case 'completed':
        return 'bg-emerald-500/20 text-emerald-400';
      case 'overpaid':
      case 'partially_paid':
        return 'bg-blue-500/20 text-blue-400';
      case 'waiting':
      case 'confirming':
      case 'sending':
        return 'bg-yellow-500/20 text-yellow-400';
      case 'failed':
      case 'expired':
      case 'refunded':
        return 'bg-red-500/20 text-red-400';
      default:
        return 'bg-gray-500/20 text-gray-400';
    }
  };

  const completedDeposits = deposits.filter(d =>
    ['finished', 'completed', 'partially_paid', 'overpaid'].includes(d.status)
  );
  const totalCompleted = completedDeposits.reduce((sum, d) => sum + Number(d.price_amount), 0);
  const pendingDeposits = deposits.filter(d => ['waiting', 'confirming', 'sending'].includes(d.status));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-white">Deposits</h2>
          <p className="text-sm text-gray-400">{total} total deposits from your tree users</p>
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
          <p className="text-xs text-gray-500">{completedDeposits.length} deposits</p>
        </div>
        <div className="bg-[#1a1d24] rounded-xl p-4 border border-gray-800">
          <p className="text-xs text-gray-400 mb-1">Pending</p>
          <p className="text-lg font-bold text-yellow-400">{pendingDeposits.length}</p>
          <p className="text-xs text-gray-500">awaiting confirmation</p>
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
            {STATUS_OPTIONS.map(s => (
              <option key={s.value} value={s.value}>{s.label}</option>
            ))}
          </select>
        </div>
      )}

      {loading ? (
        <div className="text-center py-12">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
        </div>
      ) : deposits.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <ArrowDownToLine className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No deposits found</p>
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
                  <th className="text-left py-3 px-4 text-xs font-medium text-gray-400 uppercase">Date</th>
                </tr>
              </thead>
              <tbody>
                {deposits.map(d => (
                  <tr key={d.payment_id} className="border-b border-gray-800/50 hover:bg-[#0b0e11] transition-colors">
                    <td className="py-3 px-4">
                      <div className="text-sm text-white">{d.user_name}</div>
                      <div className="text-xs text-gray-500">{d.user_email}</div>
                    </td>
                    <td className="py-3 px-4 text-right">
                      <span className="text-sm font-medium text-white">${Number(d.price_amount).toFixed(2)}</span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-xs text-gray-300 uppercase">{d.pay_currency}</span>
                    </td>
                    <td className="py-3 px-4">
                      <span className={`text-xs px-2 py-1 rounded-md font-medium ${getStatusColor(d.status)}`}>
                        {d.status}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <span className="text-xs text-gray-400">{new Date(d.created_at).toLocaleString()}</span>
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
