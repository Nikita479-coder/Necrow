import { useState, useEffect } from 'react';
import { Star, Gift, ArrowRight, Check, MessageSquare, Award, TrendingUp, ExternalLink, Shield, Calendar, Clock, AlertTriangle } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';

export default function ReviewBonus() {
  const { user, userProfile } = useAuth();
  const { showToast } = useToast();
  const [trustpilotUsername, setTrustpilotUsername] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [hasSubmitted, setHasSubmitted] = useState(false);
  const [kycStatus, setKycStatus] = useState<string | null>(null);
  const [isLoadingKyc, setIsLoadingKyc] = useState(true);

  useEffect(() => {
    if (user) {
      loadKycStatus();
    } else {
      setIsLoadingKyc(false);
    }
  }, [user]);

  const loadKycStatus = async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('kyc_level')
        .eq('id', user.id)
        .single();

      if (!error && data) {
        setKycStatus(data.kyc_level);
      }
    } catch (error) {
      console.error('Error loading KYC status:', error);
    } finally {
      setIsLoadingKyc(false);
    }
  };

  const isKycVerified = kycStatus === 'verified' || kycStatus === 'advanced';

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!user) {
      showToast('Please sign in to claim your review bonus', 'error');
      return;
    }

    if (!isKycVerified) {
      showToast('Please complete KYC verification first', 'error');
      return;
    }

    if (!trustpilotUsername.trim()) {
      showToast('Please enter your Trustpilot username', 'error');
      return;
    }

    setIsSubmitting(true);

    try {
      const { error } = await supabase
        .from('support_tickets')
        .insert({
          user_id: user.id,
          subject: 'TrustPilot Review Bonus Claim ($5)',
          message: `I have completed KYC verification and left a 5-star review on Trustpilot.\n\nMy Trustpilot username is: ${trustpilotUsername}\n\nPlease verify and award the $5 USDT TrustPilot Review Bonus.`,
          status: 'open',
          priority: 'medium',
          category: 'other'
        });

      if (error) throw error;

      setHasSubmitted(true);
      showToast('Bonus claim submitted! Our team will verify and credit your $5 review bonus within 24 hours.', 'success');
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : 'Failed to submit claim';
      showToast(errorMessage, 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const testimonials = [
    {
      name: 'Michael R.',
      rating: 5,
      text: 'Amazing platform! Completed KYC in minutes and got my bonus. The trading experience is excellent.',
      date: '2 days ago'
    },
    {
      name: 'Sarah L.',
      rating: 5,
      text: 'Best crypto exchange I have used. The review bonus was a great incentive to try the platform.',
      date: '1 week ago'
    },
    {
      name: 'David K.',
      rating: 5,
      text: 'Fast verification, excellent customer support, and the bonuses are real. Highly recommend!',
      date: '2 weeks ago'
    }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 bg-yellow-500/10 border border-yellow-500/20 rounded-full px-4 py-2 mb-6">
            <Star className="w-4 h-4 text-yellow-400 fill-yellow-400" />
            <span className="text-yellow-400 text-sm font-semibold">TRUSTPILOT REVIEW BONUS</span>
          </div>

          <h1 className="text-5xl md:text-6xl font-bold text-white mb-6">
            Leave a Review &<br />Earn <span className="text-yellow-400">$5 USDT</span>
          </h1>

          <p className="text-xl text-gray-300 max-w-3xl mx-auto mb-8">
            Share your experience on TrustPilot and earn a $5 USDT locked trading bonus. KYC verification required.
          </p>

          <div className="flex items-center justify-center gap-2 mb-8">
            {[1, 2, 3, 4, 5].map(i => (
              <Star key={i} className="w-8 h-8 text-yellow-400 fill-yellow-400" />
            ))}
            <span className="text-2xl font-bold text-white ml-2">4.9/5</span>
            <span className="text-gray-400 ml-2">(1,247 reviews)</span>
          </div>

          {!user ? (
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="/signup"
                className="inline-flex items-center justify-center gap-2 bg-yellow-500 hover:bg-yellow-600 text-gray-900 px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Sign Up to Claim Bonus
                <ArrowRight className="w-5 h-5" />
              </a>
              <a
                href="https://www.trustpilot.com/review/sharktrades.com"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center gap-2 bg-gray-700 hover:bg-gray-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                View Our Reviews
                <ExternalLink className="w-5 h-5" />
              </a>
            </div>
          ) : (
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              {!isKycVerified && (
                <a
                  href="/kyc"
                  className="inline-flex items-center justify-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
                >
                  Complete KYC First
                  <Shield className="w-5 h-5" />
                </a>
              )}
              <a
                href="https://www.trustpilot.com/review/sharktrades.com"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center gap-2 bg-yellow-500 hover:bg-yellow-600 text-gray-900 px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Leave Your Review Now
                <ExternalLink className="w-5 h-5" />
              </a>
            </div>
          )}
        </div>

        <div className="grid md:grid-cols-4 gap-6 mb-16">
          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6 text-center">
            <div className="w-12 h-12 bg-blue-500/10 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Shield className="w-6 h-6 text-blue-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Complete KYC</h3>
            <p className="text-gray-400">Verify your identity</p>
          </div>

          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6 text-center">
            <div className="w-12 h-12 bg-yellow-500/10 rounded-lg flex items-center justify-center mx-auto mb-4">
              <MessageSquare className="w-6 h-6 text-yellow-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Write Review</h3>
            <p className="text-gray-400">Leave a 5-star review</p>
          </div>

          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6 text-center">
            <div className="w-12 h-12 bg-green-500/10 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Check className="w-6 h-6 text-green-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Submit Claim</h3>
            <p className="text-gray-400">Fill the form below</p>
          </div>

          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6 text-center">
            <div className="w-12 h-12 bg-emerald-500/10 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Gift className="w-6 h-6 text-emerald-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Get $5 USDT</h3>
            <p className="text-gray-400">Bonus credited within 24h</p>
          </div>
        </div>

        <div className="bg-gradient-to-br from-orange-500/10 to-red-500/10 border border-orange-500/20 rounded-2xl p-6 mb-8">
          <h3 className="text-lg font-bold text-white mb-4 flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-orange-400" />
            Unlock Requirements - Read Carefully!
          </h3>
          <p className="text-gray-300 mb-4">
            This $5 bonus is awarded as a <span className="text-yellow-400 font-semibold">locked trading bonus</span> (7-day expiry).
            To withdraw it, you must complete ALL of the following:
          </p>
          <div className="grid md:grid-cols-2 gap-4">
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-2">
                <TrendingUp className="w-5 h-5 text-blue-400" />
                <span className="font-semibold text-white">Trading Volume</span>
              </div>
              <p className="text-gray-400 text-sm">Complete $2,500 in trading volume using the bonus funds (500x the bonus amount).</p>
            </div>
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-2">
                <Calendar className="w-5 h-5 text-green-400" />
                <span className="font-semibold text-white">30 Consecutive Days</span>
              </div>
              <p className="text-gray-400 text-sm">Trade for 30 consecutive days. Missing a day resets your streak to 0!</p>
            </div>
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-2">
                <Clock className="w-5 h-5 text-yellow-400" />
                <span className="font-semibold text-white">2 Trades Per Day</span>
              </div>
              <p className="text-gray-400 text-sm">Complete at least 2 qualifying trades each day to count toward your streak.</p>
            </div>
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="flex items-center gap-3 mb-2">
                <Clock className="w-5 h-5 text-purple-400" />
                <span className="font-semibold text-white">15+ Minute Trades</span>
              </div>
              <p className="text-gray-400 text-sm">Each qualifying trade must be held for at least 15 minutes from open to close.</p>
            </div>
          </div>
          <p className="text-gray-400 text-sm mt-4">
            <span className="text-yellow-400">Note:</span> Bonus expires in 7 days. Profits earned from trading with the locked bonus are yours to keep!
          </p>
        </div>

        <div className="grid lg:grid-cols-2 gap-8 mb-16">
          <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8">
            <h2 className="text-2xl font-bold text-white mb-6">How to Claim Your $5 Review Bonus</h2>

            <div className="space-y-6">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold">
                  1
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Complete KYC Verification</h3>
                  <p className="text-gray-400 mb-3">Submit your identity documents and wait for approval. This usually takes 1-24 hours.</p>
                  <a
                    href="/kyc"
                    className="inline-flex items-center gap-2 text-blue-400 hover:text-blue-300 text-sm"
                  >
                    Go to KYC Verification
                    <ArrowRight className="w-4 h-4" />
                  </a>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-10 h-10 bg-yellow-500 rounded-full flex items-center justify-center text-gray-900 font-bold">
                  2
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Visit Trustpilot</h3>
                  <p className="text-gray-400 mb-3">Click the button above to visit our Trustpilot page and create an account if you don't have one.</p>
                  <a
                    href="https://www.trustpilot.com/review/sharktrades.com"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 text-yellow-400 hover:text-yellow-300 text-sm"
                  >
                    Go to Trustpilot
                    <ExternalLink className="w-4 h-4" />
                  </a>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-10 h-10 bg-yellow-500 rounded-full flex items-center justify-center text-gray-900 font-bold">
                  3
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Write a 5-Star Review</h3>
                  <p className="text-gray-400">Share your honest experience with Shark Trades. Rate our platform 5 stars and write about your trading experience.</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-10 h-10 bg-green-500 rounded-full flex items-center justify-center text-white font-bold">
                  4
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Submit Your Claim</h3>
                  <p className="text-gray-400">Fill out the form with your Trustpilot username. Our team will verify and credit your $5 bonus within 24 hours.</p>
                </div>
              </div>
            </div>

            <div className="mt-8 bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4">
              <h4 className="text-sm font-semibold text-yellow-400 mb-2">Important Notes:</h4>
              <ul className="text-sm text-gray-400 space-y-1">
                <li>- Reviews must be genuine and 5 stars</li>
                <li>- KYC must be fully verified before claiming</li>
                <li>- One review bonus per user account</li>
                <li>- $5 bonus is credited as locked trading funds (7-day expiry)</li>
                <li>- Complete volume + consecutive trading days to unlock</li>
              </ul>
            </div>
          </div>

          <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8">
            <h2 className="text-2xl font-bold text-white mb-6">Claim Your $5 USDT Review Bonus</h2>

            {!user ? (
              <div className="text-center py-12">
                <Award className="w-16 h-16 text-yellow-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-white mb-2">Sign in Required</h3>
                <p className="text-gray-400 mb-6">Please sign in or create an account to claim your review bonus.</p>
                <div className="flex flex-col gap-3">
                  <a
                    href="/signup"
                    className="inline-flex items-center justify-center gap-2 bg-yellow-500 hover:bg-yellow-600 text-gray-900 px-6 py-3 rounded-lg font-semibold transition-colors"
                  >
                    Create Account
                    <ArrowRight className="w-5 h-5" />
                  </a>
                  <a
                    href="/signin"
                    className="inline-flex items-center justify-center gap-2 bg-gray-700 hover:bg-gray-600 text-white px-6 py-3 rounded-lg font-semibold transition-colors"
                  >
                    Sign In
                  </a>
                </div>
              </div>
            ) : isLoadingKyc ? (
              <div className="text-center py-12">
                <div className="w-12 h-12 border-4 border-yellow-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
                <p className="text-gray-400">Loading your account status...</p>
              </div>
            ) : hasSubmitted ? (
              <div className="text-center py-12">
                <Check className="w-16 h-16 text-green-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-white mb-2">Claim Submitted!</h3>
                <p className="text-gray-400 mb-6">
                  Thank you! Our team will verify your Trustpilot review and credit your $5 USDT bonus within 24 hours.
                </p>
                <a
                  href="/wallet"
                  className="inline-flex items-center justify-center gap-2 bg-yellow-500 hover:bg-yellow-600 text-gray-900 px-6 py-3 rounded-lg font-semibold transition-colors"
                >
                  View Wallet
                  <ArrowRight className="w-5 h-5" />
                </a>
              </div>
            ) : (
              <>
                <div className={`mb-6 p-4 rounded-lg border ${isKycVerified ? 'bg-green-500/10 border-green-500/20' : 'bg-red-500/10 border-red-500/20'}`}>
                  <div className="flex items-center gap-3">
                    <Shield className={`w-6 h-6 ${isKycVerified ? 'text-green-400' : 'text-red-400'}`} />
                    <div>
                      <h4 className={`font-semibold ${isKycVerified ? 'text-green-400' : 'text-red-400'}`}>
                        KYC Status: {isKycVerified ? 'Verified' : 'Not Verified'}
                      </h4>
                      <p className="text-sm text-gray-400">
                        {isKycVerified
                          ? 'Your identity has been verified. You can proceed with the claim.'
                          : 'You must complete KYC verification before claiming this bonus.'}
                      </p>
                    </div>
                  </div>
                  {!isKycVerified && (
                    <a
                      href="/kyc"
                      className="mt-3 inline-flex items-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-colors"
                    >
                      Complete KYC Now
                      <ArrowRight className="w-4 h-4" />
                    </a>
                  )}
                </div>

                <form onSubmit={handleSubmitReview} className="space-y-6">
                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">
                      Shark Trades Username
                    </label>
                    <input
                      type="text"
                      value={userProfile?.full_name || user?.email || ''}
                      disabled
                      className="w-full bg-gray-700/50 border border-gray-600 rounded-lg px-4 py-3 text-white"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-300 mb-2">
                      Trustpilot Username *
                    </label>
                    <input
                      type="text"
                      value={trustpilotUsername}
                      onChange={(e) => setTrustpilotUsername(e.target.value)}
                      placeholder="Enter your Trustpilot username"
                      required
                      disabled={!isKycVerified}
                      className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-3 text-white placeholder-gray-400 focus:border-yellow-500 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
                    />
                    <p className="text-xs text-gray-400 mt-1">
                      Your Trustpilot username (not email). Find it on your Trustpilot profile.
                    </p>
                  </div>

                  <div className="bg-gray-700/30 border border-gray-600 rounded-lg p-4">
                    <h4 className="text-sm font-semibold text-white mb-2">Claim Checklist:</h4>
                    <div className="space-y-2">
                      <label className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          required
                          disabled={!isKycVerified}
                          className="rounded border-gray-600 disabled:opacity-50"
                        />
                        <span className="text-sm text-gray-300">My KYC verification is complete</span>
                      </label>
                      <label className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          required
                          disabled={!isKycVerified}
                          className="rounded border-gray-600 disabled:opacity-50"
                        />
                        <span className="text-sm text-gray-300">I have left a 5-star review on Trustpilot</span>
                      </label>
                      <label className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          required
                          disabled={!isKycVerified}
                          className="rounded border-gray-600 disabled:opacity-50"
                        />
                        <span className="text-sm text-gray-300">My review is honest and genuine</span>
                      </label>
                      <label className="flex items-center gap-2">
                        <input
                          type="checkbox"
                          required
                          disabled={!isKycVerified}
                          className="rounded border-gray-600 disabled:opacity-50"
                        />
                        <span className="text-sm text-gray-300">I understand the unlock requirements (30 days + volume)</span>
                      </label>
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={isSubmitting || !isKycVerified}
                    className="w-full bg-yellow-500 hover:bg-yellow-600 disabled:bg-gray-600 disabled:cursor-not-allowed text-gray-900 font-semibold py-4 rounded-lg transition-colors flex items-center justify-center gap-2"
                  >
                    {isSubmitting ? 'Submitting...' : !isKycVerified ? 'Complete KYC First' : 'Submit & Claim $5 USDT'}
                    <ArrowRight className="w-5 h-5" />
                  </button>
                </form>
              </>
            )}

            <div className="mt-6 text-center">
              <p className="text-sm text-gray-400">
                Need help?{' '}
                <a href="/support" className="text-yellow-400 hover:text-yellow-300">
                  Contact Support
                </a>
              </p>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">What Our Users Are Saying</h2>

          <div className="grid md:grid-cols-3 gap-6">
            {testimonials.map((testimonial, index) => (
              <div key={index} className="bg-gray-900/50 border border-gray-700 rounded-xl p-6">
                <div className="flex items-center gap-1 mb-3">
                  {[1, 2, 3, 4, 5].map(i => (
                    <Star
                      key={i}
                      className={`w-4 h-4 ${
                        i <= testimonial.rating
                          ? 'text-yellow-400 fill-yellow-400'
                          : 'text-gray-600'
                      }`}
                    />
                  ))}
                </div>
                <p className="text-gray-300 mb-4">{testimonial.text}</p>
                <div className="flex items-center justify-between">
                  <span className="text-sm font-semibold text-white">{testimonial.name}</span>
                  <span className="text-xs text-gray-400">{testimonial.date}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">More Ways to Earn</h2>

          <div className="grid md:grid-cols-3 gap-6">
            <a href="/no-deposit-bonus" className="bg-gray-900/50 border border-gray-700 rounded-xl p-6 hover:border-green-500/50 transition-colors">
              <Gift className="w-8 h-8 text-green-400 mb-3" />
              <h3 className="text-xl font-bold text-white mb-2">No Deposit Bonus</h3>
              <p className="text-gray-400 mb-4">Get started with locked trading bonus. No deposit required!</p>
              <div className="text-green-400 font-semibold">Learn More</div>
            </a>

            <a href="/refer-friends-bonus" className="bg-gray-900/50 border border-gray-700 rounded-xl p-6 hover:border-blue-500/50 transition-colors">
              <TrendingUp className="w-8 h-8 text-blue-400 mb-3" />
              <h3 className="text-xl font-bold text-white mb-2">Refer Friends</h3>
              <p className="text-gray-400 mb-4">Earn $20 per friend plus lifetime commissions up to 70%.</p>
              <div className="text-blue-400 font-semibold">Start Referring</div>
            </a>

            <a href="/bonusterms" className="bg-gray-900/50 border border-gray-700 rounded-xl p-6 hover:border-cyan-500/50 transition-colors">
              <Award className="w-8 h-8 text-cyan-400 mb-3" />
              <h3 className="text-xl font-bold text-white mb-2">Welcome Package</h3>
              <p className="text-gray-400 mb-4">Get up to $1,630 in deposit match bonuses when you fund your account.</p>
              <div className="text-cyan-400 font-semibold">View Bonuses</div>
            </a>
          </div>
        </div>

        <div className="bg-gradient-to-r from-yellow-500/10 to-orange-500/10 border border-yellow-500/20 rounded-2xl p-8 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">Your Opinion Matters</h2>
          <p className="text-xl text-gray-300 mb-8">
            Leave a TrustPilot review and earn $5 USDT in locked trading bonus!
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            {user && !isKycVerified && (
              <a
                href="/kyc"
                className="inline-flex items-center justify-center gap-2 bg-blue-500 hover:bg-blue-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Complete KYC
                <Shield className="w-5 h-5" />
              </a>
            )}
            <a
              href="https://www.trustpilot.com/review/sharktrades.com"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center gap-2 bg-yellow-500 hover:bg-yellow-600 text-gray-900 px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
            >
              Leave Your Review Now
              <ExternalLink className="w-5 h-5" />
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
