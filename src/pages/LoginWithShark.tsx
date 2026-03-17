import { useState, useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase';
import {
  Eye,
  EyeOff,
  CheckCircle,
  AlertTriangle,
  Loader2,
  XCircle,
  Shield,
  ArrowLeft,
  Fish,
} from 'lucide-react';

type Step = 'loading' | 'no-telegram' | 'sign-in' | 'mfa' | 'ip-verify' | 'linking' | 'success' | 'error';

interface TelegramWebApp {
  initData: string;
  initDataUnsafe: {
    user?: {
      id: number;
      username?: string;
      first_name?: string;
    };
  };
  close: () => void;
  ready: () => void;
  expand: () => void;
  MainButton: {
    setText: (text: string) => void;
    show: () => void;
    hide: () => void;
    onClick: (cb: () => void) => void;
    offClick: (cb: () => void) => void;
  };
}

declare global {
  interface Window {
    Telegram?: {
      WebApp?: TelegramWebApp;
    };
  }
}

export default function LoginWithShark() {
  const [step, setStep] = useState<Step>('loading');
  const [initData, setInitData] = useState('');
  const [telegramUser, setTelegramUser] = useState<{ id: number; username?: string; first_name?: string } | null>(null);
  const [errorMessage, setErrorMessage] = useState('');
  const [botUsername, setBotUsername] = useState('satoshiacademybot');

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [formLoading, setFormLoading] = useState(false);
  const [formError, setFormError] = useState('');

  const [mfaFactorId, setMfaFactorId] = useState('');
  const [mfaCode, setMfaCode] = useState('');

  const [ipCode, setIpCode] = useState('');
  const [pendingUserId, setPendingUserId] = useState('');
  const [resendTimer, setResendTimer] = useState(0);

  const initDataRef = useRef('');

  useEffect(() => {
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const hashInitData = hashParams.get('initData');

    const searchParams = new URLSearchParams(window.location.search);
    const queryInitData = searchParams.get('initData');

    const tgWebApp = window.Telegram?.WebApp;

    if (tgWebApp?.initData) {
      tgWebApp.ready();
      tgWebApp.expand();
      setInitData(tgWebApp.initData);
      initDataRef.current = tgWebApp.initData;

      if (tgWebApp.initDataUnsafe?.user) {
        setTelegramUser(tgWebApp.initDataUnsafe.user);
      }
      setStep('sign-in');
    } else if (hashInitData) {
      setInitData(decodeURIComponent(hashInitData));
      initDataRef.current = decodeURIComponent(hashInitData);

      try {
        const parsed = new URLSearchParams(decodeURIComponent(hashInitData));
        const userData = parsed.get('user');
        if (userData) {
          const user = JSON.parse(userData);
          setTelegramUser(user);
        }
      } catch {}
      setStep('sign-in');
    } else if (queryInitData) {
      setInitData(decodeURIComponent(queryInitData));
      initDataRef.current = decodeURIComponent(queryInitData);

      try {
        const parsed = new URLSearchParams(decodeURIComponent(queryInitData));
        const userData = parsed.get('user');
        if (userData) {
          const user = JSON.parse(userData);
          setTelegramUser(user);
        }
      } catch {}
      setStep('sign-in');
    } else {
      setStep('no-telegram');
    }
  }, []);

  useEffect(() => {
    if (resendTimer > 0) {
      const timer = setTimeout(() => setResendTimer(resendTimer - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [resendTimer]);

  const linkAccount = async (accessToken: string) => {
    setStep('linking');

    try {
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/game-bot-webapp-link`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ init_data: initDataRef.current }),
        }
      );

      const data = await response.json();

      if (!response.ok) {
        setErrorMessage(data.error || 'Failed to link account.');
        setStep('error');
        return;
      }

      if (data.bot_username) {
        setBotUsername(data.bot_username);
      }

      setStep('success');
    } catch {
      setErrorMessage('Connection error. Please check your internet and try again.');
      setStep('error');
    }
  };

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');

    if (!email || !password) {
      setFormError('Please fill in all fields');
      return;
    }

    setFormLoading(true);

    try {
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (authError) {
        setFormError(authError.message);
        setFormLoading(false);
        return;
      }

      if (!authData.user) {
        setFormError('Sign in failed. Please try again.');
        setFormLoading(false);
        return;
      }

      const { data: factorsData } = await supabase.auth.mfa.listFactors();
      const verifiedFactor = factorsData?.totp?.find((f: any) => f.status === 'verified');

      if (verifiedFactor) {
        setMfaFactorId(verifiedFactor.id);
        setStep('mfa');
        setFormLoading(false);
        return;
      }

      let ipAddress = 'unknown';
      try {
        const ipRes = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/get-ip-location`);
        const ipData = await ipRes.json();
        ipAddress = ipData?.ip || 'unknown';

        const { data: ipCheckData } = await supabase.rpc('check_ip_trusted', {
          p_user_id: authData.user.id,
          p_ip_address: ipAddress,
        });

        if (!ipCheckData?.is_trusted) {
          await supabase.auth.signOut();
          setPendingUserId(authData.user.id);
          setStep('ip-verify');

          const sendRes = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-ip-verification`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
            },
            body: JSON.stringify({
              email,
              userId: authData.user.id,
              ipAddress,
              deviceInfo: navigator.userAgent,
            }),
          });

          if (sendRes.ok) {
            setResendTimer(60);
          }

          setFormLoading(false);
          return;
        }
      } catch {}

      const { data: { session } } = await supabase.auth.getSession();
      if (session?.access_token) {
        await linkAccount(session.access_token);
      } else {
        setFormError('Session error. Please try again.');
      }
    } catch (err: any) {
      setFormError(err?.message || 'An unexpected error occurred.');
    }

    setFormLoading(false);
  };

  const handleMfaVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');

    if (!mfaCode || mfaCode.length !== 6) {
      setFormError('Please enter a valid 6-digit code');
      return;
    }

    setFormLoading(true);

    try {
      const { error } = await supabase.auth.mfa.challengeAndVerify({
        factorId: mfaFactorId,
        code: mfaCode,
      });

      if (error) {
        setFormError('Invalid verification code. Please try again.');
        setFormLoading(false);
        return;
      }

      const { data: { session } } = await supabase.auth.getSession();
      if (session?.access_token) {
        await linkAccount(session.access_token);
      } else {
        setFormError('Session error after MFA. Please try again.');
      }
    } catch (err: any) {
      setFormError(err?.message || 'Verification failed.');
    }

    setFormLoading(false);
  };

  const handleIpVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');

    if (!ipCode || ipCode.length !== 6) {
      setFormError('Please enter a valid 6-digit code');
      return;
    }

    setFormLoading(true);

    try {
      const verifyRes = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/verify-ip-code`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          code: ipCode,
          userId: pendingUserId,
          trustDurationDays: 30,
        }),
      });

      const verifyData = await verifyRes.json();
      if (!verifyRes.ok) {
        setFormError(verifyData.error || 'Invalid or expired code.');
        setFormLoading(false);
        return;
      }

      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (authError || !authData.session) {
        setFormError('Sign in failed after verification. Please try again.');
        setFormLoading(false);
        return;
      }

      await linkAccount(authData.session.access_token);
    } catch (err: any) {
      setFormError(err?.message || 'Verification failed.');
    }

    setFormLoading(false);
  };

  const handleResendCode = async () => {
    if (resendTimer > 0) return;

    setFormError('');
    setFormLoading(true);

    try {
      const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-ip-verification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          email,
          userId: pendingUserId,
          ipAddress: 'unknown',
          deviceInfo: navigator.userAgent,
        }),
      });

      if (res.ok) {
        setResendTimer(60);
      } else {
        setFormError('Failed to resend code.');
      }
    } catch {
      setFormError('Failed to resend code.');
    }

    setFormLoading(false);
  };

  const handleReturnToGame = () => {
    if (window.Telegram?.WebApp) {
      window.Telegram.WebApp.close();
    } else {
      window.close();
    }
  };

  const handleBackToLogin = () => {
    setStep('sign-in');
    setMfaCode('');
    setMfaFactorId('');
    setIpCode('');
    setPendingUserId('');
    setFormError('');
  };

  return (
    <div className="min-h-screen bg-[#0b0e11] flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center mx-auto mb-4 shadow-lg shadow-emerald-500/20">
            <Fish className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-white">Login with Shark</h1>
          <p className="text-gray-400 mt-1 text-sm">Connect your Shark Trades account</p>
        </div>

        <div className="bg-[#1e2329] rounded-2xl border border-gray-800 overflow-hidden">
          {step === 'loading' && (
            <div className="p-8 flex flex-col items-center gap-4">
              <Loader2 className="w-8 h-8 text-emerald-400 animate-spin" />
              <p className="text-gray-400">Connecting to Telegram...</p>
            </div>
          )}

          {step === 'no-telegram' && (
            <div className="p-8 text-center">
              <div className="w-16 h-16 rounded-full bg-amber-500/20 flex items-center justify-center mx-auto mb-4">
                <AlertTriangle className="w-8 h-8 text-amber-400" />
              </div>
              <h2 className="text-lg font-bold text-white mb-2">Open from Telegram</h2>
              <p className="text-gray-400 text-sm mb-6">
                This page must be opened from within the Telegram game bot. Please go back to the bot and tap "Login with Shark" again.
              </p>
              <a
                href="https://t.me/satoshiacademybot"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center gap-2 w-full py-3 bg-[#2b3139] hover:bg-[#363d47] text-white font-medium rounded-lg transition-colors"
              >
                Open Game Bot
              </a>
            </div>
          )}

          {step === 'sign-in' && (
            <div className="p-6">
              <div className="flex items-center gap-3 mb-6">
                <Shield className="w-5 h-5 text-emerald-400" />
                <h2 className="text-lg font-semibold text-white">Sign in to link</h2>
              </div>

              {telegramUser && (
                <div className="mb-5 p-3 bg-[#2b3139] rounded-lg flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center flex-shrink-0">
                    <span className="text-blue-400 text-sm font-bold">T</span>
                  </div>
                  <div className="min-w-0">
                    <p className="text-xs text-gray-400">Linking Telegram account</p>
                    <p className="text-white text-sm font-medium truncate">
                      {telegramUser.username ? `@${telegramUser.username}` : telegramUser.first_name || `ID: ${telegramUser.id}`}
                    </p>
                  </div>
                </div>
              )}

              <form onSubmit={handleSignIn} className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-1.5">Email</label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full bg-[#2b3139] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500 transition-colors"
                    placeholder="your@email.com"
                    autoComplete="email"
                    autoFocus
                  />
                </div>

                <div>
                  <label className="block text-sm text-gray-400 mb-1.5">Password</label>
                  <div className="relative">
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="w-full bg-[#2b3139] border border-gray-700 rounded-lg px-4 py-3 pr-12 text-white placeholder-gray-500 focus:outline-none focus:border-emerald-500 transition-colors"
                      placeholder="Enter your password"
                      autoComplete="current-password"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white transition-colors"
                    >
                      {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                    </button>
                  </div>
                </div>

                {formError && (
                  <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg flex items-start gap-2">
                    <AlertTriangle className="w-4 h-4 text-red-400 mt-0.5 flex-shrink-0" />
                    <p className="text-red-400 text-sm">{formError}</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={formLoading}
                  className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {formLoading ? (
                    <Loader2 className="w-5 h-5 animate-spin" />
                  ) : (
                    'Sign In & Link'
                  )}
                </button>
              </form>

              <p className="text-center text-gray-500 text-xs mt-4">
                Don't have an account? Sign up on the Shark website first.
              </p>
            </div>
          )}

          {step === 'mfa' && (
            <div className="p-6">
              <button
                onClick={handleBackToLogin}
                className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-4"
              >
                <ArrowLeft className="w-4 h-4" />
                <span className="text-sm">Back to Login</span>
              </button>

              <div className="flex items-center gap-3 mb-6">
                <div className="w-10 h-10 bg-emerald-500/20 rounded-full flex items-center justify-center">
                  <Shield className="w-5 h-5 text-emerald-400" />
                </div>
                <div>
                  <h2 className="text-lg font-semibold text-white">2FA Verification</h2>
                  <p className="text-xs text-gray-400">Enter the code from your authenticator</p>
                </div>
              </div>

              <form onSubmit={handleMfaVerify} className="space-y-5">
                <div>
                  <input
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    value={mfaCode}
                    onChange={(e) => setMfaCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                    placeholder="000000"
                    className="w-full bg-[#2b3139] border border-gray-700 rounded-lg px-4 py-4 text-white text-center text-2xl tracking-[0.5em] font-mono placeholder-gray-600 focus:outline-none focus:border-emerald-500 transition-colors"
                    maxLength={6}
                    autoFocus
                  />
                </div>

                {formError && (
                  <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg flex items-start gap-2">
                    <AlertTriangle className="w-4 h-4 text-red-400 mt-0.5 flex-shrink-0" />
                    <p className="text-red-400 text-sm">{formError}</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={formLoading || mfaCode.length !== 6}
                  className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {formLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : 'Verify & Link'}
                </button>
              </form>
            </div>
          )}

          {step === 'ip-verify' && (
            <div className="p-6">
              <button
                onClick={handleBackToLogin}
                className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-4"
              >
                <ArrowLeft className="w-4 h-4" />
                <span className="text-sm">Back to Login</span>
              </button>

              <div className="flex items-center gap-3 mb-6">
                <div className="w-10 h-10 bg-emerald-500/20 rounded-full flex items-center justify-center">
                  <Shield className="w-5 h-5 text-emerald-400" />
                </div>
                <div>
                  <h2 className="text-lg font-semibold text-white">New Location Detected</h2>
                  <p className="text-xs text-gray-400">Enter the code sent to your email</p>
                </div>
              </div>

              <form onSubmit={handleIpVerify} className="space-y-5">
                <div>
                  <input
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    value={ipCode}
                    onChange={(e) => setIpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                    placeholder="000000"
                    className="w-full bg-[#2b3139] border border-gray-700 rounded-lg px-4 py-4 text-white text-center text-2xl tracking-[0.5em] font-mono placeholder-gray-600 focus:outline-none focus:border-emerald-500 transition-colors"
                    maxLength={6}
                    autoFocus
                  />
                  <p className="text-xs text-gray-500 mt-2 text-center">
                    Check your email for the verification code
                  </p>
                </div>

                {formError && (
                  <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg flex items-start gap-2">
                    <AlertTriangle className="w-4 h-4 text-red-400 mt-0.5 flex-shrink-0" />
                    <p className="text-red-400 text-sm">{formError}</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={formLoading || ipCode.length !== 6}
                  className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {formLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : 'Verify & Link'}
                </button>
              </form>

              <div className="mt-4 flex justify-center">
                <button
                  onClick={handleResendCode}
                  disabled={resendTimer > 0 || formLoading}
                  className="text-sm text-emerald-400 hover:text-emerald-300 disabled:text-gray-500 disabled:cursor-not-allowed transition-colors"
                >
                  {resendTimer > 0 ? `Resend code in ${resendTimer}s` : 'Resend code'}
                </button>
              </div>
            </div>
          )}

          {step === 'linking' && (
            <div className="p-8 flex flex-col items-center gap-4">
              <Loader2 className="w-8 h-8 text-emerald-400 animate-spin" />
              <p className="text-gray-400">Linking your accounts...</p>
            </div>
          )}

          {step === 'success' && (
            <div className="p-8 text-center">
              <div className="w-16 h-16 rounded-full bg-emerald-500/20 flex items-center justify-center mx-auto mb-4">
                <CheckCircle className="w-8 h-8 text-emerald-500" />
              </div>
              <h2 className="text-xl font-bold text-white mb-2">Account Linked!</h2>
              <p className="text-gray-400 text-sm mb-6">
                Your Shark Trades account is now connected. You can return to the game to continue playing.
              </p>

              <button
                onClick={handleReturnToGame}
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-medium rounded-lg transition-colors"
              >
                Return to Game
              </button>
            </div>
          )}

          {step === 'error' && (
            <div className="p-8 text-center">
              <div className="w-16 h-16 rounded-full bg-red-500/20 flex items-center justify-center mx-auto mb-4">
                <XCircle className="w-8 h-8 text-red-400" />
              </div>
              <h2 className="text-lg font-bold text-white mb-2">Link Failed</h2>
              <p className="text-gray-400 text-sm mb-6">{errorMessage}</p>

              <div className="space-y-3">
                <button
                  onClick={() => {
                    setFormError('');
                    setStep('sign-in');
                  }}
                  className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-medium rounded-lg transition-colors"
                >
                  Try Again
                </button>
                <button
                  onClick={handleReturnToGame}
                  className="w-full py-3 bg-[#2b3139] hover:bg-[#363d47] text-white font-medium rounded-lg transition-colors"
                >
                  Return to Game
                </button>
              </div>
            </div>
          )}
        </div>

        <p className="text-center text-gray-600 text-xs mt-6">
          Shark Trading Platform
        </p>
      </div>
    </div>
  );
}
