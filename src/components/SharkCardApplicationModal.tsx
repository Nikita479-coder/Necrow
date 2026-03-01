import { useState, useEffect } from 'react';
import { X, CreditCard, DollarSign, Globe, User, AlertCircle, Clock, Lock, Wallet, Info } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';

interface SharkCardApplicationModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const COUNTRIES = [
  'United States', 'United Kingdom', 'Canada', 'Australia', 'Germany', 'France',
  'Spain', 'Italy', 'Netherlands', 'Switzerland', 'Singapore', 'Japan',
  'South Korea', 'United Arab Emirates', 'Brazil', 'Mexico', 'India', 'Other'
];

const CREDIT_LIMITS = [
  { value: 1000, label: '$1,000' },
  { value: 2500, label: '$2,500' },
  { value: 5000, label: '$5,000' },
  { value: 10000, label: '$10,000' },
  { value: 25000, label: '$25,000' },
  { value: 50000, label: '$50,000' },
  { value: 0, label: 'Custom' },
];

export default function SharkCardApplicationModal({ isOpen, onClose }: SharkCardApplicationModalProps) {
  const [fullName, setFullName] = useState('');
  const [country, setCountry] = useState('');
  const [requestedLimit, setRequestedLimit] = useState(5000);
  const [customAmount, setCustomAmount] = useState('');
  const [isCustom, setIsCustom] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isCheckingEligibility, setIsCheckingEligibility] = useState(true);
  const [availableBalance, setAvailableBalance] = useState(0);
  const [lockedBalance, setLockedBalance] = useState(0);
  const [waitingPeriod, setWaitingPeriod] = useState<{
    daysRemaining: number;
    declinedDate: string;
  } | null>(null);
  const { showSuccess, showError } = useToast();

  useEffect(() => {
    if (isOpen) {
      checkEligibility();
      fetchWalletBalance();
    }
  }, [isOpen]);

  const fetchWalletBalance = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: wallet, error } = await supabase
        .from('wallets')
        .select('balance, locked_balance')
        .eq('user_id', user.id)
        .eq('currency', 'USDT')
        .eq('wallet_type', 'main')
        .maybeSingle();

      if (error) throw error;

      if (wallet) {
        const totalBalance = wallet.balance || 0;
        const locked = wallet.locked_balance || 0;
        setAvailableBalance(totalBalance - locked);
        setLockedBalance(locked);
      } else {
        setAvailableBalance(0);
        setLockedBalance(0);
      }
    } catch (error) {
      console.error('Error fetching wallet balance:', error);
    }
  };

  const checkEligibility = async () => {
    setIsCheckingEligibility(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data: applications, error } = await supabase
        .from('shark_card_applications')
        .select('status, reviewed_at')
        .eq('user_id', user.id)
        .eq('status', 'declined')
        .order('reviewed_at', { ascending: false })
        .limit(1);

      if (error) throw error;

      if (applications && applications.length > 0) {
        const lastDeclined = applications[0];
        const reviewedAt = new Date(lastDeclined.reviewed_at);

        const { data: businessDaysData, error: calcError } = await supabase
          .rpc('calculate_business_days', {
            start_date: lastDeclined.reviewed_at,
            end_date: new Date().toISOString()
          });

        if (calcError) throw calcError;

        const daysPassed = businessDaysData || 0;
        if (daysPassed < 5) {
          setWaitingPeriod({
            daysRemaining: 5 - daysPassed,
            declinedDate: reviewedAt.toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
              year: 'numeric'
            })
          });
        } else {
          setWaitingPeriod(null);
        }
      } else {
        setWaitingPeriod(null);
      }
    } catch (error) {
      console.error('Error checking eligibility:', error);
    } finally {
      setIsCheckingEligibility(false);
    }
  };

  if (!isOpen) return null;

  const effectiveLimit = isCustom ? (parseFloat(customAmount) || 0) : requestedLimit;
  const hasInsufficientBalance = effectiveLimit > availableBalance;
  const isValidAmount = effectiveLimit > 0;

  const handleLimitSelect = (value: number) => {
    if (value === 0) {
      setIsCustom(true);
      setRequestedLimit(0);
    } else {
      setIsCustom(false);
      setRequestedLimit(value);
      setCustomAmount('');
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (hasInsufficientBalance) {
      showError(`Insufficient balance. You need ${effectiveLimit.toLocaleString()} USDT but only have ${availableBalance.toLocaleString()} USDT available.`);
      return;
    }

    if (!isValidAmount) {
      showError('Please enter a valid amount');
      return;
    }

    setIsSubmitting(true);

    try {
      const { data, error } = await supabase.rpc('apply_for_shark_card', {
        p_full_name: fullName,
        p_country: country,
        p_requested_limit: effectiveLimit
      });

      if (error) {
        throw error;
      }

      if (data?.success) {
        showSuccess(`Application submitted! ${effectiveLimit.toLocaleString()} USDT has been locked pending review.`);
        onClose();
        setFullName('');
        setCountry('');
        setRequestedLimit(5000);
        setCustomAmount('');
        setIsCustom(false);
      } else {
        throw new Error(data?.error || 'Failed to submit application');
      }
    } catch (error: any) {
      showError(error.message || 'Failed to submit application');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
      <div className="bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 rounded-2xl max-w-2xl w-full border border-amber-500/20 shadow-2xl shadow-amber-500/10 max-h-[90vh] overflow-y-auto">
        <div className="p-6 border-b border-slate-700/50 flex items-center justify-between sticky top-0 bg-slate-900/95 backdrop-blur-sm z-10">
          <div className="flex items-center gap-3">
            <div className="bg-gradient-to-br from-amber-500 to-orange-600 p-3 rounded-xl">
              <CreditCard className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-white">Apply for Shark Card</h2>
              <p className="text-slate-400 text-sm">Get instant credit with exclusive benefits</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-white transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          <div className="bg-gradient-to-r from-blue-500/10 to-cyan-500/10 border border-blue-500/20 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-white font-semibold flex items-center gap-2">
                <Wallet className="w-4 h-4 text-blue-400" />
                Your Available Balance
              </h3>
              <span className="text-2xl font-bold text-white">{availableBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} <span className="text-sm text-slate-400">USDT</span></span>
            </div>
            {lockedBalance > 0 && (
              <div className="flex items-center gap-2 text-sm text-slate-400">
                <Lock className="w-3.5 h-3.5" />
                <span>{lockedBalance.toLocaleString()} USDT currently locked in pending applications</span>
              </div>
            )}
          </div>

          <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl p-4">
            <div className="flex items-start gap-3">
              <Info className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
              <div>
                <h3 className="text-amber-400 font-semibold mb-1">How It Works</h3>
                <ul className="text-sm text-amber-300/80 space-y-1">
                  <li>1. Your requested amount will be <span className="font-semibold">locked</span> in your main wallet during review</li>
                  <li>2. If approved, funds transfer to your Shark Card wallet</li>
                  <li>3. If declined, funds are <span className="font-semibold">unlocked</span> and returned to you</li>
                </ul>
              </div>
            </div>
          </div>

          {waitingPeriod && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                <div className="flex-1">
                  <h3 className="text-red-400 font-semibold mb-1 flex items-center gap-2">
                    Application Temporarily Unavailable
                  </h3>
                  <p className="text-sm text-red-300/90 mb-2">
                    Your previous application was declined on <span className="font-medium">{waitingPeriod.declinedDate}</span>.
                    You must wait <span className="font-bold">{waitingPeriod.daysRemaining} more business day{waitingPeriod.daysRemaining > 1 ? 's' : ''}</span> before submitting a new application.
                  </p>
                  <div className="flex items-center gap-2 text-xs text-red-300/70">
                    <Clock className="w-3.5 h-3.5" />
                    <span>Business days exclude weekends (Saturday & Sunday)</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          <div className="bg-gradient-to-r from-amber-500/10 to-orange-500/10 border border-amber-500/20 rounded-xl p-4">
            <h3 className="text-white font-semibold mb-2 flex items-center gap-2">
              <CreditCard className="w-4 h-4 text-amber-500" />
              Shark Card Benefits
            </h3>
            <ul className="space-y-2 text-sm text-slate-300">
              <li className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 bg-amber-500 rounded-full"></div>
                <span>Up to 10% cashback on all crypto purchases</span>
              </li>
              <li className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 bg-amber-500 rounded-full"></div>
                <span>Zero annual fees for the first year</span>
              </li>
              <li className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 bg-amber-500 rounded-full"></div>
                <span>Instant credit approval for verified users</span>
              </li>
              <li className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 bg-amber-500 rounded-full"></div>
                <span>Global acceptance at millions of merchants</span>
              </li>
            </ul>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2 flex items-center gap-2">
                <User className="w-4 h-4 text-amber-500" />
                Full Legal Name
              </label>
              <input
                type="text"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                required
                disabled={!!waitingPeriod}
                placeholder="Enter your full name as it appears on ID"
                className="w-full bg-slate-800/50 border border-slate-700 rounded-xl px-4 py-3 text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:border-amber-500 disabled:opacity-50 disabled:cursor-not-allowed"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2 flex items-center gap-2">
                <Globe className="w-4 h-4 text-amber-500" />
                Country of Residence
              </label>
              <select
                value={country}
                onChange={(e) => setCountry(e.target.value)}
                required
                disabled={!!waitingPeriod}
                className="w-full bg-slate-800/50 border border-slate-700 rounded-xl px-4 py-3 text-white focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:border-amber-500 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <option value="">Select your country</option>
                {COUNTRIES.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2 flex items-center gap-2">
                <DollarSign className="w-4 h-4 text-amber-500" />
                Requested Credit Limit
              </label>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                {CREDIT_LIMITS.map((limit) => (
                  <button
                    key={limit.value}
                    type="button"
                    onClick={() => handleLimitSelect(limit.value)}
                    disabled={!!waitingPeriod}
                    className={`px-4 py-3 rounded-xl font-medium transition-all ${
                      (limit.value === 0 && isCustom) || (limit.value !== 0 && !isCustom && requestedLimit === limit.value)
                        ? 'bg-gradient-to-br from-amber-500 to-orange-600 text-white shadow-lg shadow-amber-500/20'
                        : 'bg-slate-800/50 text-slate-400 border border-slate-700 hover:border-amber-500/50'
                    } disabled:opacity-50 disabled:cursor-not-allowed`}
                  >
                    {limit.label}
                  </button>
                ))}
              </div>

              {isCustom && (
                <div className="mt-3">
                  <div className="relative">
                    <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400">$</span>
                    <input
                      type="number"
                      value={customAmount}
                      onChange={(e) => setCustomAmount(e.target.value)}
                      placeholder="Enter custom amount"
                      min="100"
                      step="100"
                      disabled={!!waitingPeriod}
                      className="w-full bg-slate-800/50 border border-slate-700 rounded-xl pl-8 pr-16 py-3 text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:border-amber-500 disabled:opacity-50 disabled:cursor-not-allowed"
                    />
                    <span className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400">USDT</span>
                  </div>
                </div>
              )}

              {hasInsufficientBalance && isValidAmount && (
                <div className="mt-3 bg-red-500/10 border border-red-500/30 rounded-lg p-3">
                  <div className="flex items-center gap-2 text-red-400 text-sm">
                    <AlertCircle className="w-4 h-4 flex-shrink-0" />
                    <span>Insufficient balance. You need <span className="font-bold">{effectiveLimit.toLocaleString()} USDT</span> but only have <span className="font-bold">{availableBalance.toLocaleString()} USDT</span> available.</span>
                  </div>
                </div>
              )}
            </div>
          </div>

          {isValidAmount && !hasInsufficientBalance && (
            <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4">
              <div className="flex items-center gap-3">
                <Lock className="w-5 h-5 text-green-400" />
                <div>
                  <span className="text-green-400 font-semibold">{effectiveLimit.toLocaleString()} USDT</span>
                  <span className="text-green-300/80 text-sm ml-2">will be locked upon submission</span>
                </div>
              </div>
            </div>
          )}

          <div className="bg-slate-800/30 border border-slate-700/50 rounded-xl p-4">
            <p className="text-xs text-slate-400 leading-relaxed">
              By applying, you agree to our terms and conditions. Your application will be reviewed within 24-48 hours.
              The requested amount will be locked in your wallet during review. If approved, funds will be transferred to your Shark Card wallet.
              If declined, your funds will be automatically unlocked.
            </p>
          </div>

          <div className="flex gap-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-6 py-3 bg-slate-800 text-slate-300 rounded-xl font-medium hover:bg-slate-700 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || !fullName || !country || isCheckingEligibility || !!waitingPeriod || hasInsufficientBalance || !isValidAmount}
              className="flex-1 px-6 py-3 bg-gradient-to-br from-amber-500 to-orange-600 text-white rounded-xl font-medium hover:shadow-lg hover:shadow-amber-500/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isCheckingEligibility ? 'Checking eligibility...' :
               waitingPeriod ? `Wait ${waitingPeriod.daysRemaining} more day${waitingPeriod.daysRemaining > 1 ? 's' : ''}` :
               isSubmitting ? 'Submitting...' :
               <>
                 <Lock className="w-4 h-4" />
                 Submit & Lock Funds
               </>}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
