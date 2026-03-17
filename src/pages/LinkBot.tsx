import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import {
  Gamepad2,
  Eye,
  EyeOff,
  CheckCircle,
  AlertTriangle,
  ExternalLink,
  Loader2,
  ShieldCheck,
  Link2,
  XCircle,
  ArrowLeft,
} from 'lucide-react';

type LinkStep = 'loading' | 'sign-in' | 'confirm' | 'success' | 'error';

interface LinkRequestInfo {
  token: string;
  telegram_username: string | null;
  chat_id: string;
}

export default function LinkBot() {
  const { navigateTo } = useNavigation();
  const { isAuthenticated, user, signIn, loading: authLoading } = useAuth();
  const [step, setStep] = useState<LinkStep>('loading');
  const [linkRequest, setLinkRequest] = useState<LinkRequestInfo | null>(null);
  const [errorMessage, setErrorMessage] = useState('');
  const [botUsername, setBotUsername] = useState('satoshiacademybot');

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [signInLoading, setSignInLoading] = useState(false);
  const [signInError, setSignInError] = useState('');

  const [confirming, setConfirming] = useState(false);

  const token = new URLSearchParams(window.location.search).get('token');

  useEffect(() => {
    if (!token) {
      setErrorMessage('No link token found. Please start the linking process from the Telegram bot.');
      setStep('error');
      return;
    }

    validateToken(token);
  }, [token]);

  useEffect(() => {
    if (authLoading) return;

    if (step === 'loading' && linkRequest) {
      setStep(isAuthenticated ? 'confirm' : 'sign-in');
    }

    if (step === 'sign-in' && isAuthenticated && linkRequest) {
      setStep('confirm');
    }
  }, [isAuthenticated, authLoading, linkRequest, step]);

  const validateToken = async (t: string) => {
    try {
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/game-bot-validate-token`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ token: t }),
        }
      );

      const data = await response.json();

      if (!data.valid) {
        const messages: Record<string, string> = {
          not_found: 'This link has expired or is invalid. Please request a new one from the bot.',
          already_used: 'This link has already been used. Your account may already be connected.',
          expired: 'This link has expired. Please request a new one from the bot.',
        };
        setErrorMessage(messages[data.reason] || 'Invalid link. Please request a new one from the bot.');
        setStep('error');
        return;
      }

      setLinkRequest({
        token: t,
        telegram_username: data.telegram_username,
        chat_id: data.chat_id,
      });

      if (!authLoading) {
        setStep(isAuthenticated ? 'confirm' : 'sign-in');
      }
    } catch {
      setErrorMessage('Something went wrong. Please try again from the bot.');
      setStep('error');
    }
  };

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setSignInError('');

    if (!email || !password) {
      setSignInError('Please fill in all fields');
      return;
    }

    setSignInLoading(true);
    const result = await signIn(email, password);
    setSignInLoading(false);

    if (result.error) {
      setSignInError(result.error.message);
      return;
    }

    if (result.mfaRequired || result.ipVerificationRequired) {
      setSignInError('Please sign in through the main website first, then return to this link.');
      return;
    }
  };

  const handleConfirmLink = async () => {
    if (!linkRequest || !token) return;

    setConfirming(true);
    setSignInError('');

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        setStep('sign-in');
        setConfirming(false);
        return;
      }

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/game-bot-confirm-link`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ token }),
        }
      );

      const data = await response.json();

      if (!response.ok) {
        setErrorMessage(data.error || 'Failed to link account. Please try again.');
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
    } finally {
      setConfirming(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0b0e11] flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <button
          onClick={() => navigateTo('home')}
          className="inline-flex items-center gap-1.5 text-gray-400 hover:text-white text-sm mb-6 transition-colors group"
        >
          <ArrowLeft className="w-4 h-4 group-hover:-translate-x-0.5 transition-transform" />
          Back to Home
        </button>
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center mx-auto mb-4 shadow-lg shadow-emerald-500/20">
            <Gamepad2 className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-white">Shark Game Bot</h1>
          <p className="text-gray-400 mt-1 text-sm">Link your Telegram to your Shark account</p>
        </div>

        <div className="bg-[#1e2329] rounded-2xl border border-gray-800 overflow-hidden">
          {step === 'loading' && (
            <div className="p-8 flex flex-col items-center gap-4">
              <Loader2 className="w-8 h-8 text-emerald-400 animate-spin" />
              <p className="text-gray-400">Validating link...</p>
            </div>
          )}

          {step === 'sign-in' && (
            <div className="p-6">
              <div className="flex items-center gap-3 mb-6">
                <ShieldCheck className="w-5 h-5 text-emerald-400" />
                <h2 className="text-lg font-semibold text-white">Sign in to continue</h2>
              </div>

              {linkRequest?.telegram_username && (
                <div className="mb-5 p-3 bg-[#2b3139] rounded-lg flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center flex-shrink-0">
                    <span className="text-blue-400 text-sm font-bold">T</span>
                  </div>
                  <div className="min-w-0">
                    <p className="text-xs text-gray-400">Linking Telegram account</p>
                    <p className="text-white text-sm font-medium truncate">@{linkRequest.telegram_username}</p>
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

                {signInError && (
                  <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-lg flex items-start gap-2">
                    <AlertTriangle className="w-4 h-4 text-red-400 mt-0.5 flex-shrink-0" />
                    <p className="text-red-400 text-sm">{signInError}</p>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={signInLoading}
                  className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {signInLoading ? (
                    <Loader2 className="w-5 h-5 animate-spin" />
                  ) : (
                    'Sign In & Link'
                  )}
                </button>
              </form>

              <p className="text-center text-gray-500 text-xs mt-4">
                Don't have an account? Sign up on the Shark website first, then return to this link.
              </p>
            </div>
          )}

          {step === 'confirm' && (
            <div className="p-6">
              <div className="text-center mb-6">
                <Link2 className="w-10 h-10 text-emerald-400 mx-auto mb-3" />
                <h2 className="text-lg font-semibold text-white">Confirm Account Link</h2>
                <p className="text-gray-400 text-sm mt-1">
                  Connect your Telegram to your Shark account
                </p>
              </div>

              <div className="space-y-3 mb-6">
                <div className="p-4 bg-[#2b3139] rounded-xl">
                  <p className="text-xs text-gray-400 mb-1">Shark Account</p>
                  <p className="text-white font-medium truncate">{user?.email}</p>
                </div>

                <div className="flex justify-center">
                  <div className="w-8 h-8 rounded-full bg-emerald-500/20 flex items-center justify-center">
                    <Link2 className="w-4 h-4 text-emerald-400" />
                  </div>
                </div>

                <div className="p-4 bg-[#2b3139] rounded-xl">
                  <p className="text-xs text-gray-400 mb-1">Telegram Account</p>
                  <p className="text-white font-medium">
                    {linkRequest?.telegram_username
                      ? `@${linkRequest.telegram_username}`
                      : `Chat ${linkRequest?.chat_id}`}
                  </p>
                </div>
              </div>

              <button
                onClick={handleConfirmLink}
                disabled={confirming}
                className="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
              >
                {confirming ? (
                  <Loader2 className="w-5 h-5 animate-spin" />
                ) : (
                  <>
                    <CheckCircle className="w-5 h-5" />
                    Confirm Link
                  </>
                )}
              </button>

              <p className="text-center text-gray-500 text-xs mt-4">
                You can unlink at any time from Settings
              </p>
            </div>
          )}

          {step === 'success' && (
            <div className="p-8 text-center">
              <div className="w-16 h-16 rounded-full bg-emerald-500/20 flex items-center justify-center mx-auto mb-4">
                <CheckCircle className="w-8 h-8 text-emerald-500" />
              </div>
              <h2 className="text-xl font-bold text-white mb-2">Account Linked!</h2>
              <p className="text-gray-400 text-sm mb-6">
                Your Shark account is now connected to the Game Bot. You can return to Telegram to start playing.
              </p>

              <a
                href={`https://t.me/${botUsername}`}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center gap-2 w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-medium rounded-lg transition-colors"
              >
                <ExternalLink className="w-5 h-5" />
                Return to Telegram
              </a>
            </div>
          )}

          {step === 'error' && (
            <div className="p-8 text-center">
              <div className="w-16 h-16 rounded-full bg-red-500/20 flex items-center justify-center mx-auto mb-4">
                <XCircle className="w-8 h-8 text-red-400" />
              </div>
              <h2 className="text-lg font-bold text-white mb-2">Link Failed</h2>
              <p className="text-gray-400 text-sm mb-6">{errorMessage}</p>

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
