import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import { Lock, Eye, EyeOff, CheckCircle, AlertCircle, ArrowLeft, Shield } from 'lucide-react';
import { supabase } from '../lib/supabase';
import Navbar from '../components/Navbar';

function ResetPassword() {
  const { navigateTo } = useNavigation();
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [tokenValid, setTokenValid] = useState<boolean | null>(null);
  const [checkingToken, setCheckingToken] = useState(true);

  useEffect(() => {
    const checkSession = async () => {
      setCheckingToken(true);

      const hashParams = new URLSearchParams(window.location.hash.substring(1));
      const accessToken = hashParams.get('access_token');
      const type = hashParams.get('type');

      if (type === 'recovery' && accessToken) {
        try {
          const { data, error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: hashParams.get('refresh_token') || '',
          });

          if (error) {
            console.error('Session error:', error);
            setTokenValid(false);
          } else if (data.session) {
            setTokenValid(true);
          } else {
            setTokenValid(false);
          }
        } catch (err) {
          console.error('Token validation error:', err);
          setTokenValid(false);
        }
      } else {
        const { data: { session } } = await supabase.auth.getSession();
        if (session) {
          setTokenValid(true);
        } else {
          setTokenValid(false);
        }
      }

      setCheckingToken(false);
    };

    checkSession();
  }, []);

  const validatePassword = (password: string): string | null => {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!/[A-Z]/.test(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!/[a-z]/.test(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!/[0-9]/.test(password)) {
      return 'Password must contain at least one number';
    }
    return null;
  };

  const getPasswordStrength = (password: string): { level: number; label: string; color: string } => {
    let score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (/[A-Z]/.test(password)) score++;
    if (/[a-z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^A-Za-z0-9]/.test(password)) score++;

    if (score <= 2) return { level: 1, label: 'Weak', color: 'bg-red-500' };
    if (score <= 4) return { level: 2, label: 'Medium', color: 'bg-yellow-500' };
    return { level: 3, label: 'Strong', color: 'bg-emerald-500' };
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    const passwordError = validatePassword(newPassword);
    if (passwordError) {
      setError(passwordError);
      return;
    }

    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);

    try {
      const { error: updateError } = await supabase.auth.updateUser({
        password: newPassword,
      });

      if (updateError) throw updateError;

      await supabase.auth.signOut();
      setSuccess(true);
    } catch (err: any) {
      console.error('Password update error:', err);
      setError(err.message || 'Failed to update password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const passwordStrength = getPasswordStrength(newPassword);

  if (checkingToken) {
    return (
      <>
        <Navbar />
        <div className="min-h-screen bg-black flex items-center justify-center p-6">
          <div className="text-center">
            <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b] mb-4"></div>
            <p className="text-gray-400">Verifying reset link...</p>
          </div>
        </div>
      </>
    );
  }

  if (tokenValid === false) {
    return (
      <>
        <Navbar />
        <div className="min-h-screen bg-black flex items-center justify-center p-6 relative overflow-hidden">
          <div className="absolute inset-0 overflow-hidden pointer-events-none">
            <div className="absolute top-10 left-10 w-72 h-72 bg-[#f0b90b] rounded-full filter blur-3xl opacity-20 animate-blob" />
            <div className="absolute top-20 right-20 w-96 h-96 bg-[#d9a506] rounded-full filter blur-3xl opacity-20 animate-blob animation-delay-2000" />
          </div>

          <div className="w-full max-w-md relative z-10">
            <div className="relative bg-[#1a1d29] rounded-2xl p-8 border border-gray-800">
              <div className="text-center">
                <div className="w-16 h-16 bg-red-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
                  <AlertCircle className="w-8 h-8 text-red-400" />
                </div>
                <h1 className="text-2xl font-bold text-white mb-2">Link Expired</h1>
                <p className="text-gray-400 mb-6">
                  This password reset link has expired or is invalid.
                </p>

                <div className="space-y-3">
                  <button
                    onClick={() => navigateTo('forgotpassword')}
                    className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3.5 rounded-lg transition-colors"
                  >
                    Request New Link
                  </button>
                  <button
                    onClick={() => navigateTo('signin')}
                    className="w-full text-gray-400 hover:text-white text-sm transition-colors py-2"
                  >
                    Return to Sign In
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <Navbar />
      <div className="min-h-screen bg-black flex items-center justify-center p-6 relative overflow-hidden">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-10 left-10 w-72 h-72 bg-[#f0b90b] rounded-full filter blur-3xl opacity-20 animate-blob" />
          <div className="absolute top-20 right-20 w-96 h-96 bg-[#d9a506] rounded-full filter blur-3xl opacity-20 animate-blob animation-delay-2000" />
          <div className="absolute -bottom-8 left-1/3 w-80 h-80 bg-[#f0b90b] rounded-full filter blur-3xl opacity-20 animate-blob animation-delay-4000" />
          <div className="absolute top-1/2 right-1/4 w-64 h-64 bg-[#f8d12f] rounded-full filter blur-3xl opacity-15 animate-blob animation-delay-3000" />
          <div className="absolute bottom-20 right-10 w-56 h-56 bg-[#f0b90b] rounded-full filter blur-2xl opacity-25 animate-blob animation-delay-1000" />
        </div>

        <div className="w-full max-w-md relative z-10">
          <div className="relative">
            <div className="absolute -inset-4 bg-[#f0b90b]/5 rounded-3xl blur-2xl" />

            <div className="relative bg-[#1a1d29] rounded-2xl p-8 border border-gray-800">
              {!success ? (
                <>
                  <div className="mb-8">
                    <button
                      onClick={() => navigateTo('signin')}
                      className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-4"
                    >
                      <ArrowLeft className="w-4 h-4" />
                      <span className="text-sm">Back to Login</span>
                    </button>
                    <div className="flex items-center gap-3 mb-4">
                      <div className="w-12 h-12 bg-[#f0b90b]/20 rounded-full flex items-center justify-center">
                        <Lock className="w-6 h-6 text-[#f0b90b]" />
                      </div>
                      <div>
                        <h1 className="text-2xl font-bold text-white">Reset Password</h1>
                        <p className="text-sm text-gray-400">Create a new secure password</p>
                      </div>
                    </div>
                    <div className="border-b-2 border-[#f0b90b] w-12" />
                  </div>

                  <form onSubmit={handleSubmit} className="space-y-5">
                    <div>
                      <label className="block text-sm text-gray-400 mb-2">
                        New Password
                      </label>
                      <div className="relative">
                        <input
                          type={showNewPassword ? 'text' : 'password'}
                          value={newPassword}
                          onChange={(e) => setNewPassword(e.target.value)}
                          placeholder="Enter new password"
                          className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 pr-12 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
                          autoFocus
                        />
                        <button
                          type="button"
                          onClick={() => setShowNewPassword(!showNewPassword)}
                          className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-400 transition-colors"
                        >
                          {showNewPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                        </button>
                      </div>

                      {newPassword && (
                        <div className="mt-3">
                          <div className="flex items-center gap-2 mb-2">
                            <div className="flex-1 h-1.5 bg-gray-700 rounded-full overflow-hidden">
                              <div
                                className={`h-full ${passwordStrength.color} transition-all duration-300`}
                                style={{ width: `${(passwordStrength.level / 3) * 100}%` }}
                              />
                            </div>
                            <span className={`text-xs font-medium ${
                              passwordStrength.level === 1 ? 'text-red-400' :
                              passwordStrength.level === 2 ? 'text-yellow-400' : 'text-emerald-400'
                            }`}>
                              {passwordStrength.label}
                            </span>
                          </div>
                        </div>
                      )}
                    </div>

                    <div>
                      <label className="block text-sm text-gray-400 mb-2">
                        Confirm Password
                      </label>
                      <div className="relative">
                        <input
                          type={showConfirmPassword ? 'text' : 'password'}
                          value={confirmPassword}
                          onChange={(e) => setConfirmPassword(e.target.value)}
                          placeholder="Confirm new password"
                          className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 pr-12 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
                        />
                        <button
                          type="button"
                          onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                          className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-400 transition-colors"
                        >
                          {showConfirmPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                        </button>
                      </div>
                      {confirmPassword && newPassword !== confirmPassword && (
                        <p className="text-xs text-red-400 mt-1">Passwords do not match</p>
                      )}
                      {confirmPassword && newPassword === confirmPassword && (
                        <p className="text-xs text-emerald-400 mt-1 flex items-center gap-1">
                          <CheckCircle className="w-3 h-3" /> Passwords match
                        </p>
                      )}
                    </div>

                    <div className="bg-[#252837] rounded-lg p-4">
                      <div className="flex items-start gap-2 mb-3">
                        <Shield className="w-4 h-4 text-[#f0b90b] flex-shrink-0 mt-0.5" />
                        <span className="text-xs text-gray-400 font-medium">Password Requirements</span>
                      </div>
                      <ul className="text-xs text-gray-500 space-y-1.5 ml-6">
                        <li className={newPassword.length >= 8 ? 'text-emerald-400' : ''}>
                          {newPassword.length >= 8 ? '✓' : '•'} At least 8 characters
                        </li>
                        <li className={/[A-Z]/.test(newPassword) ? 'text-emerald-400' : ''}>
                          {/[A-Z]/.test(newPassword) ? '✓' : '•'} One uppercase letter
                        </li>
                        <li className={/[a-z]/.test(newPassword) ? 'text-emerald-400' : ''}>
                          {/[a-z]/.test(newPassword) ? '✓' : '•'} One lowercase letter
                        </li>
                        <li className={/[0-9]/.test(newPassword) ? 'text-emerald-400' : ''}>
                          {/[0-9]/.test(newPassword) ? '✓' : '•'} One number
                        </li>
                      </ul>
                    </div>

                    {error && (
                      <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-3 flex items-start gap-2">
                        <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                        <p className="text-red-500 text-sm">{error}</p>
                      </div>
                    )}

                    <button
                      type="submit"
                      disabled={loading || !newPassword || !confirmPassword || newPassword !== confirmPassword}
                      className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3.5 rounded-lg transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {loading ? 'Updating Password...' : 'Reset Password'}
                    </button>
                  </form>
                </>
              ) : (
                <>
                  <div className="text-center">
                    <div className="w-16 h-16 bg-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
                      <CheckCircle className="w-8 h-8 text-emerald-400" />
                    </div>
                    <h1 className="text-2xl font-bold text-white mb-2">Password Updated!</h1>
                    <p className="text-gray-400 mb-6">
                      Your password has been successfully reset. You can now sign in with your new password.
                    </p>

                    <button
                      onClick={() => navigateTo('signin')}
                      className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3.5 rounded-lg transition-colors"
                    >
                      Sign In Now
                    </button>
                  </div>

                  <div className="mt-6 p-4 bg-[#252837] rounded-lg">
                    <p className="text-xs text-gray-400 text-center">
                      For security, you've been logged out of all sessions. Please sign in again to continue.
                    </p>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

export default ResetPassword;
