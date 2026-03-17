import { useState, useEffect, useRef } from 'react';
import { Lock, Shield, Key, Smartphone, CheckCircle, AlertCircle, Eye, EyeOff, Copy, QrCode, Globe, Trash2, MapPin, Clock, ChevronLeft, ChevronRight } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import WhitelistWallets from './WhitelistWallets';

interface VerifiedIP {
  id: string;
  ip_address: string;
  device_info: string;
  location: {
    city?: string;
    country?: string;
  };
  first_seen: string;
  last_used: string;
  trust_expires_at: string | null;
}

export default function SecuritySettings() {
  const { user, profile } = useAuth();
  const [loading, setLoading] = useState(false);
  const verificationInputRef = useRef<HTMLInputElement>(null);
  const hasCheckedMfa = useRef(false);

  const [verifiedIPs, setVerifiedIPs] = useState<VerifiedIP[]>([]);
  const [ipsLoading, setIPsLoading] = useState(false);
  const [ipToRevoke, setIpToRevoke] = useState<VerifiedIP | null>(null);
  const [revoking, setRevoking] = useState(false);
  const [ipPage, setIpPage] = useState(1);
  const ipsPerPage = 5;

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [passwordError, setPasswordError] = useState('');
  const [passwordSuccess, setPasswordSuccess] = useState('');
  const [needsMfaForPassword, setNeedsMfaForPassword] = useState(false);
  const [passwordMfaCode, setPasswordMfaCode] = useState('');

  const [mfaEnabled, setMfaEnabled] = useState(false);
  const [mfaEnrolling, setMfaEnrolling] = useState(false);
  const [mfaQRCode, setMfaQRCode] = useState('');
  const [mfaSecret, setMfaSecret] = useState('');
  const [mfaFactorId, setMfaFactorId] = useState('');
  const [verificationCode, setVerificationCode] = useState('');
  const [mfaError, setMfaError] = useState('');
  const [mfaSuccess, setMfaSuccess] = useState('');

  const [emailForReset, setEmailForReset] = useState('');
  const [resetEmailSent, setResetEmailSent] = useState(false);
  const [resetError, setResetError] = useState('');

  useEffect(() => {
    checkMFAStatus();
    fetchVerifiedIPs();
  }, [user]);

  useEffect(() => {
    if (mfaEnrolling && mfaQRCode && verificationInputRef.current) {
      setTimeout(() => {
        verificationInputRef.current?.focus();
      }, 500);
    }
  }, [mfaEnrolling, mfaQRCode]);

  const fetchVerifiedIPs = async () => {
    if (!user) return;

    setIPsLoading(true);
    try {
      const { data, error } = await supabase
        .from('trusted_ips')
        .select('*')
        .eq('is_trusted', true)
        .order('last_used', { ascending: false });

      if (error) throw error;

      setVerifiedIPs(data || []);
    } catch (error) {
      console.error('Error fetching verified IPs:', error);
    } finally {
      setIPsLoading(false);
    }
  };

  const handleRevokeVerifiedIP = async () => {
    if (!ipToRevoke) return;

    setRevoking(true);
    try {
      const { error } = await supabase.rpc('revoke_trusted_ip', {
        p_trusted_ip_id: ipToRevoke.id
      });

      if (error) throw error;

      const newIPs = verifiedIPs.filter(ip => ip.id !== ipToRevoke.id);
      setVerifiedIPs(newIPs);
      const maxPage = Math.max(1, Math.ceil(newIPs.length / ipsPerPage));
      if (ipPage > maxPage) setIpPage(maxPage);
      setIpToRevoke(null);
    } catch (error: any) {
      console.error('Error revoking verified IP:', error);
    } finally {
      setRevoking(false);
    }
  };

  const formatDate = (date: string) => {
    return new Date(date).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const checkMFAStatus = async () => {
    if (!user || hasCheckedMfa.current) return;
    hasCheckedMfa.current = true;

    try {
      await supabase.auth.refreshSession();

      const { data } = await supabase.auth.mfa.listFactors();
      const totpFactor = data?.totp?.find((factor: any) => factor.status === 'verified');
      setMfaEnabled(!!totpFactor);
      if (totpFactor) {
        setMfaFactorId(totpFactor.id);
      }
    } catch (error) {
      console.error('Error checking MFA status:', error);
    }
  };

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError('');
    setPasswordSuccess('');

    if (!currentPassword) {
      setPasswordError('Current password is required');
      return;
    }

    if (newPassword.length < 8) {
      setPasswordError('Password must be at least 8 characters long');
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError('Passwords do not match');
      return;
    }

    const userEmail = user?.email || profile?.email;
    if (!userEmail) {
      setPasswordError('Unable to verify identity. Please try again.');
      return;
    }

    setLoading(true);
    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: userEmail,
        password: currentPassword
      });

      if (signInError) {
        setPasswordError('Current password is incorrect');
        setLoading(false);
        return;
      }

      if (mfaEnabled && !needsMfaForPassword) {
        setNeedsMfaForPassword(true);
        setLoading(false);
        return;
      }

      if (mfaEnabled && needsMfaForPassword) {
        if (!passwordMfaCode || passwordMfaCode.length !== 6) {
          setPasswordError('Please enter a valid 6-digit 2FA code');
          setLoading(false);
          return;
        }

        const { data: challengeData, error: challengeError } = await supabase.auth.mfa.challenge({
          factorId: mfaFactorId
        });

        if (challengeError) {
          setPasswordError('Failed to initiate 2FA verification. Please try again.');
          setLoading(false);
          return;
        }

        const { error: verifyError } = await supabase.auth.mfa.verify({
          factorId: mfaFactorId,
          challengeId: challengeData.id,
          code: passwordMfaCode
        });

        if (verifyError) {
          setPasswordError('Invalid 2FA code. Please try again.');
          setLoading(false);
          return;
        }
      }

      const { error } = await supabase.auth.updateUser({
        password: newPassword
      });

      if (error) throw error;

      setPasswordSuccess('Password updated successfully!');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setNeedsMfaForPassword(false);
      setPasswordMfaCode('');

      setTimeout(() => setPasswordSuccess(''), 3000);
    } catch (error: any) {
      console.error('Error updating password:', error);
      setPasswordError(error.message || 'Failed to update password');
    } finally {
      setLoading(false);
    }
  };

  const handlePasswordReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setResetError('');
    setResetEmailSent(false);

    if (!emailForReset) {
      setResetError('Please enter your email address');
      return;
    }

    setLoading(true);
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(emailForReset, {
        redirectTo: `${window.location.origin}/profile`,
      });

      if (error) throw error;

      setResetEmailSent(true);
      setEmailForReset('');
    } catch (error: any) {
      console.error('Error sending reset email:', error);
      setResetError(error.message || 'Failed to send reset email');
    } finally {
      setLoading(false);
    }
  };

  const handleEnableMFA = async () => {
    setMfaError('');
    setMfaSuccess('');
    setLoading(true);

    try {
      const enrolled = await enrollMfaWithRecovery();

      setMfaQRCode(enrolled.totp.qr_code);
      setMfaSecret(enrolled.totp.secret);
      setMfaFactorId(enrolled.id);
      setMfaEnrolling(true);
    } catch (error: any) {
      console.error('Error enrolling MFA:', error?.message, error?.code, error);
      const msg = error?.message || '';
      const normalizedMsg = msg.toLowerCase();
      if (normalizedMsg.includes('session') || normalizedMsg.includes('expired') || normalizedMsg.includes('token')) {
        setMfaError('Your session has expired. Please sign out, sign back in, and try again.');
      } else if (normalizedMsg.includes('factor') || normalizedMsg.includes('limit') || normalizedMsg.includes('already')) {
        setMfaError('We could not start 2FA automatically after several recovery attempts. Please sign out, sign back in, and try again.');
      } else if (normalizedMsg.includes('fetch') || normalizedMsg.includes('network')) {
        setMfaError('Network error while starting 2FA setup. Please check your connection and try again.');
      } else {
        setMfaError(msg ? `Failed to start 2FA setup: ${msg}` : 'Failed to start 2FA setup. Please sign out, sign back in, and try again.');
      }
      setMfaEnrolling(false);
    } finally {
      setLoading(false);
    }
  };

  const handleStartOver = async () => {
    await handleCancelMFA();
    setTimeout(() => handleEnableMFA(), 300);
  };

  const handleVerifyMFA = async () => {
    if (!verificationCode || verificationCode.length !== 6) {
      setMfaError('Please enter a 6-digit code');
      return;
    }

    setMfaError('');
    setLoading(true);

    try {
      const { data: challengeData, error: challengeError } = await supabase.auth.mfa.challenge({
        factorId: mfaFactorId
      });

      if (challengeError) throw challengeError;

      const { error: verifyError } = await supabase.auth.mfa.verify({
        factorId: mfaFactorId,
        challengeId: challengeData.id,
        code: verificationCode
      });

      if (verifyError) throw verifyError;

      setMfaEnabled(true);
      setMfaEnrolling(false);
      setMfaSuccess('2FA enabled successfully!');
      setVerificationCode('');
      setMfaQRCode('');
      setMfaSecret('');

      setTimeout(() => setMfaSuccess(''), 3000);
    } catch (error: any) {
      console.error('Error verifying MFA:', error);

      if (error.message?.includes('challenge') || error.message?.includes('not found') || error.message?.includes('expired')) {
        setMfaError('Session expired. Click "Start Over" to get a fresh QR code.');
      } else {
        setMfaError('Invalid code. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleDisableMFA = async () => {
    if (!confirm('Are you sure you want to disable 2FA?')) return;

    setMfaError('');
    setLoading(true);

    try {
      await supabase.auth.mfa.unenroll({ factorId: mfaFactorId });
      setMfaEnabled(false);
      setMfaFactorId('');
      setMfaSuccess('2FA disabled');
      setTimeout(() => setMfaSuccess(''), 3000);
    } catch (error: any) {
      console.error('Error disabling MFA:', error);
      setMfaError('Failed to disable 2FA');
    } finally {
      setLoading(false);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  const handleCancelMFA = async () => {
    if (mfaFactorId) {
      try {
        await supabase.auth.mfa.unenroll({ factorId: mfaFactorId });
      } catch (error) {
        console.error('Failed to cancel MFA enrollment:', error);
      }
    }
    setMfaEnrolling(false);
    setMfaQRCode('');
    setMfaSecret('');
    setMfaFactorId('');
    setVerificationCode('');
    setMfaError('');
  };

  const cleanupUnverifiedMfaFactors = async () => {
    await supabase.auth.refreshSession();

    for (let attempt = 0; attempt < 4; attempt++) {
      const { data: factors } = await supabase.auth.mfa.listFactors();

      const verifiedFactor = factors?.totp?.find((factor: any) => factor.status === 'verified');
      if (verifiedFactor) {
        setMfaEnabled(true);
        setMfaFactorId(verifiedFactor.id);
        throw new Error('2FA is already enabled on this account.');
      }

      const unverified = factors?.totp?.filter((factor: any) => factor.status === 'unverified') || [];
      if (unverified.length === 0) {
        return;
      }

      const cleanupResults = await Promise.allSettled(
        unverified.map((factor: any) => supabase.auth.mfa.unenroll({ factorId: factor.id }))
      );

      cleanupResults.forEach((result, index) => {
        if (result.status === 'rejected') {
          console.error('Failed to clean up unverified factor:', unverified[index]?.id, result.reason);
        }
      });

      await new Promise((resolve) => setTimeout(resolve, 500));
      await supabase.auth.refreshSession();
    }

    const { data: finalFactors } = await supabase.auth.mfa.listFactors();
    const remainingUnverified = finalFactors?.totp?.filter((factor: any) => factor.status === 'unverified') || [];
    if (remainingUnverified.length > 0) {
      throw new Error('There is a stuck 2FA setup on your account.');
    }
  };

  const enrollMfaWithRecovery = async () => {
    await cleanupUnverifiedMfaFactors();

    const attemptEnroll = async (attemptNumber: number) => {
      const friendlyName = attemptNumber === 0
        ? 'Authenticator App'
        : `Authenticator App ${Date.now()}-${attemptNumber}`;

      const { data, error } = await supabase.auth.mfa.enroll({
        factorType: 'totp',
        friendlyName
      });

      if (error) throw error;
      return data;
    };

    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        return await attemptEnroll(attempt);
      } catch (error: any) {
        const msg = error?.message || '';
        if (!(msg.includes('factor') || msg.includes('limit') || msg.includes('already'))) {
          throw error;
        }

        await cleanupUnverifiedMfaFactors();
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
    }

    throw new Error('There is a stuck 2FA setup on your account.');
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold mb-6">Security</h2>

      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <div className="flex items-center gap-3 mb-6">
          <Lock className="w-6 h-6 text-[#f0b90b]" />
          <h3 className="text-xl font-semibold">Change Password</h3>
        </div>

        {passwordSuccess && (
          <div className="mb-4 p-4 bg-emerald-500/20 border border-emerald-500/50 rounded-lg flex items-center gap-2 text-emerald-400">
            <CheckCircle className="w-5 h-5" />
            <span>{passwordSuccess}</span>
          </div>
        )}

        {passwordError && (
          <div className="mb-4 p-4 bg-red-500/20 border border-red-500/50 rounded-lg flex items-center gap-2 text-red-400">
            <AlertCircle className="w-5 h-5" />
            <span>{passwordError}</span>
          </div>
        )}

        {mfaEnabled && (
          <div className="mb-4 p-4 bg-amber-500/20 border border-amber-500/50 rounded-lg flex items-center gap-2 text-amber-400">
            <Shield className="w-5 h-5" />
            <span>2FA verification is required to change your password.</span>
          </div>
        )}

        <form onSubmit={handlePasswordChange} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Current Password
            </label>
            <div className="relative">
              <input
                type={showCurrentPassword ? 'text' : 'password'}
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white pr-12 outline-none focus:border-[#f0b90b] transition-colors"
                placeholder="Enter current password"
                required
              />
              <button
                type="button"
                onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-300"
              >
                {showCurrentPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              New Password
            </label>
            <div className="relative">
              <input
                type={showNewPassword ? 'text' : 'password'}
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white pr-12 outline-none focus:border-[#f0b90b] transition-colors"
                placeholder="Enter new password"
                required
                minLength={8}
              />
              <button
                type="button"
                onClick={() => setShowNewPassword(!showNewPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-300"
              >
                {showNewPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>
            <p className="text-xs text-gray-500 mt-1">
              Password must be at least 8 characters long
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Confirm New Password
            </label>
            <div className="relative">
              <input
                type={showConfirmPassword ? 'text' : 'password'}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white pr-12 outline-none focus:border-[#f0b90b] transition-colors"
                placeholder="Confirm new password"
                required
              />
              <button
                type="button"
                onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-300"
              >
                {showConfirmPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>
          </div>

          {needsMfaForPassword && (
            <div className="p-4 bg-[#0b0e11] border border-[#f0b90b]/50 rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Smartphone className="w-5 h-5 text-[#f0b90b]" />
                <label className="text-sm font-medium text-white">
                  Enter 2FA Code from Authenticator App
                </label>
              </div>
              <input
                type="text"
                value={passwordMfaCode}
                onChange={(e) => setPasswordMfaCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                className="w-full bg-[#181a20] border border-gray-700 rounded-lg px-4 py-3 text-white text-center text-xl tracking-widest outline-none focus:border-[#f0b90b] font-mono"
                placeholder="000000"
                maxLength={6}
                autoComplete="off"
              />
              <p className="text-xs text-gray-500 mt-2 text-center">
                Open your authenticator app and enter the 6-digit code
              </p>
            </div>
          )}

          <button
            type="submit"
            disabled={loading || (needsMfaForPassword && passwordMfaCode.length !== 6)}
            className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Updating...' : needsMfaForPassword ? 'Verify & Update Password' : 'Update Password'}
          </button>

          {needsMfaForPassword && (
            <button
              type="button"
              onClick={() => {
                setNeedsMfaForPassword(false);
                setPasswordMfaCode('');
                setPasswordError('');
              }}
              className="w-full bg-[#2b3139] hover:bg-[#3b4149] text-white font-semibold py-3 rounded-lg transition-colors"
            >
              Cancel
            </button>
          )}
        </form>
      </div>

      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <div className="flex items-center gap-3 mb-6">
          <Key className="w-6 h-6 text-[#f0b90b]" />
          <h3 className="text-xl font-semibold">Password Reset via Email</h3>
        </div>

        {resetEmailSent && (
          <div className="mb-4 p-4 bg-emerald-500/20 border border-emerald-500/50 rounded-lg flex items-center gap-2 text-emerald-400">
            <CheckCircle className="w-5 h-5" />
            <span>Password reset email sent! Check your inbox.</span>
          </div>
        )}

        {resetError && (
          <div className="mb-4 p-4 bg-red-500/20 border border-red-500/50 rounded-lg flex items-center gap-2 text-red-400">
            <AlertCircle className="w-5 h-5" />
            <span>{resetError}</span>
          </div>
        )}

        <p className="text-sm text-gray-400 mb-4">
          If you forgot your password, we can send you a password reset link to your email address.
        </p>

        <form onSubmit={handlePasswordReset} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Email Address
            </label>
            <input
              type="email"
              value={emailForReset}
              onChange={(e) => setEmailForReset(e.target.value)}
              className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
              placeholder="Enter your email address"
              required
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#2b3139] hover:bg-[#3b4149] text-white font-semibold py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Sending...' : 'Send Reset Link'}
          </button>
        </form>
      </div>

      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <Shield className="w-6 h-6 text-[#f0b90b]" />
            <div>
              <h3 className="text-xl font-semibold">Two-Factor Authentication (2FA)</h3>
              <p className="text-sm text-gray-400 mt-1">
                Add an extra layer of security to your account
              </p>
            </div>
          </div>
          <div className={`px-3 py-1 rounded-full text-xs font-medium ${
            mfaEnabled ? 'bg-emerald-500/20 text-emerald-400' : 'bg-gray-500/20 text-gray-400'
          }`}>
            {mfaEnabled ? 'Enabled' : 'Disabled'}
          </div>
        </div>

        {mfaSuccess && (
          <div className="mb-4 p-4 bg-emerald-500/20 border border-emerald-500/50 rounded-lg flex items-center gap-2 text-emerald-400">
            <CheckCircle className="w-5 h-5" />
            <span>{mfaSuccess}</span>
          </div>
        )}

        {mfaError && (
          <div className="mb-4 p-4 bg-red-500/20 border border-red-500/50 rounded-lg flex items-center gap-2 text-red-400">
            <AlertCircle className="w-5 h-5" />
            <span>{mfaError}</span>
          </div>
        )}

        {!mfaEnabled && !mfaEnrolling && (
          <div>
            <p className="text-sm text-gray-400 mb-4">
              Secure your account with Google Authenticator, Authy, or Microsoft Authenticator.
            </p>
            <button
              onClick={handleEnableMFA}
              disabled={loading}
              className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3 rounded-lg transition-colors flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Smartphone className="w-5 h-5" />
              {loading ? 'Starting...' : 'Enable 2FA'}
            </button>
          </div>
        )}

        {mfaEnrolling && mfaQRCode && (
          <div className="space-y-5">
            <div className="border-t border-gray-800 pt-5">
              <h4 className="font-semibold mb-3 flex items-center gap-2">
                <QrCode className="w-5 h-5 text-[#f0b90b]" />
                Scan QR Code
              </h4>

              <div className="flex justify-center mb-5">
                <div className="bg-white rounded-xl p-4">
                  <img src={mfaQRCode} alt="2FA QR Code" className="w-48 h-48" />
                </div>
              </div>

              <details className="mb-4">
                <summary className="text-sm text-gray-400 cursor-pointer hover:text-gray-300">
                  Can't scan? Click for manual setup
                </summary>
                <div className="mt-3 p-3 bg-[#0b0e11] border border-gray-700 rounded-lg">
                  <code className="text-xs font-mono text-white break-all select-all">{mfaSecret}</code>
                  <button
                    onClick={() => copyToClipboard(mfaSecret)}
                    className="ml-2 text-[#f0b90b] text-xs hover:underline"
                  >
                    Copy
                  </button>
                </div>
              </details>
            </div>

            <div className="border-t border-gray-800 pt-5">
              <h4 className="font-semibold mb-3 flex items-center gap-2">
                <Smartphone className="w-5 h-5 text-[#f0b90b]" />
                Enter 6-Digit Code
              </h4>
              <div className="flex gap-3">
                <input
                  ref={verificationInputRef}
                  type="text"
                  value={verificationCode}
                  onChange={(e) => setVerificationCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  onKeyPress={(e) => {
                    if (e.key === 'Enter' && verificationCode.length === 6 && !loading) {
                      handleVerifyMFA();
                    }
                  }}
                  className="flex-1 bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white text-center text-xl tracking-widest outline-none focus:border-[#f0b90b] font-mono"
                  placeholder="000000"
                  maxLength={6}
                  autoComplete="off"
                />
                <button
                  onClick={handleVerifyMFA}
                  disabled={loading || verificationCode.length !== 6}
                  className="px-6 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold rounded-lg transition-colors disabled:opacity-50"
                >
                  {loading ? '...' : 'Verify'}
                </button>
              </div>
            </div>

            <div className="flex gap-3">
              {mfaError && mfaError.includes('expired') && (
                <button
                  onClick={handleStartOver}
                  disabled={loading}
                  className="flex-1 bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3 rounded-lg transition-colors disabled:opacity-50"
                >
                  Start Over
                </button>
              )}
              <button
                onClick={handleCancelMFA}
                disabled={loading}
                className="flex-1 bg-[#2b3139] hover:bg-[#3b4149] text-white font-semibold py-3 rounded-lg transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
            </div>
          </div>
        )}

        {mfaEnabled && (
          <div>
            <div className="p-4 bg-emerald-500/10 border border-emerald-500/20 rounded-lg mb-4">
              <div className="flex items-start gap-3">
                <CheckCircle className="w-5 h-5 text-emerald-400 mt-0.5" />
                <div>
                  <p className="text-emerald-400 font-medium">2FA Active</p>
                  <p className="text-sm text-gray-400 mt-1">
                    Your account is protected. You'll need a code from your authenticator app when you sign in.
                  </p>
                </div>
              </div>
            </div>
            <button
              onClick={handleDisableMFA}
              disabled={loading}
              className="w-full bg-red-500/20 hover:bg-red-500/30 text-red-400 font-semibold py-3 rounded-lg transition-colors border border-red-500/50 disabled:opacity-50"
            >
              {loading ? '...' : 'Disable 2FA'}
            </button>
          </div>
        )}
      </div>

      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <div className="flex items-center gap-3 mb-6">
          <Globe className="w-6 h-6 text-[#f0b90b]" />
          <div>
            <h3 className="text-xl font-semibold">Verified IPs</h3>
            <p className="text-sm text-gray-400 mt-1">
              Manage IP addresses that you've verified for login
            </p>
          </div>
        </div>

        {ipsLoading ? (
          <div className="text-center py-8">
            <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]"></div>
            <p className="text-gray-400 mt-2">Loading verified IPs...</p>
          </div>
        ) : verifiedIPs.length === 0 ? (
          <div className="text-center py-8">
            <Globe className="w-12 h-12 text-gray-600 mx-auto mb-3" />
            <p className="text-gray-400">No verified IPs yet</p>
            <p className="text-sm text-gray-500 mt-1">
              When you log in from a new location, you'll be asked to verify. Verified IPs will appear here.
            </p>
          </div>
        ) : (
          <>
            <div className="space-y-3">
              {verifiedIPs
                .slice((ipPage - 1) * ipsPerPage, ipPage * ipsPerPage)
                .map((ip) => (
                <div
                  key={ip.id}
                  className="bg-[#0b0e11] border border-gray-700 rounded-lg p-4 hover:border-gray-600 transition-colors"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <Globe className="w-4 h-4 text-[#f0b90b] flex-shrink-0" />
                        <span className="text-sm font-medium text-white font-mono">
                          {ip.ip_address}
                        </span>
                      </div>

                      <div className="space-y-1">
                        <div className="flex items-center gap-2 text-xs text-gray-400">
                          <MapPin className="w-3 h-3 flex-shrink-0" />
                          <span>
                            {ip.location?.city && ip.location?.country
                              ? `${ip.location.city}, ${ip.location.country}`
                              : 'Unknown Location'
                            }
                          </span>
                        </div>

                        {ip.device_info && (
                          <div className="text-xs text-gray-500 truncate">
                            Device: {ip.device_info}
                          </div>
                        )}

                        <div className="flex items-center gap-2 text-xs text-gray-500">
                          <Clock className="w-3 h-3 flex-shrink-0" />
                          <span>Last used: {formatDate(ip.last_used)}</span>
                        </div>

                        {ip.trust_expires_at && (
                          <div className="text-xs text-gray-500">
                            Expires: {formatDate(ip.trust_expires_at)}
                          </div>
                        )}
                      </div>
                    </div>

                    <button
                      onClick={() => setIpToRevoke(ip)}
                      className="p-2 text-gray-400 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-all flex-shrink-0"
                      title="Remove verified IP"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {verifiedIPs.length > ipsPerPage && (
              <div className="flex items-center justify-between mt-4 pt-4 border-t border-gray-800">
                <span className="text-sm text-gray-400">
                  Showing {((ipPage - 1) * ipsPerPage) + 1}-{Math.min(ipPage * ipsPerPage, verifiedIPs.length)} of {verifiedIPs.length}
                </span>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setIpPage(p => Math.max(1, p - 1))}
                    disabled={ipPage === 1}
                    className="p-2 bg-[#0b0e11] border border-gray-700 rounded-lg text-gray-400 hover:text-white hover:border-gray-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                  >
                    <ChevronLeft className="w-4 h-4" />
                  </button>
                  <span className="text-sm text-gray-400 min-w-[80px] text-center">
                    Page {ipPage} of {Math.ceil(verifiedIPs.length / ipsPerPage)}
                  </span>
                  <button
                    onClick={() => setIpPage(p => Math.min(Math.ceil(verifiedIPs.length / ipsPerPage), p + 1))}
                    disabled={ipPage >= Math.ceil(verifiedIPs.length / ipsPerPage)}
                    className="p-2 bg-[#0b0e11] border border-gray-700 rounded-lg text-gray-400 hover:text-white hover:border-gray-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                  >
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>
              </div>
            )}
          </>
        )}

        <div className="mt-4 p-4 bg-[#0b0e11]/50 border border-gray-800 rounded-lg">
          <p className="text-xs text-gray-400">
            <strong className="text-gray-300">Security Tip:</strong> Review your verified IPs regularly and remove any you don't recognize. Each IP will need to be re-verified 30 days after it was last trusted.
          </p>
        </div>
      </div>

      <div className="bg-[#181a20] border border-gray-800 rounded-lg p-6">
        <WhitelistWallets mfaEnabled={mfaEnabled} />
      </div>

      {ipToRevoke && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#181a20] border border-gray-700 rounded-xl max-w-md w-full p-6 shadow-2xl">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 bg-red-500/20 rounded-full flex items-center justify-center">
                <AlertCircle className="w-5 h-5 text-red-400" />
              </div>
              <h3 className="text-lg font-bold text-white">Remove Verified IP?</h3>
            </div>

            <p className="text-gray-400 text-sm mb-4">
              You will need to verify again when logging in from this location.
            </p>

            <div className="bg-[#0b0e11] border border-gray-700 rounded-lg p-4 mb-6 space-y-2">
              <div className="flex items-center gap-2">
                <Globe className="w-4 h-4 text-[#f0b90b]" />
                <span className="text-white font-mono text-sm">{ipToRevoke.ip_address}</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-400">
                <MapPin className="w-4 h-4" />
                <span>
                  {ipToRevoke.location?.city && ipToRevoke.location?.country
                    ? `${ipToRevoke.location.city}, ${ipToRevoke.location.country}`
                    : 'Unknown Location'
                  }
                </span>
              </div>
              {ipToRevoke.device_info && (
                <div className="text-xs text-gray-500 truncate">
                  {ipToRevoke.device_info}
                </div>
              )}
              <div className="flex items-center gap-2 text-xs text-gray-500">
                <Clock className="w-3 h-3" />
                <span>Last used: {formatDate(ipToRevoke.last_used)}</span>
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setIpToRevoke(null)}
                disabled={revoking}
                className="flex-1 bg-gray-700 hover:bg-gray-600 disabled:opacity-50 text-white font-semibold py-3 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleRevokeVerifiedIP}
                disabled={revoking}
                className="flex-1 bg-red-600 hover:bg-red-500 disabled:opacity-50 text-white font-semibold py-3 rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                {revoking ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Removing...
                  </>
                ) : (
                  'Remove IP'
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
