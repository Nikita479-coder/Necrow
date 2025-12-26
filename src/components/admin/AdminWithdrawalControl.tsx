import { useState, useEffect } from 'react';
import { Lock, Unlock, AlertTriangle, CheckCircle2 } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';
import { useToast } from '../../hooks/useToast';

interface AdminWithdrawalControlProps {
  userId: string;
}

export default function AdminWithdrawalControl({ userId }: AdminWithdrawalControlProps) {
  const { user } = useAuth();
  const { showToast } = useToast();
  const [loading, setLoading] = useState(false);
  const [withdrawalBlocked, setWithdrawalBlocked] = useState(false);
  const [blockReason, setBlockReason] = useState('');
  const [blockedBy, setBlockedBy] = useState<string | null>(null);
  const [blockedAt, setBlockedAt] = useState<string | null>(null);
  const [showBlockModal, setShowBlockModal] = useState(false);
  const [newBlockReason, setNewBlockReason] = useState('');

  useEffect(() => {
    loadWithdrawalStatus();
  }, [userId]);

  const loadWithdrawalStatus = async () => {
    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('withdrawal_blocked, withdrawal_block_reason, withdrawal_blocked_by, withdrawal_blocked_at')
        .eq('id', userId)
        .single();

      if (error) throw error;

      if (data) {
        setWithdrawalBlocked(data.withdrawal_blocked || false);
        setBlockReason(data.withdrawal_block_reason || '');
        setBlockedBy(data.withdrawal_blocked_by);
        setBlockedAt(data.withdrawal_blocked_at);
      }
    } catch (error: any) {
      console.error('Error loading withdrawal status:', error);
    }
  };

  const handleBlockWithdrawals = async () => {
    if (!newBlockReason.trim()) {
      showToast('Please enter a reason for blocking withdrawals', 'error');
      return;
    }

    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('admin_block_withdrawals', {
        p_user_id: userId,
        p_reason: newBlockReason.trim(),
        p_admin_id: user?.id
      });

      if (error) throw error;

      if (data?.success) {
        showToast('Withdrawals blocked successfully', 'success');
        setShowBlockModal(false);
        setNewBlockReason('');
        loadWithdrawalStatus();
      } else {
        showToast(data?.error || 'Failed to block withdrawals', 'error');
      }
    } catch (error: any) {
      console.error('Error blocking withdrawals:', error);
      showToast(error.message || 'Failed to block withdrawals', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleUnblockWithdrawals = async () => {
    if (!confirm('Are you sure you want to unblock withdrawals for this user?')) {
      return;
    }

    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('admin_unblock_withdrawals', {
        p_user_id: userId,
        p_admin_id: user?.id
      });

      if (error) throw error;

      if (data?.success) {
        showToast('Withdrawals unblocked successfully', 'success');
        loadWithdrawalStatus();
      } else {
        showToast(data?.error || 'Failed to unblock withdrawals', 'error');
      }
    } catch (error: any) {
      console.error('Error unblocking withdrawals:', error);
      showToast(error.message || 'Failed to unblock withdrawals', 'error');
    } finally {
      setLoading(false);
    }
  };

  const commonReasons = [
    'Additional KYC verification required',
    'Proof of address needed',
    'Enhanced due diligence required',
    'Suspicious activity detected',
    'Account under review',
    'Additional identity verification required',
  ];

  return (
    <div className="bg-[#1a1d24] border border-gray-800 rounded-xl p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          {withdrawalBlocked ? (
            <div className="w-10 h-10 bg-red-500/20 rounded-lg flex items-center justify-center">
              <Lock className="w-5 h-5 text-red-500" />
            </div>
          ) : (
            <div className="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
              <Unlock className="w-5 h-5 text-green-500" />
            </div>
          )}
          <div>
            <h3 className="text-white font-semibold text-lg">Withdrawal Control</h3>
            <p className="text-gray-400 text-sm">Manage user withdrawal permissions</p>
          </div>
        </div>
      </div>

      {withdrawalBlocked ? (
        <div className="space-y-4">
          <div className="bg-red-500/10 border border-red-500/50 rounded-xl p-4">
            <div className="flex items-start gap-3 mb-3">
              <AlertTriangle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
              <div className="flex-1">
                <h4 className="text-red-500 font-semibold mb-1">Withdrawals Blocked</h4>
                <p className="text-gray-300 text-sm">{blockReason}</p>
              </div>
            </div>
            {blockedAt && (
              <p className="text-gray-400 text-xs mt-2">
                Blocked on {new Date(blockedAt).toLocaleString()}
              </p>
            )}
          </div>

          <button
            onClick={handleUnblockWithdrawals}
            disabled={loading}
            className="w-full bg-green-500 hover:bg-green-600 disabled:bg-gray-700 text-white font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2"
          >
            <Unlock className="w-5 h-5" />
            {loading ? 'Unblocking...' : 'Unblock Withdrawals'}
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="bg-green-500/10 border border-green-500/50 rounded-xl p-4">
            <div className="flex items-start gap-3">
              <CheckCircle2 className="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" />
              <div>
                <h4 className="text-green-500 font-semibold mb-1">Withdrawals Enabled</h4>
                <p className="text-gray-300 text-sm">User can withdraw funds normally</p>
              </div>
            </div>
          </div>

          <button
            onClick={() => setShowBlockModal(true)}
            className="w-full bg-red-500 hover:bg-red-600 text-white font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2"
          >
            <Lock className="w-5 h-5" />
            Block Withdrawals
          </button>
        </div>
      )}

      {showBlockModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#1a1d24] border border-gray-800 rounded-2xl max-w-lg w-full p-6">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-red-500/20 rounded-lg flex items-center justify-center">
                <Lock className="w-6 h-6 text-red-500" />
              </div>
              <div>
                <h3 className="text-white font-bold text-xl">Block Withdrawals</h3>
                <p className="text-gray-400 text-sm">Provide a reason for blocking</p>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-gray-400 text-sm font-medium mb-2 block">Reason</label>
                <textarea
                  value={newBlockReason}
                  onChange={(e) => setNewBlockReason(e.target.value)}
                  placeholder="Enter reason for blocking withdrawals..."
                  rows={3}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-3 text-white outline-none focus:border-red-500 transition-colors resize-none"
                />
              </div>

              <div>
                <label className="text-gray-400 text-sm font-medium mb-2 block">Common Reasons</label>
                <div className="grid grid-cols-1 gap-2">
                  {commonReasons.map((reason) => (
                    <button
                      key={reason}
                      onClick={() => setNewBlockReason(reason)}
                      className="text-left px-4 py-2 bg-[#0b0e11] hover:bg-[#2b3139] border border-gray-700 hover:border-red-500 rounded-lg text-sm text-gray-300 hover:text-white transition-all"
                    >
                      {reason}
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => {
                    setShowBlockModal(false);
                    setNewBlockReason('');
                  }}
                  className="flex-1 bg-gray-700 hover:bg-gray-600 text-white font-semibold py-3 rounded-xl transition-all"
                >
                  Cancel
                </button>
                <button
                  onClick={handleBlockWithdrawals}
                  disabled={loading || !newBlockReason.trim()}
                  className="flex-1 bg-red-500 hover:bg-red-600 disabled:bg-gray-700 text-white font-semibold py-3 rounded-xl transition-all flex items-center justify-center gap-2"
                >
                  <Lock className="w-5 h-5" />
                  {loading ? 'Blocking...' : 'Block'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
