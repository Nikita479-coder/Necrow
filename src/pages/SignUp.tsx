import { useState, useEffect, useRef, useMemo } from 'react';
import { useNavigation } from '../App';
import { useAuth } from '../context/AuthContext';
import { Eye, EyeOff, CreditCard, Sparkles, TrendingUp, Shield, Mail, ArrowLeft, RefreshCw, Gift, CheckCircle, ChevronDown, Search } from 'lucide-react';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';
import { countryCodes } from '../constants/countryCodes';
import { saveAcquisitionToDatabase } from '../services/acquisitionService';

type Step = 'register' | 'verify';

function SignUp() {
  const { navigateTo, navigationState } = useNavigation();
  const { signUp, isAuthenticated, loading: authLoading } = useAuth();
  const [step, setStep] = useState<Step>('register');
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    password: '',
    referralCode: '',
  });
  const [phonePrefix, setPhonePrefix] = useState('+1');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [otpCode, setOtpCode] = useState(['', '', '', '', '', '']);
  const [resendCooldown, setResendCooldown] = useState(0);
  const [verifying, setVerifying] = useState(false);
  const [showCountryDropdown, setShowCountryDropdown] = useState(false);
  const [countrySearch, setCountrySearch] = useState('');
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);
  const phoneInputRef = useRef<HTMLInputElement | null>(null);
  const dropdownRef = useRef<HTMLDivElement | null>(null);

  const sortedCountryCodes = useMemo(() => {
    return [...countryCodes].sort((a, b) => {
      const dialA = parseInt(a.dialCode.replace('+', ''));
      const dialB = parseInt(b.dialCode.replace('+', ''));
      return dialA - dialB;
    });
  }, []);

  const filteredCountries = useMemo(() => {
    if (!countrySearch) return sortedCountryCodes;
    const search = countrySearch.toLowerCase();
    return sortedCountryCodes.filter(
      (c) => c.name.toLowerCase().includes(search) || c.dialCode.includes(search)
    );
  }, [countrySearch, sortedCountryCodes]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setShowCountryDropdown(false);
        setCountrySearch('');
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const fullPhoneValue = phonePrefix + formData.phone;

  const handlePhoneInputChange = (value: string) => {
    let cleanValue = value.replace(/[^\d+]/g, '');

    if (!cleanValue.startsWith('+') && cleanValue.length > 0) {
      cleanValue = '+' + cleanValue;
    }

    if (!cleanValue || cleanValue === '+') {
      setPhonePrefix('+1');
      setFormData({ ...formData, phone: '' });
      return;
    }

    const matchingCountries = sortedCountryCodes.filter((c) =>
      cleanValue.startsWith(c.dialCode)
    );

    if (matchingCountries.length > 0) {
      const longestMatch = matchingCountries.reduce((a, b) =>
        a.dialCode.length > b.dialCode.length ? a : b
      );
      setPhonePrefix(longestMatch.dialCode);
      setFormData({
        ...formData,
        phone: cleanValue.slice(longestMatch.dialCode.length),
      });
    } else {
      const potentialMatches = sortedCountryCodes.filter((c) =>
        c.dialCode.startsWith(cleanValue)
      );
      if (potentialMatches.length > 0) {
        setPhonePrefix(cleanValue);
        setFormData({ ...formData, phone: '' });
      } else {
        setFormData({ ...formData, phone: cleanValue.replace(/^\+/, '') });
      }
    }
  };

  useEffect(() => {
    const refFromNav = navigationState?.referralCode;
    const refFromStorage = localStorage.getItem('pendingReferralCode');
    const referralCode = refFromNav || refFromStorage;

    if (referralCode) {
      setFormData(prev => ({ ...prev, referralCode }));
    }
  }, [navigationState]);

  useEffect(() => {
    if (!authLoading && isAuthenticated) {
      navigateTo('home');
    }
  }, [authLoading, isAuthenticated]);

  useEffect(() => {
    if (resendCooldown > 0) {
      const timer = setTimeout(() => setResendCooldown(resendCooldown - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [resendCooldown]);

  const sendOtp = async (email: string) => {
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const response = await fetch(`${supabaseUrl}/functions/v1/send-signup-otp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({ email }),
    });

    const data = await response.json();
    if (!data.success) {
      throw new Error(data.error || 'Failed to send verification code');
    }
    return data;
  };

  const verifyOtp = async (email: string, code: string) => {
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const response = await fetch(`${supabaseUrl}/functions/v1/verify-signup-otp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({ email, code }),
    });

    const data = await response.json();
    return data;
  };

  const sendWelcomeEmail = async (email: string, fullName: string) => {
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    try {
      await fetch(`${supabaseUrl}/functions/v1/send-welcome-email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({ email, full_name: fullName }),
      });
    } catch (e) {
      console.error('Failed to send welcome email:', e);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');

    if (!formData.name || !formData.email || !formData.phone || !formData.password) {
      setError('Please fill in all required fields');
      return;
    }

    if (formData.password.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }

    if (!agreedToTerms) {
      setError('Please agree to the Terms and Conditions');
      return;
    }

    setLoading(true);

    try {
      await sendOtp(formData.email);
      setStep('verify');
      setResendCooldown(60);
      setOtpCode(['', '', '', '', '', '']);
    } catch (err: any) {
      setError(err.message || 'Failed to send verification code');
    } finally {
      setLoading(false);
    }
  };

  const handleOtpChange = (index: number, value: string) => {
    if (value.length > 1) {
      const pastedCode = value.slice(0, 6).split('');
      const newOtp = [...otpCode];
      pastedCode.forEach((char, i) => {
        if (i + index < 6 && /^\d$/.test(char)) {
          newOtp[i + index] = char;
        }
      });
      setOtpCode(newOtp);
      const nextIndex = Math.min(index + pastedCode.length, 5);
      inputRefs.current[nextIndex]?.focus();
      return;
    }

    if (!/^\d*$/.test(value)) return;

    const newOtp = [...otpCode];
    newOtp[index] = value;
    setOtpCode(newOtp);

    if (value && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleOtpKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === 'Backspace' && !otpCode[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handleVerifyOtp = async () => {
    const code = otpCode.join('');
    if (code.length !== 6) {
      setError('Please enter the complete 6-digit code');
      return;
    }

    setVerifying(true);
    setError('');

    try {
      const verifyResult = await verifyOtp(formData.email, code);

      if (!verifyResult.success) {
        setError(verifyResult.error || 'Invalid verification code');
        if (verifyResult.attempts_remaining !== undefined) {
          setError(`${verifyResult.error} (${verifyResult.attempts_remaining} attempts remaining)`);
        }
        setVerifying(false);
        return;
      }

      const fullPhoneNumber = `${phonePrefix}${formData.phone}`;

      const { error: signUpError, data: signUpData } = await signUp(
        formData.email,
        formData.password,
        formData.name,
        fullPhoneNumber,
        formData.referralCode || undefined
      );

      if (signUpError) {
        setError(signUpError.message);
        setVerifying(false);
        return;
      }

      if (signUpData?.user?.id) {
        await supabase
          .from('user_profiles')
          .update({ email_verified: true })
          .eq('id', signUpData.user.id);

        await saveAcquisitionToDatabase(signUpData.user.id);
      }

      await sendWelcomeEmail(formData.email, formData.name);

      localStorage.removeItem('pendingReferralCode');
      navigateTo('home');
    } catch (err: any) {
      setError(err.message || 'Verification failed');
    } finally {
      setVerifying(false);
    }
  };

  const handleResendOtp = async () => {
    if (resendCooldown > 0) return;

    setLoading(true);
    setError('');

    try {
      await sendOtp(formData.email);
      setResendCooldown(60);
      setOtpCode(['', '', '', '', '', '']);
    } catch (err: any) {
      setError(err.message || 'Failed to resend code');
    } finally {
      setLoading(false);
    }
  };

  const renderRegistrationForm = () => (
    <form onSubmit={handleSubmit} className="space-y-5">
      <div>
        <label htmlFor="name" className="block text-sm text-gray-400 mb-2">
          Full Name
        </label>
        <input
          id="name"
          type="text"
          value={formData.name}
          onChange={(e) => setFormData({ ...formData, name: e.target.value })}
          placeholder="Full Name"
          className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
        />
      </div>

      <div>
        <label htmlFor="email" className="block text-sm text-gray-400 mb-2">
          Email
        </label>
        <input
          id="email"
          type="email"
          value={formData.email}
          onChange={(e) => setFormData({ ...formData, email: e.target.value })}
          placeholder="Email"
          className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all"
        />
      </div>

      <div>
        <label htmlFor="phone" className="block text-sm text-gray-400 mb-2">
          Phone Number
        </label>
        <div className="relative" ref={dropdownRef}>
          <div className="flex bg-[#252837] rounded-lg overflow-hidden focus-within:ring-2 focus-within:ring-[#f0b90b] transition-all">
            <input
              ref={phoneInputRef}
              id="phone"
              type="tel"
              value={fullPhoneValue}
              onChange={(e) => handlePhoneInputChange(e.target.value)}
              placeholder="+1 234 567 8900"
              className="flex-1 bg-transparent border-0 px-4 py-3 text-white placeholder-gray-500 focus:outline-none"
            />
            <button
              type="button"
              onClick={() => setShowCountryDropdown(!showCountryDropdown)}
              className="flex items-center gap-1 px-3 py-3 text-gray-400 hover:text-white hover:bg-[#2d3142] transition-colors shrink-0"
            >
              <ChevronDown className={`w-4 h-4 transition-transform ${showCountryDropdown ? 'rotate-180' : ''}`} />
            </button>
          </div>

          {showCountryDropdown && (
            <div className="absolute top-full left-0 right-0 mt-1 bg-[#252837] rounded-lg border border-gray-700 shadow-xl z-50 max-h-64 overflow-hidden">
              <div className="p-2 border-b border-gray-700">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                  <input
                    type="text"
                    value={countrySearch}
                    onChange={(e) => setCountrySearch(e.target.value)}
                    placeholder="Search country..."
                    className="w-full bg-[#1a1d29] rounded-md pl-9 pr-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-[#f0b90b]"
                    autoFocus
                  />
                </div>
              </div>
              <div className="overflow-y-auto max-h-48">
                {filteredCountries.map((country) => (
                  <button
                    key={country.code}
                    type="button"
                    onClick={() => {
                      setPhonePrefix(country.dialCode);
                      setShowCountryDropdown(false);
                      setCountrySearch('');
                      phoneInputRef.current?.focus();
                    }}
                    className={`w-full flex items-center gap-3 px-3 py-2.5 text-left hover:bg-[#2d3142] transition-colors ${
                      phonePrefix === country.dialCode ? 'bg-[#f0b90b]/10 text-[#f0b90b]' : 'text-white'
                    }`}
                  >
                    <span className="text-sm font-medium w-12">{country.dialCode}</span>
                    <span className="text-sm text-gray-400 truncate">{country.name}</span>
                  </button>
                ))}
                {filteredCountries.length === 0 && (
                  <div className="px-3 py-4 text-center text-gray-500 text-sm">No countries found</div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      <div>
        <label htmlFor="password" className="block text-sm text-gray-400 mb-2">
          Password
        </label>
        <div className="relative">
          <input
            id="password"
            type={showPassword ? 'text' : 'password'}
            value={formData.password}
            onChange={(e) => setFormData({ ...formData, password: e.target.value })}
            placeholder="Password"
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

      <div>
        <label htmlFor="referralCode" className="block text-sm text-gray-400 mb-2">
          Referral code (optional)
        </label>
        <input
          id="referralCode"
          type="text"
          value={formData.referralCode}
          onChange={(e) => setFormData({ ...formData, referralCode: e.target.value.toUpperCase() })}
          placeholder="Referral code (optional)"
          className="w-full bg-[#252837] border-0 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-[#f0b90b] transition-all uppercase"
        />
      </div>

      <div className="flex items-start gap-3 pt-2">
        <input
          id="terms"
          type="checkbox"
          checked={agreedToTerms}
          onChange={(e) => setAgreedToTerms(e.target.checked)}
          className="mt-0.5 w-4 h-4 rounded border-gray-600 bg-[#252837] text-[#f0b90b] focus:ring-[#f0b90b] focus:ring-offset-0 cursor-pointer"
        />
        <label htmlFor="terms" className="text-sm text-gray-400 leading-tight">
          By signing up, you agree to the{' '}
          <button
            type="button"
            onClick={() => navigateTo('terms')}
            className="text-gray-300 underline hover:text-white"
          >
            Terms of Service
          </button>
          {' '}and{' '}
          <button
            type="button"
            onClick={() => navigateTo('terms')}
            className="text-gray-300 underline hover:text-white"
          >
            Privacy Policy
          </button>
          .{' '}
          <button
            type="button"
            onClick={() => navigateTo('bonusterms')}
            className="text-[#f0b90b] underline hover:text-[#d9a506]"
          >
            View Bonus Terms
          </button>
        </label>
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
        {loading ? 'Sending verification code...' : 'Create account'}
      </button>
    </form>
  );

  const renderVerificationStep = () => (
    <div className="space-y-6">
      <button
        onClick={() => {
          setStep('register');
          setError('');
        }}
        className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        <span>Back to registration</span>
      </button>

      <div className="text-center">
        <div className="w-16 h-16 bg-[#f0b90b]/10 rounded-full flex items-center justify-center mx-auto mb-4">
          <Mail className="w-8 h-8 text-[#f0b90b]" />
        </div>
        <h2 className="text-xl font-bold text-white mb-2">Verify your email</h2>
        <p className="text-gray-400 text-sm">
          We sent a 6-digit code to<br />
          <span className="text-white font-medium">{formData.email}</span>
        </p>
      </div>

      <div className="flex justify-center gap-2">
        {otpCode.map((digit, index) => (
          <input
            key={index}
            ref={(el) => (inputRefs.current[index] = el)}
            type="text"
            inputMode="numeric"
            maxLength={6}
            value={digit}
            onChange={(e) => handleOtpChange(index, e.target.value)}
            onKeyDown={(e) => handleOtpKeyDown(index, e)}
            onPaste={(e) => {
              e.preventDefault();
              const pastedData = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
              if (pastedData) {
                handleOtpChange(0, pastedData);
              }
            }}
            className="w-12 h-14 text-center text-xl font-bold bg-[#252837] border-2 border-gray-700 rounded-lg text-white focus:outline-none focus:border-[#f0b90b] transition-colors"
          />
        ))}
      </div>

      <p className="text-center text-sm text-gray-500">
        Code expires in <span className="text-[#f0b90b]">15 minutes</span>
      </p>

      {error && (
        <div className="bg-red-500/10 border border-red-500/50 rounded-lg p-3">
          <p className="text-red-500 text-sm text-center">{error}</p>
        </div>
      )}

      <button
        onClick={handleVerifyOtp}
        disabled={verifying || otpCode.join('').length !== 6}
        className="w-full bg-gradient-to-r from-[#f0b90b] to-[#d9a506] hover:from-[#d9a506] hover:to-[#c49b05] text-black font-semibold py-3.5 rounded-lg transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {verifying ? 'Verifying...' : 'Verify & Create Account'}
      </button>

      <div className="text-center">
        <button
          onClick={handleResendOtp}
          disabled={resendCooldown > 0 || loading}
          className="inline-flex items-center gap-2 text-gray-400 hover:text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          {resendCooldown > 0 ? (
            <span>Resend code in {resendCooldown}s</span>
          ) : (
            <span>Resend verification code</span>
          )}
        </button>
      </div>

      <div className="text-center">
        <button
          onClick={() => {
            setStep('register');
            setError('');
          }}
          className="text-[#f0b90b] hover:underline text-sm"
        >
          Change email address
        </button>
      </div>
    </div>
  );

  return (
    <>
      <Navbar />
      <div className="min-h-screen bg-black flex relative overflow-hidden">
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-10 w-96 h-96 bg-[#f0b90b] rounded-full filter blur-3xl opacity-20 animate-blob" />
        <div className="absolute top-40 right-20 w-[32rem] h-[32rem] bg-[#d9a506] rounded-full filter blur-3xl opacity-20 animate-blob animation-delay-2000" />
        <div className="absolute -bottom-16 left-1/4 w-[28rem] h-[28rem] bg-[#f0b90b] rounded-full filter blur-3xl opacity-20 animate-blob animation-delay-4000" />
        <div className="absolute top-1/3 right-1/3 w-80 h-80 bg-[#f8d12f] rounded-full filter blur-3xl opacity-15 animate-blob animation-delay-3000" />
        <div className="absolute bottom-32 right-16 w-72 h-72 bg-[#f0b90b] rounded-full filter blur-2xl opacity-25 animate-blob animation-delay-1000" />
        <div className="absolute top-1/2 left-16 w-64 h-64 bg-[#f8d12f] rounded-full filter blur-3xl opacity-18 animate-blob animation-delay-5000" />
      </div>

      <div className="hidden lg:flex lg:w-1/2 items-center justify-center p-12 relative overflow-hidden z-10">
        <div className="absolute inset-0 bg-gradient-to-br from-[#f0b90b]/5 via-transparent to-transparent" />

        <div className="relative z-10 max-w-xl">
          <div className="relative mb-8">
            <div className="absolute -top-20 -left-20 w-40 h-40 bg-[#f0b90b] rounded-full blur-3xl opacity-20 animate-pulse" />
            <div className="absolute -bottom-20 -right-20 w-60 h-60 bg-[#f0b90b] rounded-full blur-3xl opacity-10" />

            {step === 'register' ? (
              <div className="relative bg-gradient-to-br from-gray-900 via-gray-800 to-black p-8 rounded-3xl border border-gray-800 shadow-2xl transform rotate-3 hover:rotate-0 transition-transform duration-500">
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center gap-2">
                    <Gift className="w-8 h-8 text-[#f0b90b]" />
                    <span className="text-[#f0b90b] font-bold text-xl">NEW USER BONUS</span>
                  </div>
                  <Sparkles className="w-6 h-6 text-[#f0b90b]" />
                </div>

                <div className="space-y-4 mb-6">
                  <div className="flex items-center gap-3 text-gray-300">
                    <div className="w-10 h-10 rounded-full bg-green-500/20 flex items-center justify-center">
                      <CheckCircle className="w-5 h-5 text-green-500" />
                    </div>
                    <div>
                      <div className="font-semibold text-white">$20 KYC Bonus</div>
                      <div className="text-sm text-gray-400">Free credit on verification</div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3 text-gray-300">
                    <div className="w-10 h-10 rounded-full bg-[#f0b90b]/20 flex items-center justify-center">
                      <TrendingUp className="w-5 h-5 text-[#f0b90b]" />
                    </div>
                    <div>
                      <div className="font-semibold text-white">100% Deposit Match</div>
                      <div className="text-sm text-gray-400">Up to $100 bonus</div>
                    </div>
                  </div>
                </div>

                <div className="bg-gradient-to-r from-[#f0b90b] to-[#d9a506] rounded-xl p-px">
                  <div className="bg-gray-900 rounded-xl p-4">
                    <div className="text-center">
                      <div className="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-[#f0b90b] to-[#d9a506]">
                        Up to $120
                      </div>
                      <div className="text-gray-400 text-sm">In Welcome Bonuses</div>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="relative bg-gradient-to-br from-gray-900 via-gray-800 to-black p-8 rounded-3xl border border-gray-800 shadow-2xl transform rotate-3 hover:rotate-0 transition-transform duration-500">
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center gap-2">
                    <CreditCard className="w-8 h-8 text-[#f0b90b]" />
                    <span className="text-[#f0b90b] font-bold text-xl">SHARK CARD</span>
                  </div>
                  <Sparkles className="w-6 h-6 text-[#f0b90b]" />
                </div>

                <div className="space-y-4 mb-6">
                  <div className="flex items-center gap-3 text-gray-300">
                    <div className="w-10 h-10 rounded-full bg-[#f0b90b]/20 flex items-center justify-center">
                      <TrendingUp className="w-5 h-5 text-[#f0b90b]" />
                    </div>
                    <div>
                      <div className="font-semibold text-white">Instant Trading Credit</div>
                      <div className="text-sm text-gray-400">Start trading immediately</div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3 text-gray-300">
                    <div className="w-10 h-10 rounded-full bg-[#f0b90b]/20 flex items-center justify-center">
                      <Shield className="w-5 h-5 text-[#f0b90b]" />
                    </div>
                    <div>
                      <div className="font-semibold text-white">VIP Benefits</div>
                      <div className="text-sm text-gray-400">Exclusive rewards & rebates</div>
                    </div>
                  </div>
                </div>

                <div className="bg-gradient-to-r from-[#f0b90b] to-[#d9a506] rounded-xl p-px">
                  <div className="bg-gray-900 rounded-xl p-4">
                    <div className="text-center">
                      <div className="text-3xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-[#f0b90b] to-[#d9a506]">
                        Up to $1000
                      </div>
                      <div className="text-gray-400 text-sm">Available Credit</div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>

          <h2 className="text-4xl font-bold text-white mb-4">
            {step === 'register' ? 'Get Up to $120 in Bonuses' : 'Almost There!'}
          </h2>
          <p className="text-gray-400 text-lg">
            {step === 'register'
              ? 'Complete KYC for $20 free credit, then get 100% matched on your first deposit up to $100.'
              : 'Verify your email to complete registration and unlock your welcome bonuses.'}
          </p>
        </div>
      </div>

      <div className="flex-1 flex items-center justify-center p-6 relative z-10">
        <div className="w-full max-w-md">
          <div className="relative">
            <div className="absolute -inset-4 bg-[#f0b90b]/5 rounded-3xl blur-2xl" />

            <div className="relative bg-[#1a1d29] rounded-2xl p-8 border border-gray-800">
              {step === 'register' && (
                <div className="mb-8">
                  <div className="flex items-center justify-between mb-4">
                    <h1 className="text-2xl font-bold text-white">Register account</h1>
                    <button
                      onClick={() => navigateTo('signin')}
                      className="text-[#f0b90b] hover:underline text-sm flex items-center gap-1"
                    >
                      <span>Log in</span>
                    </button>
                  </div>
                  <div className="border-b-2 border-[#f0b90b] w-12" />
                </div>
              )}

              {step === 'register' ? renderRegistrationForm() : renderVerificationStep()}

              <div className="mt-8 text-center">
                <button
                  onClick={() => navigateTo('home')}
                  className="text-gray-500 hover:text-gray-400 text-sm transition-colors"
                >
                  Back to Home
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
      </div>
    </>
  );
}

export default SignUp;
