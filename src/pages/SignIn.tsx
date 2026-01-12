import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import { useAuth } from '../context/AuthContext';
import { Eye, EyeOff, Shield, ArrowLeft } from 'lucide-react';
import Navbar from '../components/Navbar';

function SignIn() {
  const { navigateTo } = useNavigation();
  const { signIn, verifyMfa, sendIpVerification, verifyIpCode, isAuthenticated, loading: authLoading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const [showMfaStep, setShowMfaStep] = useState(false);
  const [mfaFactorId, setMfaFactorId] = useState('');
  const [mfaCode, setMfaCode] = useState('');

  const [showIpVerification, setShowIpVerification] = useState(false);
  const [ipCode, setIpCode] = useState('');
  const [pendingUserId, setPendingUserId] = useState('');
  const [resendTimer, setResendTimer] = useState(0);

  useEffect(() => {
    if (!authLoading && isAuthenticated && !showMfaStep && !showIpVerification) {
      navigateTo('home');
    }
  }, [authLoading, isAuthenticated, showMfaStep, showIpVerification]);

  useEffect(() => {
    if (resendTimer > 0) {
      const timer = setTimeout(() => setResendTimer(resendTimer - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [resendTimer]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!email || !password) {
      setError('Please fill in all fields');
      return;
    }

    setLoading(true);
    const result = await signIn(email, password);
    setLoading(false);

    if (result.error) {
      setError(result.error.message);
      return;
    }

    if (result.mfaRequired && result.factorId) {
      setMfaFactorId(result.factorId);
      setShowMfaStep(true);
      return;
    }

    if (result.ipVerificationRequired && result.pendingUserId) {
      setPendingUserId(result.pendingUserId);
      setShowIpVerification(true);

      const sendResult = await sendIpVerification(result.pendingUserId, email);
      if (sendResult.error) {
        setError('Failed to send verification code. Please try again.');
      } else {
        setResendTimer(60);
      }
      return;
    }

    navigateTo('home');
  };

  const handleMfaVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!mfaCode || mfaCode.length !== 6) {
      setError('Please enter a valid 6-digit code');
      return;
    }

    setLoading(true);
    const { error } = await verifyMfa(mfaFactorId, mfaCode);
    setLoading(false);

    if (error) {
      setError('Invalid verification code. Please try again.');
      return;
    }

    navigateTo('home');
  };

  const handleBackToLogin = () => {
    setShowMfaStep(false);
    setMfaCode('');
    setMfaFactorId('');
    setShowIpVerification(false);
    setIpCode('');
    setPendingUserId('');
    setError('');
  };

  const handleIpVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!ipCode || ipCode.length !== 6) {
      setError('Please enter a valid 6-digit code');
      return;
    }

    setLoading(true);

    const verifyResult = await verifyIpCode(ipCode, pendingUserId);

    if (verifyResult.error) {
      setError(verifyResult.error.message || 'Invalid or expired code. Please try again.');
      setLoading(false);
      return;
    }

    const signInResult = await signIn(email, password);
    setLoading(false);

    if (signInResult.error) {
      setError(signInResult.error.message);
      return;
    }

    navigateTo('home');
  };

  const handleResendCode = async () => {
    if (resendTimer > 0) return;

    setError('');
    setLoading(true);
    const { error } = await sendIpVerification(pendingUserId, email);
    setLoading(false);

    if (error) {
      setError('Failed to resend code. Please try again.');
    } else {
      setResendTimer(60);
    }
  };

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
            {showIpVerification ? (
              <>
                <div className="mb-8">
                  <button
                    onClick={handleBackToLogin}
                    className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-4"
                  >
                    <ArrowLeft className="w-4 h-4" />
                    <span className="text-sm">Back to Login</span>
                  </button>
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-12 h-12 bg-[#f0b90b]/20 rounded-full flex items-center justify-center">
                      <Shield className="w-6 h-6 text-[#f0b90b]" />
                    </div>
                    <div>
                      <h1 className="text-2xl font-bold text-white">New Location Detected</h1>
                      <p className="text-sm text-gray-400">Enter the code sent to your email</p>
                    </div>
                  </div>
                  <div className="border-b-2 border-[#f0b90b] w-12" />
                </div>

                <form onSubmit={handleIpVerify} className="space-y-6">
                  <div>
                    <label className="block text-sm text-gray-400 mb-3">
                      Verification Code
                    </label>
                    <input
                      type="text"
                      inputMode="numeric"
                      autoComplete="one-time-code"
                      value={ipCode}
                      onChange={(e) => setIpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                      placeholder="000000"
                      className="w-full bg-[#252837] border-0 rounded-lg px-4 py-4 text-white text-center text-2xl tracking-[0.5em] font-mono placeholder-gray-600 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
                      maxLength={6}
                      autoFocus
                    />
                    <p className="text-xs text-gray-500 mt-2 text-center">
                      Check your email for the verification code
                    </p>
                  </div>

                  {error && (
                    <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-3">
                      <p className="text-red-500 text-sm">{error}</p>
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading || ipCode.length !== 6}
                    className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3.5 rounded-lg transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading ? 'Verifying...' : 'Verify & Sign In'}
                  </button>
                </form>

                <div className="mt-6 p-4 bg-[#252837] rounded-lg space-y-3">
                  <p className="text-xs text-gray-400 text-center">
                    We detected a login from a new location. For your security, we've sent a verification code to your email.
                  </p>
                  <div className="flex justify-center">
                    <button
                      onClick={handleResendCode}
                      disabled={resendTimer > 0 || loading}
                      className="text-sm text-[#f0b90b] hover:text-[#f8d12f] disabled:text-gray-500 disabled:cursor-not-allowed transition-colors"
                    >
                      {resendTimer > 0 ? `Resend code in ${resendTimer}s` : 'Resend code'}
                    </button>
                  </div>
                </div>
              </>
            ) : !showMfaStep ? (
              <>
                <div className="mb-8">
                  <div className="flex items-center justify-between mb-4">
                    <h1 className="text-2xl font-bold text-white">Log In</h1>
                    <button
                      onClick={() => navigateTo('signup')}
                      className="text-[#f0b90b] hover:underline text-sm flex items-center gap-1"
                    >
                      <span>⇄</span> Register Now
                    </button>
                  </div>
                  <div className="border-b-2 border-[#f0b90b] w-12" />
                </div>

                <form onSubmit={handleSubmit} className="space-y-5">
                  <div>
                    <label htmlFor="email" className="block text-sm text-gray-400 mb-2">
                      Email
                    </label>
                    <input
                      id="email"
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="Enter Email"
                      className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
                    />
                  </div>

                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label htmlFor="password" className="block text-sm text-gray-400">
                        Password
                      </label>
                      <button
                        type="button"
                        onClick={() => navigateTo('forgotpassword')}
                        className="text-xs text-[#f0b90b] hover:text-[#f8d12f] hover:underline transition-colors"
                      >
                        Forgot Password?
                      </button>
                    </div>
                    <div className="relative">
                      <input
                        id="password"
                        type={showPassword ? 'text' : 'password'}
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="Enter Password"
                        className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 pr-12 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
                      />
                      <button
                        type="button"
                        onClick={() => setShowPassword(!showPassword)}
                        className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-400 transition-colors"
                      >
                        {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                      </button>
                    </div>
                  </div>

                  {error && (
                    <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-3">
                      <p className="text-red-500 text-sm">{error}</p>
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-[#3d4356] hover:bg-[#4a5168] text-white font-medium py-3.5 rounded-lg transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading ? 'Signing in...' : 'Next'}
                  </button>
                </form>

                <div className="mt-8 text-center">
                  <button
                    onClick={() => navigateTo('home')}
                    className="text-gray-500 hover:text-gray-400 text-sm transition-colors"
                  >
                    Back to Home
                  </button>
                </div>
              </>
            ) : (
              <>
                <div className="mb-8">
                  <button
                    onClick={handleBackToLogin}
                    className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-4"
                  >
                    <ArrowLeft className="w-4 h-4" />
                    <span className="text-sm">Back to Login</span>
                  </button>
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-12 h-12 bg-[#f0b90b]/20 rounded-full flex items-center justify-center">
                      <Shield className="w-6 h-6 text-[#f0b90b]" />
                    </div>
                    <div>
                      <h1 className="text-2xl font-bold text-white">2FA Verification</h1>
                      <p className="text-sm text-gray-400">Enter the code from your authenticator app</p>
                    </div>
                  </div>
                  <div className="border-b-2 border-[#f0b90b] w-12" />
                </div>

                <form onSubmit={handleMfaVerify} className="space-y-6">
                  <div>
                    <label className="block text-sm text-gray-400 mb-3">
                      Verification Code
                    </label>
                    <input
                      type="text"
                      inputMode="numeric"
                      autoComplete="one-time-code"
                      value={mfaCode}
                      onChange={(e) => setMfaCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                      placeholder="000000"
                      className="w-full bg-[#252837] border-0 rounded-lg px-4 py-4 text-white text-center text-2xl tracking-[0.5em] font-mono placeholder-gray-600 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
                      maxLength={6}
                      autoFocus
                    />
                    <p className="text-xs text-gray-500 mt-2 text-center">
                      Open your authenticator app to view your code
                    </p>
                  </div>

                  {error && (
                    <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-3">
                      <p className="text-red-500 text-sm">{error}</p>
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading || mfaCode.length !== 6}
                    className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3.5 rounded-lg transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {loading ? 'Verifying...' : 'Verify & Sign In'}
                  </button>
                </form>

                <div className="mt-6 p-4 bg-[#252837] rounded-lg">
                  <p className="text-xs text-gray-400 text-center">
                    Having trouble? Make sure your authenticator app time is synced correctly.
                    If you've lost access to your authenticator, contact support.
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

export default SignIn;
