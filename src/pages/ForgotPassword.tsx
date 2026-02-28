import { useState, useEffect } from 'react';
import { useNavigation } from '../App';
import { ArrowLeft, Mail, CheckCircle, AlertCircle } from 'lucide-react';
import Navbar from '../components/Navbar';

function ForgotPassword() {
  const { navigateTo } = useNavigation();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown > 0) {
      const timer = setTimeout(() => setCooldown(cooldown - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [cooldown]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!email) {
      setError('Please enter your email address');
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      setError('Please enter a valid email address');
      return;
    }

    if (cooldown > 0) {
      setError(`Please wait ${cooldown} seconds before requesting another reset`);
      return;
    }

    setLoading(true);

    try {
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-password-reset`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
          },
          body: JSON.stringify({
            email,
            redirectTo: `${window.location.origin}/?reset=true`,
          }),
        }
      );

      const data = await response.json();

      if (!response.ok || !data.success) {
        throw new Error(data.error || 'Failed to send reset email');
      }

      setSuccess(true);
      setCooldown(60);
    } catch (err: any) {
      console.error('Password reset error:', err);
      setError(err.message || 'Failed to send reset email. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (cooldown > 0) return;
    setSuccess(false);
    setError('');
    await handleSubmit({ preventDefault: () => {} } as React.FormEvent);
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
                        <Mail className="w-6 h-6 text-[#f0b90b]" />
                      </div>
                      <div>
                        <h1 className="text-2xl font-bold text-white">Forgot Password</h1>
                        <p className="text-sm text-gray-400">We'll send you a reset link</p>
                      </div>
                    </div>
                    <div className="border-b-2 border-[#f0b90b] w-12" />
                  </div>

                  <form onSubmit={handleSubmit} className="space-y-5">
                    <div>
                      <label htmlFor="email" className="block text-sm text-gray-400 mb-2">
                        Email Address
                      </label>
                      <input
                        id="email"
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        placeholder="Enter your email"
                        className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
                        autoFocus
                      />
                      <p className="text-xs text-gray-500 mt-2">
                        Enter the email address associated with your account
                      </p>
                    </div>

                    {error && (
                      <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-3 flex items-start gap-2">
                        <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                        <p className="text-red-500 text-sm">{error}</p>
                      </div>
                    )}

                    <button
                      type="submit"
                      disabled={loading || cooldown > 0}
                      className="w-full bg-[#f0b90b] hover:bg-[#f8d12f] text-black font-semibold py-3.5 rounded-lg transition-colors duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {loading ? 'Sending...' : cooldown > 0 ? `Wait ${cooldown}s` : 'Send Reset Link'}
                    </button>
                  </form>

                  <div className="mt-6 p-4 bg-[#252837] rounded-lg">
                    <p className="text-xs text-gray-400 text-center">
                      Remember your password?{' '}
                      <button
                        onClick={() => navigateTo('signin')}
                        className="text-[#f0b90b] hover:underline"
                      >
                        Sign in instead
                      </button>
                    </p>
                  </div>
                </>
              ) : (
                <>
                  <div className="text-center">
                    <div className="w-16 h-16 bg-emerald-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
                      <CheckCircle className="w-8 h-8 text-emerald-400" />
                    </div>
                    <h1 className="text-2xl font-bold text-white mb-2">Check Your Email</h1>
                    <p className="text-gray-400 mb-6">
                      We've sent a password reset link to:
                    </p>
                    <p className="text-[#f0b90b] font-medium mb-6 break-all">
                      {email}
                    </p>

                    <div className="bg-[#252837] rounded-lg p-4 mb-6 text-left">
                      <h3 className="text-sm font-semibold text-white mb-2">What's next?</h3>
                      <ol className="text-xs text-gray-400 space-y-2">
                        <li className="flex items-start gap-2">
                          <span className="text-[#f0b90b] font-bold">1.</span>
                          <span>Check your email inbox (and spam folder)</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-[#f0b90b] font-bold">2.</span>
                          <span>Click the reset link in the email</span>
                        </li>
                        <li className="flex items-start gap-2">
                          <span className="text-[#f0b90b] font-bold">3.</span>
                          <span>Create a new secure password</span>
                        </li>
                      </ol>
                    </div>

                    <div className="space-y-3">
                      <button
                        onClick={handleResend}
                        disabled={cooldown > 0}
                        className="w-full bg-[#252837] hover:bg-[#2f3346] text-white font-medium py-3 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {cooldown > 0 ? `Resend in ${cooldown}s` : 'Resend Email'}
                      </button>
                      <button
                        onClick={() => navigateTo('signin')}
                        className="w-full text-gray-400 hover:text-white text-sm transition-colors py-2"
                      >
                        Return to Sign In
                      </button>
                    </div>
                  </div>

                  <div className="mt-6 p-4 bg-[#0b0e11] rounded-lg border border-gray-800">
                    <p className="text-xs text-gray-500 text-center">
                      Didn't receive the email? Check your spam folder or try a different email address.
                      The link expires in 1 hour.
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

export default ForgotPassword;
