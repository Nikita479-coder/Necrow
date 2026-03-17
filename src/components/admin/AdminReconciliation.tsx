import { useState, useEffect } from 'react';
import { DollarSign, TrendingUp, TrendingDown, ArrowUpRight, ArrowDownRight, RefreshCw, Calendar, Download } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface ReconciliationData {
  date: string;
  deposits: number;
  withdrawals: number;
  feesCollected: number;
  tradingVolume: number;
  netFlow: number;
  userCount: number;
}

interface SummaryData {
  totalDeposits: number;
  totalWithdrawals: number;
  totalFees: number;
  totalVolume: number;
  netFlow: number;
  avgDailyDeposit: number;
  avgDailyWithdrawal: number;
}

export default function AdminReconciliation() {
  const [data, setData] = useState<ReconciliationData[]>([]);
  const [summary, setSummary] = useState<SummaryData | null>(null);
  const [loading, setLoading] = useState(true);
  const [dateRange, setDateRange] = useState('7d');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  useEffect(() => {
    loadReconciliationData();
  }, [dateRange, startDate, endDate]);

  const getDateRange = () => {
    const now = new Date();
    let start: Date;
    let end = now;

    if (startDate && endDate) {
      start = new Date(startDate);
      end = new Date(endDate);
    } else {
      switch (dateRange) {
        case '7d':
          start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case '30d':
          start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        case '90d':
          start = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);
          break;
        default:
          start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      }
    }

    return { start, end };
  };

  const loadReconciliationData = async () => {
    setLoading(true);
    try {
      const { start, end } = getDateRange();

      const { data: deposits } = await supabase
        .from('transactions')
        .select('amount, created_at')
        .eq('transaction_type', 'deposit')
        .gte('created_at', start.toISOString())
        .lte('created_at', end.toISOString());

      const { data: withdrawals } = await supabase
        .from('transactions')
        .select('amount, created_at')
        .eq('transaction_type', 'withdrawal')
        .gte('created_at', start.toISOString())
        .lte('created_at', end.toISOString());

      const { data: fees } = await supabase
        .from('fee_collections')
        .select('fee_amount, created_at')
        .gte('created_at', start.toISOString())
        .lte('created_at', end.toISOString());

      const { data: positions } = await supabase
        .from('futures_positions')
        .select('position_size, opened_at')
        .gte('opened_at', start.toISOString())
        .lte('opened_at', end.toISOString());

      const dailyData: Record<string, ReconciliationData> = {};

      const currentDate = new Date(start);
      while (currentDate <= end) {
        const dateKey = currentDate.toISOString().split('T')[0];
        dailyData[dateKey] = {
          date: dateKey,
          deposits: 0,
          withdrawals: 0,
          feesCollected: 0,
          tradingVolume: 0,
          netFlow: 0,
          userCount: 0,
        };
        currentDate.setDate(currentDate.getDate() + 1);
      }

      deposits?.forEach((d) => {
        const dateKey = new Date(d.created_at).toISOString().split('T')[0];
        if (dailyData[dateKey]) {
          dailyData[dateKey].deposits += parseFloat(d.amount) || 0;
        }
      });

      withdrawals?.forEach((w) => {
        const dateKey = new Date(w.created_at).toISOString().split('T')[0];
        if (dailyData[dateKey]) {
          dailyData[dateKey].withdrawals += Math.abs(parseFloat(w.amount) || 0);
        }
      });

      fees?.forEach((f) => {
        const dateKey = new Date(f.created_at).toISOString().split('T')[0];
        if (dailyData[dateKey]) {
          dailyData[dateKey].feesCollected += parseFloat(f.fee_amount) || 0;
        }
      });

      positions?.forEach((p) => {
        const dateKey = new Date(p.opened_at).toISOString().split('T')[0];
        if (dailyData[dateKey]) {
          dailyData[dateKey].tradingVolume += parseFloat(p.position_size) || 0;
        }
      });

      Object.keys(dailyData).forEach((key) => {
        dailyData[key].netFlow = dailyData[key].deposits - dailyData[key].withdrawals;
      });

      const sortedData = Object.values(dailyData).sort((a, b) => b.date.localeCompare(a.date));
      setData(sortedData);

      const totalDeposits = sortedData.reduce((sum, d) => sum + d.deposits, 0);
      const totalWithdrawals = sortedData.reduce((sum, d) => sum + d.withdrawals, 0);
      const totalFees = sortedData.reduce((sum, d) => sum + d.feesCollected, 0);
      const totalVolume = sortedData.reduce((sum, d) => sum + d.tradingVolume, 0);
      const days = sortedData.length || 1;

      setSummary({
        totalDeposits,
        totalWithdrawals,
        totalFees,
        totalVolume,
        netFlow: totalDeposits - totalWithdrawals,
        avgDailyDeposit: totalDeposits / days,
        avgDailyWithdrawal: totalWithdrawals / days,
      });
    } catch (error) {
      console.error('Error loading reconciliation data:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount: number) => {
    if (amount >= 1000000) return `$${(amount / 1000000).toFixed(2)}M`;
    if (amount >= 1000) return `$${(amount / 1000).toFixed(2)}K`;
    return `$${amount.toFixed(2)}`;
  };

  const handleExport = () => {
    const headers = ['Date', 'Deposits', 'Withdrawals', 'Net Flow', 'Fees Collected', 'Trading Volume'];
    const rows = data.map((d) => [
      d.date,
      d.deposits.toFixed(2),
      d.withdrawals.toFixed(2),
      d.netFlow.toFixed(2),
      d.feesCollected.toFixed(2),
      d.tradingVolume.toFixed(2),
    ]);

    const csv = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `reconciliation_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <h2 className="text-xl font-bold text-white flex items-center gap-2">
          <DollarSign className="w-6 h-6 text-[#f0b90b]" />
          Financial Reconciliation
        </h2>
        <div className="flex items-center gap-3">
          <select
            value={dateRange}
            onChange={(e) => {
              setDateRange(e.target.value);
              setStartDate('');
              setEndDate('');
            }}
            className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
          >
            <option value="7d">Last 7 Days</option>
            <option value="30d">Last 30 Days</option>
            <option value="90d">Last 90 Days</option>
            <option value="custom">Custom Range</option>
          </select>

          {dateRange === 'custom' && (
            <>
              <input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
              />
              <span className="text-gray-500">to</span>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm"
              />
            </>
          )}

          <button
            onClick={loadReconciliationData}
            disabled={loading}
            className="p-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>

          <button
            onClick={handleExport}
            className="flex items-center gap-2 px-3 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors text-sm"
          >
            <Download className="w-4 h-4" />
            Export
          </button>
        </div>
      </div>

      {summary && (
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-2 text-green-400 mb-2">
              <ArrowUpRight className="w-4 h-4" />
              <span className="text-sm">Total Deposits</span>
            </div>
            <p className="text-2xl font-bold text-white">{formatCurrency(summary.totalDeposits)}</p>
            <p className="text-xs text-gray-500 mt-1">Avg: {formatCurrency(summary.avgDailyDeposit)}/day</p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-2 text-red-400 mb-2">
              <ArrowDownRight className="w-4 h-4" />
              <span className="text-sm">Total Withdrawals</span>
            </div>
            <p className="text-2xl font-bold text-white">{formatCurrency(summary.totalWithdrawals)}</p>
            <p className="text-xs text-gray-500 mt-1">Avg: {formatCurrency(summary.avgDailyWithdrawal)}/day</p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-2 mb-2">
              <TrendingUp className={`w-4 h-4 ${summary.netFlow >= 0 ? 'text-green-400' : 'text-red-400'}`} />
              <span className={`text-sm ${summary.netFlow >= 0 ? 'text-green-400' : 'text-red-400'}`}>Net Flow</span>
            </div>
            <p className={`text-2xl font-bold ${summary.netFlow >= 0 ? 'text-green-400' : 'text-red-400'}`}>
              {summary.netFlow >= 0 ? '+' : ''}{formatCurrency(summary.netFlow)}
            </p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800">
            <div className="flex items-center gap-2 text-[#f0b90b] mb-2">
              <DollarSign className="w-4 h-4" />
              <span className="text-sm">Fees Collected</span>
            </div>
            <p className="text-2xl font-bold text-white">{formatCurrency(summary.totalFees)}</p>
          </div>

          <div className="bg-[#0b0e11] rounded-xl p-4 border border-gray-800 col-span-2">
            <div className="flex items-center gap-2 text-blue-400 mb-2">
              <TrendingUp className="w-4 h-4" />
              <span className="text-sm">Total Trading Volume</span>
            </div>
            <p className="text-2xl font-bold text-white">{formatCurrency(summary.totalVolume)}</p>
          </div>
        </div>
      )}

      <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#1a1d24]">
              <tr>
                <th className="px-4 py-3 text-left text-sm font-medium text-gray-400">Date</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">Deposits</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">Withdrawals</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">Net Flow</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">Fees</th>
                <th className="px-4 py-3 text-right text-sm font-medium text-gray-400">Volume</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-800">
              {data.map((row) => (
                <tr key={row.date} className="hover:bg-[#1a1d24]/50 transition-colors">
                  <td className="px-4 py-3 text-white font-medium">{row.date}</td>
                  <td className="px-4 py-3 text-right text-green-400">{formatCurrency(row.deposits)}</td>
                  <td className="px-4 py-3 text-right text-red-400">{formatCurrency(row.withdrawals)}</td>
                  <td className={`px-4 py-3 text-right font-medium ${row.netFlow >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                    {row.netFlow >= 0 ? '+' : ''}{formatCurrency(row.netFlow)}
                  </td>
                  <td className="px-4 py-3 text-right text-[#f0b90b]">{formatCurrency(row.feesCollected)}</td>
                  <td className="px-4 py-3 text-right text-gray-300">{formatCurrency(row.tradingVolume)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {data.length === 0 && !loading && (
          <div className="text-center py-12">
            <DollarSign className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">No data available for the selected period</p>
          </div>
        )}

        {loading && (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b] mx-auto"></div>
            <p className="text-gray-400 mt-3">Loading reconciliation data...</p>
          </div>
        )}
      </div>
    </div>
  );
}
