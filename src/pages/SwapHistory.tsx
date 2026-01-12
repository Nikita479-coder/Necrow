import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import CryptoIcon from '../components/CryptoIcon';
import { ArrowRight, Clock, CheckCircle, XCircle, ArrowLeft } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { supabase } from '../lib/supabase';

interface SwapOrder {
  order_id: string;
  from_currency: string;
  to_currency: string;
  from_amount: string;
  to_amount: string;
  order_type: string;
  execution_rate: string;
  status: string;
  fee_amount: string;
  executed_at: string;
  created_at: string;
}

function SwapHistory() {
  const { user } = useAuth();
  const { navigateTo } = useNavigation();
  const [orders, setOrders] = useState<SwapOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'executed' | 'pending' | 'cancelled'>('all');

  useEffect(() => {
    if (user) {
      loadSwapHistory();
    }
  }, [user, filter]);

  const loadSwapHistory = async () => {
    if (!user) return;

    setLoading(true);
    try {
      let query = supabase
        .from('swap_orders')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

      if (filter !== 'all') {
        query = query.eq('status', filter);
      }

      const { data, error } = await query;

      if (error) {
        console.error('Error loading swap history:', error);
        return;
      }

      if (data) {
        setOrders(data);
      }
    } catch (error) {
      console.error('Failed to load swap history:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'executed':
        return <CheckCircle className="w-5 h-5 text-[#0ecb81]" />;
      case 'pending':
        return <Clock className="w-5 h-5 text-[#f0b90b]" />;
      case 'cancelled':
      case 'expired':
        return <XCircle className="w-5 h-5 text-[#f6465d]" />;
      default:
        return <Clock className="w-5 h-5 text-gray-400" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'executed':
        return 'text-[#0ecb81]';
      case 'pending':
        return 'text-[#f0b90b]';
      case 'cancelled':
      case 'expired':
        return 'text-[#f6465d]';
      default:
        return 'text-gray-400';
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const filteredOrders = orders;

  return (
    <div className="min-h-screen bg-[#0c0d0f] text-white">
      <Navbar />

      <div className="max-w-[1400px] mx-auto px-6 py-8">
        <div className="mb-8">
          <button
            onClick={() => navigateTo('swap')}
            className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-4"
          >
            <ArrowLeft className="w-5 h-5" />
            <span className="text-sm font-medium">Back to Swap</span>
          </button>
          <h1 className="text-4xl font-bold mb-3">Swap History</h1>
          <p className="text-gray-400 text-base">View all your past currency conversions</p>
        </div>

        <div className="bg-[#181a20] border border-[#2b2e35] rounded-lg overflow-hidden">
          <div className="flex items-center gap-4 p-6 border-b border-[#2b2e35]">
            <button
              onClick={() => setFilter('all')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === 'all'
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#2b2e35] text-gray-400 hover:text-white hover:bg-[#3b3f47]'
              }`}
            >
              All
            </button>
            <button
              onClick={() => setFilter('executed')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === 'executed'
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#2b2e35] text-gray-400 hover:text-white hover:bg-[#3b3f47]'
              }`}
            >
              Completed
            </button>
            <button
              onClick={() => setFilter('pending')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === 'pending'
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#2b2e35] text-gray-400 hover:text-white hover:bg-[#3b3f47]'
              }`}
            >
              Pending
            </button>
            <button
              onClick={() => setFilter('cancelled')}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                filter === 'cancelled'
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#2b2e35] text-gray-400 hover:text-white hover:bg-[#3b3f47]'
              }`}
            >
              Cancelled
            </button>
          </div>

          <div className="overflow-x-auto">
            {loading ? (
              <div className="flex items-center justify-center py-20">
                <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[#f0b90b]"></div>
              </div>
            ) : filteredOrders.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-20">
                <div className="w-20 h-20 bg-[#2b2e35] rounded-full flex items-center justify-center mb-4">
                  <Clock className="w-10 h-10 text-gray-600" />
                </div>
                <h3 className="text-xl font-semibold text-white mb-2">No swap history</h3>
                <p className="text-gray-400 text-center max-w-md">
                  You haven't made any swaps yet. Start converting your assets to see your history here.
                </p>
              </div>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-[#2b2e35]">
                    <th className="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Date
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      From
                    </th>
                    <th className="px-6 py-4 text-center text-xs font-medium text-gray-400 uppercase tracking-wider">

                    </th>
                    <th className="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      To
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Rate
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Type
                    </th>
                    <th className="px-6 py-4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#2b2e35]">
                  {filteredOrders.map((order) => (
                    <tr key={order.order_id} className="hover:bg-[#1e2329] transition-colors">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-white">
                          {formatDate(order.executed_at || order.created_at)}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center gap-3">
                          <CryptoIcon symbol={order.from_currency} size={32} />
                          <div>
                            <div className="text-sm font-semibold text-white">
                              {parseFloat(order.from_amount).toFixed(8)}
                            </div>
                            <div className="text-xs text-gray-400">{order.from_currency}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-center">
                        <ArrowRight className="w-5 h-5 text-gray-400 mx-auto" />
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center gap-3">
                          <CryptoIcon symbol={order.to_currency} size={32} />
                          <div>
                            <div className="text-sm font-semibold text-white">
                              {parseFloat(order.to_amount).toFixed(8)}
                            </div>
                            <div className="text-xs text-gray-400">{order.to_currency}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-white">
                          {parseFloat(order.execution_rate).toFixed(8)}
                        </div>
                        <div className="text-xs text-gray-400">
                          1 {order.from_currency} = {parseFloat(order.execution_rate).toFixed(8)} {order.to_currency}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="text-sm text-gray-300 capitalize">{order.order_type}</span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center gap-2">
                          {getStatusIcon(order.status)}
                          <span className={`text-sm font-medium capitalize ${getStatusColor(order.status)}`}>
                            {order.status}
                          </span>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default SwapHistory;
