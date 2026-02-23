import { useState } from 'react';
import { Shield, Ban, CheckCircle, XCircle, DollarSign, AlertTriangle, Award, RefreshCw } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';
import { useAuth } from '../../context/AuthContext';
import { loggingService } from '../../services/loggingService';
import AdminEmailSender from './AdminEmailSender';
import AdminBonusManager from './AdminBonusManager';
import AdminWithdrawalControl from './AdminWithdrawalControl';
import AdminBalanceAdjustmentModal from './AdminBalanceAdjustmentModal';

interface Props {
  userId: string;
  userData: any;
  onRefresh: () => void;
}

export default function AdminUserActions({ userId, userData, onRefresh }: Props) {
  const [loading, setLoading] = useState(false);
  const [showBalanceModal, setShowBalanceModal] = useState(false);
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const { showToast } = useToast();
  const { user: adminUser } = useAuth();

  const updateKYCStatus = async (status: string, level?: number) => {
    setLoading(true);
    try {
      const oldStatus = userData?.profile?.kyc_status || 'unverified';
      const oldLevel = userData?.profile?.kyc_level || 0;

      const { error } = await supabase
        .from('user_profiles')
        .update({
          kyc_status: status,
          ...(level !== undefined && { kyc_level: level })
        })
        .eq('id', userId);

      if (error) throw error;

      await loggingService.logAdminActivity({
        action_type: 'kyc_status_update',
        action_description: `Changed KYC status from ${oldStatus} to ${status}${level !== undefined ? ` (Level ${level})` : ''}`,
        target_user_id: userId,
        metadata: {
          old_status: oldStatus,
          new_status: status,
          old_level: oldLevel,
          new_level: level || oldLevel
        }
      });

      if (status === 'verified' && oldStatus !== 'verified') {
        await sendKYCApprovalEmailAndNotification(level || 1);
      } else if (status === 'rejected') {
        await sendKYCRejectionEmail();
      }

      showToast('KYC status updated successfully', 'success');
      onRefresh();
    } catch (error) {
      console.error('KYC update error:', error);
      showToast('Failed to update KYC status', 'error');
    } finally {
      setLoading(false);
    }
  };

  const sendKYCApprovalEmailAndNotification = async (level: number) => {
    try {
      const userEmail = userData?.email;
      const userName = userData?.profile?.full_name || 'Valued User';

      if (userEmail) {
        const { data: template } = await supabase
          .from('email_templates')
          .select('id, subject, body')
          .eq('name', 'KYC Approved')
          .maybeSingle();

        if (template) {
          const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
          const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

          await fetch(`${supabaseUrl}/functions/v1/send-email`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${supabaseKey}`,
            },
            body: JSON.stringify({
              to: userEmail,
              subject: template.subject.replace('{{user_name}}', userName),
              html: template.body
                .replace(/\{\{user_name\}\}/g, userName)
                .replace(/\{\{kyc_level\}\}/g, String(level))
                .replace(/\{\{bonus_amount\}\}/g, '$20')
            })
          });
        }
      }

      await supabase.from('notifications').insert({
        user_id: userId,
        type: 'kyc_update',
        title: 'KYC Verification Approved',
        message: `Congratulations! Your KYC verification (Level ${level}) has been approved. You now have access to all trading features. Leave a TrustPilot review to earn a $5 bonus.`,
        read: false
      });
    } catch (error) {
      console.error('Error sending KYC approval notification:', error);
    }
  };

  const sendKYCRejectionEmail = async () => {
    try {
      const userEmail = userData?.email;
      const userName = userData?.profile?.full_name || 'Valued User';

      if (userEmail) {
        const { data: template } = await supabase
          .from('email_templates')
          .select('id, subject, body')
          .eq('name', 'KYC Rejected')
          .maybeSingle();

        if (template) {
          const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
          const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

          await fetch(`${supabaseUrl}/functions/v1/send-email`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${supabaseKey}`,
            },
            body: JSON.stringify({
              to: userEmail,
              subject: template.subject.replace('{{user_name}}', userName),
              html: template.body.replace(/\{\{user_name\}\}/g, userName)
            })
          });
        }
      }

      await supabase.from('notifications').insert({
        user_id: userId,
        type: 'kyc_update',
        title: 'KYC Verification Requires Attention',
        message: 'Your KYC verification could not be approved. Please check your email for details and resubmit your documents.',
        read: false
      });
    } catch (error) {
      console.error('Error sending KYC rejection email:', error);
    }
  };


  const toggleAccountStatus = async (suspend: boolean) => {
    if (!confirm(`Are you sure you want to ${suspend ? 'suspend' : 'activate'} this account?`)) {
      return;
    }

    setLoading(true);
    try {
      const wasSuspended = userData?.profile?.is_suspended || false;

      const updatePayload = suspend
        ? {
            is_suspended: true,
            suspension_reason: 'Suspended by admin',
            suspended_at: new Date().toISOString(),
            suspended_by: adminUser?.id || null,
          }
        : {
            is_suspended: false,
            suspension_reason: null,
            suspended_at: null,
            suspended_by: null,
          };

      const { error } = await supabase
        .from('user_profiles')
        .update(updatePayload)
        .eq('id', userId);

      if (error) throw error;

      await loggingService.logAdminActivity({
        action_type: 'account_status_change',
        action_description: `${suspend ? 'Suspended' : 'Activated'} account`,
        target_user_id: userId,
        metadata: {
          was_suspended: wasSuspended,
          is_suspended: suspend,
          action: suspend ? 'suspended' : 'activated'
        }
      });

      showToast(`Account ${suspend ? 'suspended' : 'activated'} successfully`, 'success');
      onRefresh();
    } catch (error: any) {
      console.error('Account status update error:', error);
      showToast(error?.message || 'Failed to update account status', 'error');
    } finally {
      setLoading(false);
    }
  };

  const resetUserAccount = async () => {
    setLoading(true);
    setShowResetConfirm(false);

    try {
      showToast('Resetting account...', 'info');

      const email = userData?.userEmail;
      if (!email) throw new Error('User email not found');

      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.access_token) throw new Error('Not authenticated');

      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const response = await fetch(`${supabaseUrl}/functions/v1/reset-user-account`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          email,
          keepKyc: true,
          bonusAmount: 20,
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || 'Failed to reset account');
      }

      showToast('Account reset successfully with $20 bonus', 'success');
      onRefresh();
    } catch (error: any) {
      console.error('Reset account error:', error);
      showToast(error?.message || 'Failed to reset account', 'error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white mb-4">KYC Management</h2>
        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
          <p className="text-gray-400 mb-4">Manage user's KYC verification status</p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <button
              onClick={() => updateKYCStatus('verified', 1)}
              disabled={loading}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors disabled:opacity-50"
            >
              <CheckCircle className="w-5 h-5" />
              <span>Verify Level 1</span>
            </button>
            <button
              onClick={() => updateKYCStatus('verified', 2)}
              disabled={loading}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors disabled:opacity-50"
            >
              <CheckCircle className="w-5 h-5" />
              <span>Verify Level 2</span>
            </button>
            <button
              onClick={() => updateKYCStatus('pending')}
              disabled={loading}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-yellow-500/10 hover:bg-yellow-500/20 text-yellow-400 rounded-lg border border-yellow-500/30 transition-colors disabled:opacity-50"
            >
              <Shield className="w-5 h-5" />
              <span>Set Pending</span>
            </button>
            <button
              onClick={() => updateKYCStatus('rejected')}
              disabled={loading}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 transition-colors disabled:opacity-50"
            >
              <XCircle className="w-5 h-5" />
              <span>Reject</span>
            </button>
          </div>
          <div className="mt-4 pt-4 border-t border-gray-700">
            <p className="text-sm text-gray-500 mb-3">Full Verification (requires face verification)</p>
            <button
              onClick={() => updateKYCStatus('verified', 3)}
              disabled={loading}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#f0b90b]/10 hover:bg-[#f0b90b]/20 text-[#f0b90b] rounded-lg border border-[#f0b90b]/30 transition-colors disabled:opacity-50 font-semibold"
            >
              <Award className="w-5 h-5" />
              <span>Verify Level 3 (Full Verification)</span>
            </button>
          </div>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Balance Management</h2>
        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
          <p className="text-gray-400 mb-4">Manually adjust user's balance</p>
          <button
            onClick={() => setShowBalanceModal(true)}
            disabled={loading}
            className="flex items-center gap-2 px-6 py-3 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors disabled:opacity-50"
          >
            <DollarSign className="w-5 h-5" />
            <span>Adjust Balance</span>
          </button>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Account Management</h2>
        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
          <p className="text-gray-400 mb-4">Manage user's account status</p>
          <div className="flex flex-wrap gap-3">
            <button
              onClick={() => toggleAccountStatus(true)}
              disabled={loading}
              className="flex items-center gap-2 px-6 py-3 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 transition-colors disabled:opacity-50"
            >
              <Ban className="w-5 h-5" />
              <span>Suspend Account</span>
            </button>
            <button
              onClick={() => toggleAccountStatus(false)}
              disabled={loading}
              className="flex items-center gap-2 px-6 py-3 bg-green-500/10 hover:bg-green-500/20 text-green-400 rounded-lg border border-green-500/30 transition-colors disabled:opacity-50"
            >
              <CheckCircle className="w-5 h-5" />
              <span>Activate Account</span>
            </button>
            <button
              onClick={() => setShowResetConfirm(true)}
              disabled={loading}
              className="flex items-center gap-2 px-6 py-3 bg-orange-500/10 hover:bg-orange-500/20 text-orange-400 rounded-lg border border-orange-500/30 transition-colors disabled:opacity-50"
            >
              <RefreshCw className="w-5 h-5" />
              <span>Reset Account</span>
            </button>
          </div>
          <div className="mt-4 pt-4 border-t border-gray-700">
            <p className="text-sm text-gray-500">
              Reset Account: Removes all trades, transactions, and balances. KYC status is preserved.
            </p>
          </div>
        </div>
      </div>

      <AdminWithdrawalControl userId={userId} />

      <AdminEmailSender userId={userId} userData={userData} onRefresh={onRefresh} />

      <AdminBonusManager userId={userId} userData={userData} onRefresh={onRefresh} />

      <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl p-6">
        <div className="flex items-start gap-3">
          <AlertTriangle className="w-6 h-6 text-yellow-400 flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-yellow-400 font-bold mb-2">Important Notice</h3>
            <p className="text-sm text-yellow-400/80">
              These actions directly affect user data. Please exercise caution and ensure all actions are properly documented and justified. Balance adjustments and account suspensions should be used sparingly and only when necessary.
            </p>
          </div>
        </div>
      </div>

      <AdminBalanceAdjustmentModal
        isOpen={showBalanceModal}
        onClose={() => setShowBalanceModal(false)}
        userId={userId}
        userName={userData?.full_name || userData?.email || 'User'}
        onSuccess={onRefresh}
      />

      {showResetConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-md w-full p-6">
            <div className="flex items-start gap-3 mb-4">
              <div className="w-12 h-12 bg-orange-500/10 rounded-lg flex items-center justify-center flex-shrink-0">
                <AlertTriangle className="w-6 h-6 text-orange-400" />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white mb-2">Reset User Account?</h3>
                <p className="text-gray-400 text-sm">
                  This action will permanently delete:
                </p>
                <ul className="mt-2 text-sm text-gray-400 space-y-1 list-disc list-inside">
                  <li>All trading positions and history</li>
                  <li>All transactions and wallet balances</li>
                  <li>Copy trading relationships</li>
                  <li>Staking positions</li>
                  <li>Referral commissions earned</li>
                  <li>All bonuses and rewards</li>
                </ul>
                <p className="mt-3 text-sm text-yellow-400 font-medium">
                  The user's KYC status will be preserved. All balances and trading history will be reset.
                </p>
              </div>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setShowResetConfirm(false)}
                disabled={loading}
                className="flex-1 px-4 py-3 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={resetUserAccount}
                disabled={loading}
                className="flex-1 px-4 py-3 bg-orange-500 hover:bg-orange-600 text-white rounded-lg transition-colors disabled:opacity-50 font-medium"
              >
                {loading ? 'Resetting...' : 'Reset Account'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
