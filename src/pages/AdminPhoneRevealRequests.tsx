import { useState, useEffect } from 'react';
import { Phone, Check, X, Clock, User, MessageSquare, RefreshCw, Eye, Filter, Search } from 'lucide-react';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';

interface PhoneRevealRequest {
  id: string;
  requester_id: string;
  requester_name: string;
  requester_email: string;
  target_user_id: string;
  target_user_name: string;
  target_user_phone: string;
  reason: string;
  status: 'pending' | 'approved' | 'denied';
  reviewed_by: string | null;
  reviewer_name: string | null;
  reviewed_at: string | null;
  admin_notes: string | null;
  created_at: string;
}

export default function AdminPhoneRevealRequests() {
  const { profile } = useAuth();
  const { navigateTo } = useNavigation();
  const [requests, setRequests] = useState<PhoneRevealRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'approved' | 'denied'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [pendingCount, setPendingCount] = useState(0);

  const [processingModal, setProcessingModal] = useState<{
    show: boolean;
    request: PhoneRevealRequest | null;
    action: 'approved' | 'denied' | null;
    notes: string;
    loading: boolean;
  }>({
    show: false,
    request: null,
    action: null,
    notes: '',
    loading: false
  });

  useEffect(() => {
    if (profile?.is_admin) {
      loadRequests();
      loadPendingCount();
    }
  }, [profile, statusFilter]);

  const loadRequests = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_phone_reveal_requests', {
        p_status: statusFilter === 'all' ? null : statusFilter,
        p_limit: 100,
        p_offset: 0
      });

      if (error) throw error;
      setRequests(data || []);
    } catch (error) {
      console.error('Error loading requests:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadPendingCount = async () => {
    try {
      const { data } = await supabase.rpc('get_pending_phone_reveal_count');
      setPendingCount(data || 0);
    } catch (error) {
      console.error('Error loading pending count:', error);
    }
  };

  const handleProcessRequest = async () => {
    if (!processingModal.request || !processingModal.action) return;

    setProcessingModal(prev => ({ ...prev, loading: true }));

    try {
      const { error } = await supabase.rpc('process_phone_reveal_request', {
        p_request_id: processingModal.request.id,
        p_action: processingModal.action,
        p_admin_notes: processingModal.notes || null
      });

      if (error) throw error;

      setProcessingModal({ show: false, request: null, action: null, notes: '', loading: false });
      loadRequests();
      loadPendingCount();
    } catch (error: any) {
      console.error('Error processing request:', error);
      alert(error.message || 'Failed to process request');
      setProcessingModal(prev => ({ ...prev, loading: false }));
    }
  };

  const handleViewUser = (userId: string) => {
    localStorage.setItem('adminSelectedUserId', userId);
    navigateTo('adminuserdetail');
  };

  const filteredRequests = requests.filter(req => {
    if (!searchQuery) return true;
    const query = searchQuery.toLowerCase();
    return (
      req.requester_name?.toLowerCase().includes(query) ||
      req.requester_email?.toLowerCase().includes(query) ||
      req.target_user_name?.toLowerCase().includes(query) ||
      req.reason?.toLowerCase().includes(query)
    );
  });

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (!profile?.is_admin) {
    return (
      <div className="min-h-screen bg-[#0a0d10] text-white">
        <Navbar />
        <div className="max-w-7xl mx-auto px-4 py-12">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-red-400 mb-4">Access Denied</h1>
            <p className="text-gray-400">Only super admins can access this page.</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0a0d10] text-white">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-8">
          <div className="flex items-center gap-3">
            <Phone className="w-8 h-8 text-[#f0b90b]" />
            <div>
              <h1 className="text-3xl font-bold">Phone Reveal Requests</h1>
              <p className="text-gray-400 mt-1">
                Review and manage phone number reveal requests from staff members
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {pendingCount > 0 && (
              <div className="flex items-center gap-2 px-4 py-2 bg-yellow-500/10 border border-yellow-500/30 rounded-lg">
                <Clock className="w-4 h-4 text-yellow-400" />
                <span className="text-yellow-400 font-medium">{pendingCount} Pending</span>
              </div>
            )}
            <button
              onClick={loadRequests}
              disabled={loading}
              className="flex items-center gap-2 px-4 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </div>

        <div className="flex items-center gap-4 mb-6">
          <div className="flex items-center gap-2 bg-[#0b0e11] rounded-lg border border-gray-800 p-1">
            {(['all', 'pending', 'approved', 'denied'] as const).map((status) => (
              <button
                key={status}
                onClick={() => setStatusFilter(status)}
                className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                  statusFilter === status
                    ? 'bg-[#f0b90b] text-black'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                {status.charAt(0).toUpperCase() + status.slice(1)}
              </button>
            ))}
          </div>

          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
            <input
              type="text"
              placeholder="Search by name, email, or reason..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg pl-10 pr-4 py-2 text-white text-sm outline-none focus:border-[#f0b90b]"
            />
          </div>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b] mx-auto"></div>
            <p className="text-gray-400 mt-4">Loading requests...</p>
          </div>
        ) : filteredRequests.length === 0 ? (
          <div className="bg-[#0b0e11] rounded-xl p-12 text-center border border-gray-800">
            <Phone className="w-16 h-16 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400">No phone reveal requests found</p>
          </div>
        ) : (
          <div className="space-y-4">
            {filteredRequests.map((request) => (
              <div
                key={request.id}
                className={`bg-[#0b0e11] rounded-xl p-6 border ${
                  request.status === 'pending'
                    ? 'border-yellow-500/30'
                    : request.status === 'approved'
                    ? 'border-green-500/30'
                    : 'border-red-500/30'
                }`}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-4">
                      <span className={`px-3 py-1 rounded-lg text-sm font-medium ${
                        request.status === 'pending'
                          ? 'bg-yellow-500/10 text-yellow-400'
                          : request.status === 'approved'
                          ? 'bg-green-500/10 text-green-400'
                          : 'bg-red-500/10 text-red-400'
                      }`}>
                        {request.status.toUpperCase()}
                      </span>
                      <span className="text-gray-500 text-sm">
                        {formatDate(request.created_at)}
                      </span>
                    </div>

                    <div className="grid md:grid-cols-2 gap-6">
                      <div>
                        <h4 className="text-sm font-medium text-gray-400 mb-2">Requester</h4>
                        <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-800">
                          <p className="text-white font-medium">{request.requester_name || 'Unknown'}</p>
                          <p className="text-gray-400 text-sm">{request.requester_email}</p>
                          <button
                            onClick={() => handleViewUser(request.requester_id)}
                            className="text-[#f0b90b] text-sm mt-1 hover:underline flex items-center gap-1"
                          >
                            <Eye className="w-3 h-3" />
                            View Profile
                          </button>
                        </div>
                      </div>

                      <div>
                        <h4 className="text-sm font-medium text-gray-400 mb-2">Target User</h4>
                        <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-800">
                          <p className="text-white font-medium">{request.target_user_name || 'Unknown'}</p>
                          <p className="text-[#f0b90b] font-mono text-sm">{request.target_user_phone || 'No phone'}</p>
                          <button
                            onClick={() => handleViewUser(request.target_user_id)}
                            className="text-[#f0b90b] text-sm mt-1 hover:underline flex items-center gap-1"
                          >
                            <Eye className="w-3 h-3" />
                            View Profile
                          </button>
                        </div>
                      </div>
                    </div>

                    <div className="mt-4">
                      <h4 className="text-sm font-medium text-gray-400 mb-2">Reason</h4>
                      <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-800">
                        <p className="text-white">{request.reason}</p>
                      </div>
                    </div>

                    {request.status !== 'pending' && (
                      <div className="mt-4 bg-[#1a1d24]/50 rounded-lg p-3 border border-gray-800/50">
                        <div className="flex items-center gap-2 mb-2">
                          <User className="w-4 h-4 text-gray-400" />
                          <span className="text-sm text-gray-400">
                            {request.status === 'approved' ? 'Approved' : 'Denied'} by{' '}
                            <span className="text-white">{request.reviewer_name || 'Admin'}</span>
                          </span>
                          {request.reviewed_at && (
                            <span className="text-gray-500 text-sm">
                              on {formatDate(request.reviewed_at)}
                            </span>
                          )}
                        </div>
                        {request.admin_notes && (
                          <p className="text-gray-300 text-sm mt-2">
                            <span className="text-gray-500">Notes:</span> {request.admin_notes}
                          </p>
                        )}
                      </div>
                    )}
                  </div>

                  {request.status === 'pending' && (
                    <div className="flex flex-col gap-2 ml-6">
                      <button
                        onClick={() => setProcessingModal({
                          show: true,
                          request,
                          action: 'approved',
                          notes: '',
                          loading: false
                        })}
                        className="flex items-center gap-2 px-4 py-2 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors"
                      >
                        <Check className="w-4 h-4" />
                        Approve
                      </button>
                      <button
                        onClick={() => setProcessingModal({
                          show: true,
                          request,
                          action: 'denied',
                          notes: '',
                          loading: false
                        })}
                        className="flex items-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 transition-colors"
                      >
                        <X className="w-4 h-4" />
                        Deny
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {processingModal.show && processingModal.request && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 w-full max-w-md">
            <div className="flex items-center justify-between p-4 border-b border-gray-800">
              <h3 className="text-lg font-bold text-white">
                {processingModal.action === 'approved' ? 'Approve' : 'Deny'} Request
              </h3>
              <button
                onClick={() => setProcessingModal({ show: false, request: null, action: null, notes: '', loading: false })}
                className="text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-4 space-y-4">
              <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-700">
                <p className="text-sm text-gray-400 mb-1">Staff Member</p>
                <p className="text-white">{processingModal.request.requester_name}</p>
              </div>

              <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-700">
                <p className="text-sm text-gray-400 mb-1">Requesting Access To</p>
                <p className="text-white">{processingModal.request.target_user_name}</p>
                <p className="text-[#f0b90b] font-mono text-sm">{processingModal.request.target_user_phone}</p>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">Admin Notes (Optional)</label>
                <textarea
                  value={processingModal.notes}
                  onChange={(e) => setProcessingModal(prev => ({ ...prev, notes: e.target.value }))}
                  placeholder={`Add notes for ${processingModal.action === 'approved' ? 'approval' : 'denial'}...`}
                  className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b] resize-none h-20"
                />
              </div>

              {processingModal.action === 'approved' && (
                <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-3">
                  <p className="text-green-400 text-sm">
                    Approving this request will reveal the phone number to this staff member.
                  </p>
                </div>
              )}

              {processingModal.action === 'denied' && (
                <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3">
                  <p className="text-red-400 text-sm">
                    The staff member will be notified that their request was denied.
                  </p>
                </div>
              )}
            </div>

            <div className="flex justify-end gap-3 p-4 border-t border-gray-800">
              <button
                onClick={() => setProcessingModal({ show: false, request: null, action: null, notes: '', loading: false })}
                className="px-4 py-2 text-gray-400 hover:text-white transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleProcessRequest}
                disabled={processingModal.loading}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors disabled:opacity-50 ${
                  processingModal.action === 'approved'
                    ? 'bg-green-500 hover:bg-green-600 text-white'
                    : 'bg-red-500 hover:bg-red-600 text-white'
                }`}
              >
                {processingModal.loading ? (
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                ) : processingModal.action === 'approved' ? (
                  <Check className="w-4 h-4" />
                ) : (
                  <X className="w-4 h-4" />
                )}
                {processingModal.action === 'approved' ? 'Approve' : 'Deny'} Request
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
