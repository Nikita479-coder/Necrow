import { useState, useEffect } from 'react';
import Navbar from '../components/Navbar';
import { ArrowDownRight, Search, Filter, CheckCircle2, XCircle, Clock, Eye, Send, RefreshCw, ExternalLink, Copy } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../hooks/useToast';
import CryptoIcon from '../components/CryptoIcon';

interface Withdrawal {
  id: string;
  user_id: string;
  email: string;
  username: string;
  full_name: string;
  currency: string;
  amount: number;
  fee: number;
  receive_amount: number;
  status: string;
  address: string;
  network: string;
  tx_hash: string | null;
  created_at: string;
  updated_at: string;
  confirmed_at: string | null;
}

export default function AdminWithdrawals() {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [withdrawals, setWithdrawals] = useState<Withdrawal[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedWithdrawal, setSelectedWithdrawal] = useState<Withdrawal | null>(null);
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [txHashInput, setTxHashInput] = useState('');
  const [adminNotes, setAdminNotes] = useState('');
  const [showProcessModal, setShowProcessModal] = useState(false);
  const [processAction, setProcessAction] = useState<'approve' | 'reject' | 'complete'>('approve');

  useEffect(() => {
    loadWithdrawals();
  }, [statusFilter]);

  const loadWithdrawals = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('admin_get_all_withdrawals', {
        p_status: statusFilter === 'all' ? null : statusFilter,
        p_limit: 100,
        p_offset: 0
      });

      if (error) throw error;

      if (data?.success) {
        setWithdrawals(data.withdrawals || []);
      }
    } catch (error) {
      console.error('Error loading withdrawals:', error);
      showToast('Failed to load withdrawals', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleProcessWithdrawal = async () => {
    if (!selectedWithdrawal) return;

    setProcessingId(selectedWithdrawal.id);
    try {
      const { data, error } = await supabase.rpc('admin_process_withdrawal', {
        p_transaction_id: selectedWithdrawal.id,
        p_action: processAction,
        p_tx_hash: processAction === 'complete' ? txHashInput || null : null,
        p_admin_notes: adminNotes || null
      });

      if (error) throw error;

      if (data?.success) {
        showToast(data.message, 'success');
        setShowProcessModal(false);
        setSelectedWithdrawal(null);
        setTxHashInput('');
        setAdminNotes('');
        loadWithdrawals();
      } else {
        showToast(data?.error || 'Failed to process withdrawal', 'error');
      }
    } catch (error: any) {
      console.error('Error processing withdrawal:', error);
      showToast(error.message || 'Failed to process withdrawal', 'error');
    } finally {
      setProcessingId(null);
    }
  };

  const openProcessModal = (withdrawal: Withdrawal, action: 'approve' | 'reject' | 'complete') => {
    setSelectedWithdrawal(withdrawal);
    setProcessAction(action);
    setTxHashInput('');
    setAdminNotes('');
    setShowProcessModal(true);
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    showToast('Copied to clipboard', 'success');
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'bg-emerald-500/20 text-emerald-400';
      case 'processing':
        return 'bg-blue-500/20 text-blue-400';
      case 'pending':
        return 'bg-yellow-500/20 text-yellow-400';
      case 'failed':
        return 'bg-red-500/20 text-red-400';
      default:
        return 'bg-gray-500/20 text-gray-400';
    }
  };

  const filteredWithdrawals = withdrawals.filter(w => {
    if (!searchTerm) return true;
    const search = searchTerm.toLowerCase();
    return (
      w.email?.toLowerCase().includes(search) ||
      w.username?.toLowerCase().includes(search) ||
      w.full_name?.toLowerCase().includes(search) ||
      w.address?.toLowerCase().includes(search) ||
      w.currency?.toLowerCase().includes(search)
    );
  });

  const stats = {
    total: withdrawals.length,
    pending: withdrawals.filter(w => w.status === 'pending').length,
    processing: withdrawals.filter(w => w.status === 'processing').length,
    completed: withdrawals.filter(w => w.status === 'completed').length,
    failed: withdrawals.filter(w => w.status === 'failed').length,
    totalAmount: withdrawals.reduce((sum, w) => sum + (w.status === 'completed' ? w.amount : 0), 0)
  };

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Withdrawal Management</h1>
            <p className="text-gray-400">Review and process user withdrawal requests</p>
          </div>
          <button
            onClick={loadWithdrawals}
            className="flex items-center gap-2 px-4 py-2 bg-[#181a20] border border-gray-700 rounded-lg text-gray-300 hover:text-white hover:border-gray-600 transition-all"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
          <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4">
            <div className="text-gray-400 text-sm mb-1">Total Requests</div>
            <div className="text-2xl font-bold text-white">{stats.total}</div>
          </div>
          <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4">
            <div className="text-gray-400 text-sm mb-1">Pending</div>
            <div className="text-2xl font-bold text-yellow-400">{stats.pending}</div>
          </div>
          <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4">
            <div className="text-gray-400 text-sm mb-1">Processing</div>
            <div className="text-2xl font-bold text-blue-400">{stats.processing}</div>
          </div>
          <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4">
            <div className="text-gray-400 text-sm mb-1">Completed</div>
            <div className="text-2xl font-bold text-emerald-400">{stats.completed}</div>
          </div>
          <div className="bg-[#181a20] border border-gray-800 rounded-xl p-4">
            <div className="text-gray-400 text-sm mb-1">Total Processed</div>
            <div className="text-2xl font-bold text-white">${stats.totalAmount.toLocaleString()}</div>
          </div>
        </div>

        <div className="bg-[#181a20] border border-gray-800 rounded-2xl overflow-hidden">
          <div className="p-6 border-b border-gray-800">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search by user, email, or address..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl pl-10 pr-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                />
              </div>
              <div className="flex items-center gap-2">
                <Filter className="w-5 h-5 text-gray-400" />
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  className="bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                >
                  <option value="all">All Status</option>
                  <option value="pending">Pending</option>
                  <option value="processing">Processing</option>
                  <option value="completed">Completed</option>
                  <option value="failed">Failed</option>
                </select>
              </div>
            </div>
          </div>

          {loading ? (
            <div className="p-12 text-center text-gray-400">Loading withdrawals...</div>
          ) : filteredWithdrawals.length === 0 ? (
            <div className="p-12 text-center text-gray-400">No withdrawals found</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-[#0b0e11]">
                  <tr>
                    <th className="text-left text-gray-400 text-sm font-medium px-6 py-4">User</th>
                    <th className="text-left text-gray-400 text-sm font-medium px-6 py-4">Amount</th>
                    <th className="text-left text-gray-400 text-sm font-medium px-6 py-4">Network</th>
                    <th className="text-left text-gray-400 text-sm font-medium px-6 py-4">Address</th>
                    <th className="text-left text-gray-400 text-sm font-medium px-6 py-4">Status</th>
                    <th className="text-left text-gray-400 text-sm font-medium px-6 py-4">Date</th>
                    <th className="text-left text-gray-400 text-sm font-medium px-6 py-4">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-800">
                  {filteredWithdrawals.map((withdrawal) => (
                    <tr key={withdrawal.id} className="hover:bg-[#0b0e11]/50 transition-colors">
                      <td className="px-6 py-4">
                        <div>
                          <div className="font-medium text-white">{withdrawal.full_name || withdrawal.username}</div>
                          <div className="text-gray-400 text-sm">{withdrawal.email}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <CryptoIcon symbol={withdrawal.currency} size={24} />
                          <div>
                            <div className="font-bold text-white">{withdrawal.amount} {withdrawal.currency}</div>
                            <div className="text-gray-400 text-xs">Fee: {withdrawal.fee} {withdrawal.currency}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className="text-white">{withdrawal.network}</span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <span className="text-gray-300 font-mono text-sm">
                            {withdrawal.address?.substring(0, 10)}...{withdrawal.address?.substring(withdrawal.address.length - 6)}
                          </span>
                          <button
                            onClick={() => copyToClipboard(withdrawal.address)}
                            className="text-gray-400 hover:text-white transition-colors"
                          >
                            <Copy className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`px-3 py-1 rounded-full text-xs font-semibold ${getStatusColor(withdrawal.status)}`}>
                          {withdrawal.status.charAt(0).toUpperCase() + withdrawal.status.slice(1)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <div className="text-gray-300 text-sm">{formatDate(withdrawal.created_at)}</div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => setSelectedWithdrawal(withdrawal)}
                            className="p-2 bg-[#0b0e11] hover:bg-[#2b3139] border border-gray-700 rounded-lg text-gray-400 hover:text-white transition-all"
                            title="View Details"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          {withdrawal.status === 'pending' && (
                            <>
                              <button
                                onClick={() => openProcessModal(withdrawal, 'approve')}
                                className="p-2 bg-emerald-500/20 hover:bg-emerald-500/30 border border-emerald-500/50 rounded-lg text-emerald-400 transition-all"
                                title="Approve"
                              >
                                <CheckCircle2 className="w-4 h-4" />
                              </button>
                              <button
                                onClick={() => openProcessModal(withdrawal, 'reject')}
                                className="p-2 bg-red-500/20 hover:bg-red-500/30 border border-red-500/50 rounded-lg text-red-400 transition-all"
                                title="Reject"
                              >
                                <XCircle className="w-4 h-4" />
                              </button>
                            </>
                          )}
                          {withdrawal.status === 'processing' && (
                            <button
                              onClick={() => openProcessModal(withdrawal, 'complete')}
                              className="p-2 bg-blue-500/20 hover:bg-blue-500/30 border border-blue-500/50 rounded-lg text-blue-400 transition-all"
                              title="Mark Complete"
                            >
                              <Send className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      {selectedWithdrawal && !showProcessModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1d24] border border-gray-800 rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-[#1a1d24] border-b border-gray-800 p-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-gradient-to-br from-[#f0b90b] to-[#f8d12f] rounded-full flex items-center justify-center">
                  <ArrowDownRight className="w-6 h-6 text-black" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-white">Withdrawal Details</h2>
                  <p className="text-gray-400 text-sm">ID: {selectedWithdrawal.id.substring(0, 8)}...</p>
                </div>
              </div>
              <button
                onClick={() => setSelectedWithdrawal(null)}
                className="text-gray-400 hover:text-white transition-colors text-2xl"
              >
                x
              </button>
            </div>

            <div className="p-6 space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                  <div className="text-gray-400 text-sm mb-1">User</div>
                  <div className="text-white font-semibold">{selectedWithdrawal.full_name || selectedWithdrawal.username}</div>
                  <div className="text-gray-400 text-sm">{selectedWithdrawal.email}</div>
                </div>
                <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                  <div className="text-gray-400 text-sm mb-1">Status</div>
                  <span className={`px-3 py-1 rounded-full text-sm font-semibold ${getStatusColor(selectedWithdrawal.status)}`}>
                    {selectedWithdrawal.status.charAt(0).toUpperCase() + selectedWithdrawal.status.slice(1)}
                  </span>
                </div>
              </div>

              <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                <div className="text-gray-400 text-sm mb-2">Amount</div>
                <div className="flex items-center gap-3">
                  <CryptoIcon symbol={selectedWithdrawal.currency} size={40} />
                  <div>
                    <div className="text-2xl font-bold text-white">{selectedWithdrawal.amount} {selectedWithdrawal.currency}</div>
                    <div className="text-gray-400 text-sm">
                      Fee: {selectedWithdrawal.fee} {selectedWithdrawal.currency} |
                      Receive: {selectedWithdrawal.receive_amount} {selectedWithdrawal.currency}
                    </div>
                  </div>
                </div>
              </div>

              <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                <div className="text-gray-400 text-sm mb-2">Destination</div>
                <div className="flex items-center justify-between">
                  <div>
                    <div className="text-white font-semibold mb-1">{selectedWithdrawal.network}</div>
                    <div className="text-gray-300 font-mono text-sm break-all">{selectedWithdrawal.address}</div>
                  </div>
                  <button
                    onClick={() => copyToClipboard(selectedWithdrawal.address)}
                    className="p-2 bg-[#181a20] hover:bg-[#2b3139] border border-gray-700 rounded-lg text-gray-400 hover:text-white transition-all"
                  >
                    <Copy className="w-5 h-5" />
                  </button>
                </div>
              </div>

              {selectedWithdrawal.tx_hash && (
                <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                  <div className="text-gray-400 text-sm mb-2">Transaction Hash</div>
                  <div className="flex items-center justify-between">
                    <div className="text-gray-300 font-mono text-sm break-all">{selectedWithdrawal.tx_hash}</div>
                    <div className="flex gap-2">
                      <button
                        onClick={() => copyToClipboard(selectedWithdrawal.tx_hash || '')}
                        className="p-2 bg-[#181a20] hover:bg-[#2b3139] border border-gray-700 rounded-lg text-gray-400 hover:text-white transition-all"
                      >
                        <Copy className="w-5 h-5" />
                      </button>
                    </div>
                  </div>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                  <div className="text-gray-400 text-sm mb-1">Created</div>
                  <div className="text-white">{formatDate(selectedWithdrawal.created_at)}</div>
                </div>
                {selectedWithdrawal.confirmed_at && (
                  <div className="bg-[#0b0e11] border border-gray-800 rounded-xl p-4">
                    <div className="text-gray-400 text-sm mb-1">Confirmed</div>
                    <div className="text-white">{formatDate(selectedWithdrawal.confirmed_at)}</div>
                  </div>
                )}
              </div>

              {selectedWithdrawal.status === 'pending' && (
                <div className="flex gap-3">
                  <button
                    onClick={() => {
                      setSelectedWithdrawal(null);
                      openProcessModal(selectedWithdrawal, 'approve');
                    }}
                    className="flex-1 bg-emerald-500 hover:bg-emerald-600 text-white font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2"
                  >
                    <CheckCircle2 className="w-5 h-5" />
                    Approve
                  </button>
                  <button
                    onClick={() => {
                      setSelectedWithdrawal(null);
                      openProcessModal(selectedWithdrawal, 'reject');
                    }}
                    className="flex-1 bg-red-500 hover:bg-red-600 text-white font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2"
                  >
                    <XCircle className="w-5 h-5" />
                    Reject
                  </button>
                </div>
              )}

              {selectedWithdrawal.status === 'processing' && (
                <button
                  onClick={() => {
                    setSelectedWithdrawal(null);
                    openProcessModal(selectedWithdrawal, 'complete');
                  }}
                  className="w-full bg-blue-500 hover:bg-blue-600 text-white font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2"
                >
                  <Send className="w-5 h-5" />
                  Mark as Completed
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {showProcessModal && selectedWithdrawal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1d24] border border-gray-800 rounded-2xl max-w-lg w-full p-6">
            <div className="flex items-center gap-3 mb-6">
              <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${
                processAction === 'approve' ? 'bg-emerald-500/20' :
                processAction === 'reject' ? 'bg-red-500/20' : 'bg-blue-500/20'
              }`}>
                {processAction === 'approve' && <CheckCircle2 className="w-6 h-6 text-emerald-400" />}
                {processAction === 'reject' && <XCircle className="w-6 h-6 text-red-400" />}
                {processAction === 'complete' && <Send className="w-6 h-6 text-blue-400" />}
              </div>
              <div>
                <h3 className="text-xl font-bold text-white">
                  {processAction === 'approve' && 'Approve Withdrawal'}
                  {processAction === 'reject' && 'Reject Withdrawal'}
                  {processAction === 'complete' && 'Complete Withdrawal'}
                </h3>
                <p className="text-gray-400 text-sm">
                  {selectedWithdrawal.amount} {selectedWithdrawal.currency} to {selectedWithdrawal.address.substring(0, 10)}...
                </p>
              </div>
            </div>

            <div className="space-y-4">
              {processAction === 'complete' && (
                <div>
                  <label className="text-gray-400 text-sm font-medium mb-2 block">Transaction Hash (Optional)</label>
                  <input
                    type="text"
                    value={txHashInput}
                    onChange={(e) => setTxHashInput(e.target.value)}
                    placeholder="Enter blockchain transaction hash..."
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-blue-500 transition-colors font-mono text-sm"
                  />
                </div>
              )}

              {processAction === 'reject' && (
                <div>
                  <label className="text-gray-400 text-sm font-medium mb-2 block">Rejection Reason</label>
                  <textarea
                    value={adminNotes}
                    onChange={(e) => setAdminNotes(e.target.value)}
                    placeholder="Enter reason for rejection..."
                    rows={3}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-red-500 transition-colors resize-none"
                  />
                </div>
              )}

              {processAction === 'approve' && (
                <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-4">
                  <p className="text-yellow-400 text-sm">
                    Approving this withdrawal will mark it as "Processing". You will need to manually send the funds and then mark it as "Complete".
                  </p>
                </div>
              )}

              {processAction === 'reject' && (
                <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4">
                  <p className="text-red-400 text-sm">
                    Rejecting this withdrawal will refund the full amount ({selectedWithdrawal.amount} {selectedWithdrawal.currency}) back to the user's wallet.
                  </p>
                </div>
              )}

              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => {
                    setShowProcessModal(false);
                    setSelectedWithdrawal(null);
                  }}
                  className="flex-1 bg-gray-700 hover:bg-gray-600 text-white font-semibold py-3 rounded-xl transition-all"
                >
                  Cancel
                </button>
                <button
                  onClick={handleProcessWithdrawal}
                  disabled={processingId === selectedWithdrawal.id}
                  className={`flex-1 font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2 ${
                    processAction === 'approve' ? 'bg-emerald-500 hover:bg-emerald-600' :
                    processAction === 'reject' ? 'bg-red-500 hover:bg-red-600' : 'bg-blue-500 hover:bg-blue-600'
                  } text-white disabled:bg-gray-700`}
                >
                  {processingId === selectedWithdrawal.id ? 'Processing...' : (
                    <>
                      {processAction === 'approve' && <><CheckCircle2 className="w-5 h-5" /> Approve</>}
                      {processAction === 'reject' && <><XCircle className="w-5 h-5" /> Reject</>}
                      {processAction === 'complete' && <><Send className="w-5 h-5" /> Complete</>}
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
