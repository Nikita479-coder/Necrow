import { useState } from 'react';
import { Shield, Ban, CheckCircle, XCircle, DollarSign, AlertTriangle, Award } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';
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
  const { showToast } = useToast();

  const updateKYCStatus = async (status: string, level?: number) => {
    setLoading(true);
    try {
      const oldStatus = userData?.profile?.kyc_status || 'unverified';
      const oldLevel = userData?.profile?.kyc_level || 0;

      await supabase
        .from('user_profiles')
        .update({
          kyc_status: status,
          ...(level !== undefined && { kyc_level: level })
        })
        .eq('id', userId);

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
        await sendKYCApprovalEmailAndBonus(level || 1);
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

  const sendKYCApprovalEmailAndBonus = async (level: number) => {
    try {
      const { data: { user: currentUser } } = await supabase.auth.getUser();

      const { data: bonusType } = await supabase
        .from('bonus_types')
        .select('id, default_amount')
        .ilike('name', '%KYC%Verification%Bonus%')
        .eq('is_active', true)
        .maybeSingle();

      if (bonusType && currentUser) {
        const { error: bonusError } = await supabase.rpc('award_user_bonus', {
          p_user_id: userId,
          p_bonus_type_id: bonusType.id,
          p_amount: bonusType.default_amount,
          p_awarded_by: currentUser.id,
          p_notes: `KYC Level ${level} Verification Bonus`,
          p_expiry_days: 7
        });
        if (bonusError) console.error('Bonus award error:', bonusError);
      }

      const userEmail = userData?.email;
      const userName = userData?.profile?.full_name || 'Valued User';

      if (userEmail) {
        const { data: template } = await supabase
          .from('email_templates')
          .select('id, subject, html_content')
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
              html: template.html_content
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
        message: `Congratulations! Your KYC verification (Level ${level}) has been approved. You have received a $20 trading bonus!`,
        read: false
      });
    } catch (error) {
      console.error('Error sending KYC approval email/bonus:', error);
    }
  };

  const sendKYCRejectionEmail = async () => {
    try {
      const userEmail = userData?.email;
      const userName = userData?.profile?.full_name || 'Valued User';

      if (userEmail) {
        const { data: template } = await supabase
          .from('email_templates')
          .select('id, subject, html_content')
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
              html: template.html_content.replace(/\{\{user_name\}\}/g, userName)
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
      const oldStatus = userData?.account_status || 'active';
      const newStatus = suspend ? 'suspended' : 'active';

      await supabase
        .from('user_profiles')
        .update({ account_status: newStatus })
        .eq('id', userId);

      await loggingService.logAdminActivity({
        action_type: 'account_status_change',
        action_description: `Changed account status from ${oldStatus} to ${newStatus}`,
        target_user_id: userId,
        metadata: {
          old_status: oldStatus,
          new_status: newStatus,
          action: suspend ? 'suspended' : 'activated'
        }
      });

      showToast(`Account ${suspend ? 'suspended' : 'activated'} successfully`, 'success');
      onRefresh();
    } catch (error) {
      showToast('Failed to update account status', 'error');
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
          <div className="flex gap-3">
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
    </div>
  );
}
