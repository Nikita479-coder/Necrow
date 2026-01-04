import { useState, useEffect } from 'react';
import { ArrowLeft, Search, Filter, X, Download, TrendingUp, DollarSign, Clock, CheckCircle, XCircle, AlertCircle, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import Navbar from '../components/Navbar';

interface Deposit {
  payment_id: string;
  user_id: string;
  user_email?: string;
  user_name?: string;
  nowpayments_payment_id: string | null;
  price_amount: number;
  price_currency: string;
  pay_amount: number | null;
  pay_currency: string;
  pay_address: string | null;
  status: string;
  actually_paid: number | null;
  outcome_amount: number | null;
  created_at: string;
  updated_at: string;
  completed_at: string | null;
  expires_at: string | null;
  wallet_type: string;
}

interface DepositStats {
  total_deposits: number;
  completed_amount: number;
  pending_count: number;
  failed_count: number;
}

export default function AdminDeposits() {
  const { user, canAccessAdmin, hasPermission, loading: authLoading } = useAuth();
  const { navigateTo } = useNavigation();
  const [deposits, setDeposits] = useState<Deposit[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [hasAccess, setHasAccess] = useState(false);

  const [stats, setStats] = useState<DepositStats>({
    total_deposits: 0,
    completed_amount: 0,
    pending_count: 0,
    failed_count: 0,
  });

  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [filterCurrency, setFilterCurrency] = useState<string>('all');
  const [filterWalletType, setFilterWalletType] = useState<string>('all');
  const [filterDateRange, setFilterDateRange] = useState<string>('all');

  useEffect(() => {
    if (authLoading) return;
    checkAccess();
  }, [user, authLoading]);

  useEffect(() => {
    if (hasAccess) {
      loadData();
    }
  }, [hasAccess]);

  const checkAccess = async () => {
    if (authLoading) return;

    if (!user) {
      navigateTo('signin');
      return;
    }

    if (canAccessAdmin() && hasPermission('view_wallets')) {
      setHasAccess(true);
    } else {
      navigateTo('home');
    }
  };

  const loadData = async () => {
    setLoading(true);
    try {
      await loadDeposits();
    } catch (error) {
      console.error('Error loading deposits:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadDeposits = async () => {
    try {
      const { data, error } = await supabase.rpc('admin_get_all_deposits', {
        p_status: filterStatus === 'all' ? null : filterStatus,
        p_limit: 500,
        p_offset: 0
      });

      if (error) throw error;

      if (data?.success) {
        const loadedDeposits = data.deposits || [];
        setDeposits(loadedDeposits);

        const completedDeposits = loadedDeposits.filter((d: Deposit) => d.status === 'finished' || d.status === 'completed' || d.status === 'partially_paid' || d.status === 'overpaid');
        const completedAmount = completedDeposits.reduce((sum: number, d: Deposit) => sum + parseFloat(d.actually_paid?.toString() || d.outcome_amount?.toString() || '0'), 0);
        const pendingCount = loadedDeposits.filter((d: Deposit) => d.status === 'waiting' || d.status === 'confirming' || d.status === 'sending').length;
        const failedCount = loadedDeposits.filter((d: Deposit) => d.status === 'failed' || d.status === 'expired' || d.status === 'refunded').length;

        setStats({
          total_deposits: loadedDeposits.length,
          completed_amount: completedAmount,
          pending_count: pendingCount,
          failed_count: failedCount,
        });
      }
    } catch (error) {
      console.error('Error loading deposits:', error);
    }
  };

  const getStatusBadge = (status: string) => {
    const statusConfig: Record<string, { color: string; icon: any; label: string }> = {
      'finished': { color: 'bg-green-500/20 text-green-400 border-green-500/30', icon: CheckCircle, label: 'Completed' },
      'completed': { color: 'bg-green-500/20 text-green-400 border-green-500/30', icon: CheckCircle, label: 'Completed' },
      'partially_paid': { color: 'bg-green-500/20 text-green-400 border-green-500/30', icon: CheckCircle, label: 'Completed' },
      'overpaid': { color: 'bg-green-500/20 text-green-400 border-green-500/30', icon: CheckCircle, label: 'Completed' },
      'waiting': { color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30', icon: Clock, label: 'Waiting' },
      'confirming': { color: 'bg-blue-500/20 text-blue-400 border-blue-500/30', icon: RefreshCw, label: 'Confirming' },
      'sending': { color: 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30', icon: TrendingUp, label: 'Sending' },
      'failed': { color: 'bg-red-500/20 text-red-400 border-red-500/30', icon: XCircle, label: 'Failed' },
      'expired': { color: 'bg-gray-500/20 text-gray-400 border-gray-500/30', icon: AlertCircle, label: 'Expired' },
      'refunded': { color: 'bg-orange-500/20 text-orange-400 border-orange-500/30', icon: AlertCircle, label: 'Refunded' },
    };

    const config = statusConfig[status] || { color: 'bg-gray-500/20 text-gray-400 border-gray-500/30', icon: AlertCircle, label: status };
    const Icon = config.icon;

    return (
      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-lg border text-xs font-medium ${config.color}`}>
        <Icon className="w-3 h-3" />
        {config.label}
      </span>
    );
  };

  const filteredDeposits = deposits.filter(deposit => {
    const matchesSearch =
      deposit.user_email?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      deposit.user_name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      deposit.payment_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      deposit.nowpayments_payment_id?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      deposit.pay_currency.toLowerCase().includes(searchTerm.toLowerCase());

    if (!matchesSearch) return false;

    if (filterStatus !== 'all' && deposit.status !== filterStatus) return false;
    if (filterCurrency !== 'all' && deposit.pay_currency !== filterCurrency) return false;
    if (filterWalletType !== 'all' && deposit.wallet_type !== filterWalletType) return false;

    if (filterDateRange !== 'all') {
      const depositDate = new Date(deposit.created_at);
      const now = new Date();
      const hoursDiff = (now.getTime() - depositDate.getTime()) / (1000 * 60 * 60);

      if (filterDateRange === '24h' && hoursDiff > 24) return false;
      if (filterDateRange === '7d' && hoursDiff > 168) return false;
      if (filterDateRange === '30d' && hoursDiff > 720) return false;
    }

    return true;
  });

  const clearFilters = () => {
    setFilterStatus('all');
    setFilterCurrency('all');
    setFilterWalletType('all');
    setFilterDateRange('all');
  };

  const activeFilterCount = [
    filterStatus !== 'all',
    filterCurrency !== 'all',
    filterWalletType !== 'all',
    filterDateRange !== 'all',
  ].filter(Boolean).length;

  const exportToCSV = () => {
    const headers = ['Date', 'User', 'Email', 'Amount Paid', 'Currency', 'Status', 'Payment ID', 'Wallet Type'];
    const rows = filteredDeposits.map(d => [
      new Date(d.created_at).toLocaleString(),
      d.user_name,
      d.user_email,
      d.actually_paid ? parseFloat(d.actually_paid.toString()).toFixed(8) : '0',
      d.pay_currency,
      d.status,
      d.payment_id,
      d.wallet_type,
    ]);

    const csv = [headers, ...rows].map(row => row.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `deposits-${new Date().toISOString()}.csv`;
    a.click();
  };

  const uniqueCurrencies = Array.from(new Set(deposits.map(d => d.pay_currency)));

  if (!hasAccess) {
    return null;
  }

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8">
          <button
            onClick={() => navigateTo('admindashboard')}
            className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-4"
          >
            <ArrowLeft className="w-5 h-5" />
            Back to Admin Dashboard
          </button>

          <div className="flex items-center justify-between flex-wrap gap-4">
            <div>
              <h1 className="text-3xl font-bold text-white mb-2">Deposit Management</h1>
              <p className="text-gray-400">Monitor and manage cryptocurrency deposits</p>
            </div>
            <button
              onClick={exportToCSV}
              className="flex items-center gap-2 px-6 py-3 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg font-medium transition-all border border-green-500/30"
            >
              <Download className="w-5 h-5" />
              Export CSV
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-blue-500/10 rounded-xl flex items-center justify-center">
                <TrendingUp className="w-6 h-6 text-blue-400" />
              </div>
              <span className="text-sm text-gray-400">Total</span>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.total_deposits}</h3>
            <p className="text-sm text-gray-400">All Deposits</p>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-green-500/10 rounded-xl flex items-center justify-center">
                <DollarSign className="w-6 h-6 text-green-400" />
              </div>
              <span className="text-sm text-gray-400">Completed</span>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">${stats.completed_amount.toLocaleString(undefined, { maximumFractionDigits: 2 })}</h3>
            <p className="text-sm text-gray-400">Total Value</p>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-yellow-500/10 rounded-xl flex items-center justify-center">
                <Clock className="w-6 h-6 text-yellow-400" />
              </div>
              <span className="text-sm text-gray-400">Pending</span>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.pending_count}</h3>
            <p className="text-sm text-gray-400">Awaiting Confirmation</p>
          </div>

          <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
            <div className="flex items-center justify-between mb-4">
              <div className="w-12 h-12 bg-red-500/10 rounded-xl flex items-center justify-center">
                <XCircle className="w-6 h-6 text-red-400" />
              </div>
              <span className="text-sm text-gray-400">Failed</span>
            </div>
            <h3 className="text-2xl font-bold text-white mb-1">{stats.failed_count}</h3>
            <p className="text-sm text-gray-400">Failed/Expired</p>
          </div>
        </div>

        <div className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800">
          <div className="mb-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-bold text-white">All Deposits</h2>
              <button
                onClick={() => setShowFilters(!showFilters)}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all ${
                  showFilters
                    ? 'bg-[#f0b90b] text-black'
                    : 'bg-[#0b0e11] text-white hover:bg-[#0f1318] border border-gray-700'
                }`}
              >
                <Filter className="w-4 h-4" />
                Filters
                {activeFilterCount > 0 && (
                  <span className="bg-black/30 px-2 py-0.5 rounded-full text-xs">
                    {activeFilterCount}
                  </span>
                )}
              </button>
            </div>

            <div className="relative mb-4">
              <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="Search by user, email, payment ID, or currency..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl pl-12 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors"
              />
            </div>

            {showFilters && (
              <div className="bg-[#0b0e11] border border-gray-700 rounded-xl p-4 mb-4">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-white font-semibold flex items-center gap-2">
                    <Filter className="w-4 h-4" />
                    Filter Options
                  </h3>
                  {activeFilterCount > 0 && (
                    <button
                      onClick={clearFilters}
                      className="text-sm text-gray-400 hover:text-white flex items-center gap-1"
                    >
                      <X className="w-4 h-4" />
                      Clear All
                    </button>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Status</label>
                    <select
                      value={filterStatus}
                      onChange={(e) => setFilterStatus(e.target.value)}
                      className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                    >
                      <option value="all">All Statuses</option>
                      <option value="finished">Completed</option>
                      <option value="partially_paid">Partially Paid</option>
                      <option value="waiting">Waiting</option>
                      <option value="confirming">Confirming</option>
                      <option value="sending">Sending</option>
                      <option value="failed">Failed</option>
                      <option value="expired">Expired</option>
                      <option value="refunded">Refunded</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Currency</label>
                    <select
                      value={filterCurrency}
                      onChange={(e) => setFilterCurrency(e.target.value)}
                      className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                    >
                      <option value="all">All Currencies</option>
                      {uniqueCurrencies.map(currency => (
                        <option key={currency} value={currency}>{currency}</option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Wallet Type</label>
                    <select
                      value={filterWalletType}
                      onChange={(e) => setFilterWalletType(e.target.value)}
                      className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                    >
                      <option value="all">All Wallet Types</option>
                      <option value="main">Main Wallet</option>
                      <option value="copy">Copy Trading</option>
                      <option value="mock">Mock Trading</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm text-gray-400 mb-2">Date Range</label>
                    <select
                      value={filterDateRange}
                      onChange={(e) => setFilterDateRange(e.target.value)}
                      className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:border-[#f0b90b] transition-colors"
                    >
                      <option value="all">All Time</option>
                      <option value="24h">Last 24 Hours</option>
                      <option value="7d">Last 7 Days</option>
                      <option value="30d">Last 30 Days</option>
                    </select>
                  </div>
                </div>

                <div className="mt-4 pt-4 border-t border-gray-700 text-sm text-gray-400">
                  Showing {filteredDeposits.length} of {deposits.length} deposits
                </div>
              </div>
            )}
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
              <p className="text-gray-400 mt-4">Loading deposits...</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-800">
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Date</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">User</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-gray-400">Amount Paid</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Currency</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Wallet</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Status</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Payment ID</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredDeposits.map((deposit) => (
                    <tr key={deposit.payment_id} className="border-b border-gray-800/50 hover:bg-[#0b0e11] transition-colors">
                      <td className="py-4 px-4">
                        <div className="text-white text-sm">
                          {new Date(deposit.created_at).toLocaleDateString()}
                        </div>
                        <div className="text-gray-400 text-xs">
                          {new Date(deposit.created_at).toLocaleTimeString()}
                        </div>
                      </td>
                      <td className="py-4 px-4">
                        <div className="text-white font-medium">{deposit.user_name}</div>
                        <div className="text-gray-400 text-sm">{deposit.user_email}</div>
                      </td>
                      <td className="py-4 px-4 text-right">
                        {deposit.actually_paid ? (
                          <div className="text-white font-bold">
                            {parseFloat(deposit.actually_paid.toString()).toFixed(8)}
                          </div>
                        ) : (
                          <div className="text-gray-500 text-sm">—</div>
                        )}
                      </td>
                      <td className="py-4 px-4">
                        <span className="inline-flex items-center px-2 py-1 rounded-lg bg-blue-500/10 text-blue-400 border border-blue-500/30 text-xs font-medium">
                          {deposit.pay_currency}
                        </span>
                      </td>
                      <td className="py-4 px-4">
                        <span className="text-sm text-gray-300 capitalize">{deposit.wallet_type}</span>
                      </td>
                      <td className="py-4 px-4">
                        {getStatusBadge(deposit.status)}
                      </td>
                      <td className="py-4 px-4">
                        <div className="text-xs text-gray-400 font-mono">
                          {deposit.payment_id.slice(0, 8)}...
                        </div>
                        {deposit.nowpayments_payment_id && (
                          <div className="text-xs text-gray-500 font-mono">
                            NP: {deposit.nowpayments_payment_id.slice(0, 8)}...
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {filteredDeposits.length === 0 && (
                <div className="text-center py-12">
                  <p className="text-gray-400">No deposits found matching your filters.</p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
