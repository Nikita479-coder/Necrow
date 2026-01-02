import { useState, useEffect } from 'react';
import { Phone, Eye, EyeOff, Lock, Send, X, Check, Clock, AlertCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { loggingService } from '../../services/loggingService';

interface PhoneRevealButtonProps {
  userId: string;
  phone: string | null;
  isSuperAdmin: boolean;
  userName?: string;
  compact?: boolean;
}

type RequestStatus = 'none' | 'pending' | 'approved' | 'denied';

export default function PhoneRevealButton({
  userId,
  phone,
  isSuperAdmin,
  userName,
  compact = false
}: PhoneRevealButtonProps) {
  const [showModal, setShowModal] = useState(false);
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [requestStatus, setRequestStatus] = useState<RequestStatus>('none');
  const [hasAccess, setHasAccess] = useState(false);
  const [revealedPhone, setRevealedPhone] = useState<string | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isSuperAdmin) {
      setHasAccess(true);
      setRevealedPhone(phone);
    } else {
      checkAccessStatus();
    }
  }, [userId, isSuperAdmin, phone]);

  const checkAccessStatus = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: grant } = await supabase
        .from('phone_reveals_granted')
        .select('*')
        .eq('staff_id', user.id)
        .eq('target_user_id', userId)
        .maybeSingle();

      if (grant && (!grant.expires_at || new Date(grant.expires_at) > new Date())) {
        setHasAccess(true);
        setRevealedPhone(phone);
        return;
      }

      const { data: request } = await supabase
        .from('phone_reveal_requests')
        .select('status')
        .eq('requester_id', user.id)
        .eq('target_user_id', userId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (request) {
        setRequestStatus(request.status as RequestStatus);
        if (request.status === 'approved') {
          setHasAccess(true);
          setRevealedPhone(phone);
        }
      }
    } catch (err) {
      console.error('Error checking access status:', err);
    }
  };

  const maskPhone = (phoneNumber: string | null): string => {
    if (!phoneNumber) return 'Not provided';
    if (phoneNumber.length <= 4) return '****';
    return '*'.repeat(phoneNumber.length - 4) + phoneNumber.slice(-4);
  };

  const handleRequestAccess = async () => {
    if (!reason.trim()) {
      setError('Please provide a reason for this request');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const { data, error: rpcError } = await supabase.rpc('create_phone_reveal_request', {
        p_target_user_id: userId,
        p_reason: reason.trim()
      });

      if (rpcError) throw rpcError;

      await loggingService.logStaffPhoneRevealRequest(userId, reason.trim());

      setRequestStatus('pending');
      setShowModal(false);
      setReason('');
    } catch (err: any) {
      setError(err.message || 'Failed to submit request');
    } finally {
      setLoading(false);
    }
  };

  if (!phone) {
    return (
      <span className="text-gray-500 text-sm">Not provided</span>
    );
  }

  if (hasAccess && revealedPhone) {
    return (
      <div className="flex items-center gap-2">
        <span className={`text-[#f0b90b] ${compact ? 'text-sm' : ''} font-mono`}>
          {revealedPhone}
        </span>
        {isSuperAdmin && (
          <span className="text-xs text-green-400 bg-green-500/10 px-1.5 py-0.5 rounded">
            Full Access
          </span>
        )}
      </div>
    );
  }

  return (
    <>
      <div className="flex items-center gap-2">
        <span className={`text-gray-400 ${compact ? 'text-sm' : ''} font-mono`}>
          {maskPhone(phone)}
        </span>

        {requestStatus === 'pending' ? (
          <div className="flex items-center gap-1 text-yellow-400 text-xs bg-yellow-500/10 px-2 py-1 rounded">
            <Clock className="w-3 h-3" />
            <span>Pending</span>
          </div>
        ) : requestStatus === 'denied' ? (
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-1 text-red-400 hover:text-red-300 text-xs bg-red-500/10 hover:bg-red-500/20 px-2 py-1 rounded transition-colors"
          >
            <AlertCircle className="w-3 h-3" />
            <span>Denied - Request Again</span>
          </button>
        ) : (
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-1 text-blue-400 hover:text-blue-300 text-xs bg-blue-500/10 hover:bg-blue-500/20 px-2 py-1 rounded transition-colors"
          >
            <Lock className="w-3 h-3" />
            <span>Request Access</span>
          </button>
        )}
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 w-full max-w-md">
            <div className="flex items-center justify-between p-4 border-b border-gray-800">
              <div className="flex items-center gap-2">
                <Phone className="w-5 h-5 text-[#f0b90b]" />
                <h3 className="text-lg font-bold text-white">Request Phone Access</h3>
              </div>
              <button
                onClick={() => setShowModal(false)}
                className="text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-4 space-y-4">
              <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-700">
                <p className="text-sm text-gray-400 mb-1">User</p>
                <p className="text-white font-medium">{userName || 'Unknown'}</p>
              </div>

              <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-700">
                <p className="text-sm text-gray-400 mb-1">Masked Phone</p>
                <p className="text-[#f0b90b] font-mono">{maskPhone(phone)}</p>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Reason for Request <span className="text-red-400">*</span>
                </label>
                <textarea
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="Please explain why you need access to this phone number..."
                  className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-3 py-2 text-white text-sm outline-none focus:border-[#f0b90b] resize-none h-24"
                />
              </div>

              {error && (
                <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-3 text-red-400 text-sm">
                  {error}
                </div>
              )}

              <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-3">
                <p className="text-yellow-400 text-sm">
                  Your request will be reviewed by a super admin. All requests are logged for compliance purposes.
                </p>
              </div>
            </div>

            <div className="flex justify-end gap-3 p-4 border-t border-gray-800">
              <button
                onClick={() => setShowModal(false)}
                className="px-4 py-2 text-gray-400 hover:text-white transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleRequestAccess}
                disabled={loading || !reason.trim()}
                className="flex items-center gap-2 px-4 py-2 bg-[#f0b90b] hover:bg-[#d4a30a] text-black font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? (
                  <div className="w-4 h-4 border-2 border-black/30 border-t-black rounded-full animate-spin" />
                ) : (
                  <Send className="w-4 h-4" />
                )}
                Submit Request
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
