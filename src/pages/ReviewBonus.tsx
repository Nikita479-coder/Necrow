import { useState } from 'react';
import { Star, Gift, ArrowRight, Check, MessageSquare, Award, TrendingUp, ExternalLink } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';

export default function ReviewBonus() {
  const { user, userProfile } = useAuth();
  const { showToast } = useToast();
  const [trustpilotUsername, setTrustpilotUsername] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [hasSubmitted, setHasSubmitted] = useState(false);

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!user) {
      showToast('Please sign in to claim your review bonus', 'error');
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
          subject: 'Trustpilot Review Bonus Claim',
          message: `I have left a review on Trustpilot. My Trustpilot username is: ${trustpilotUsername}`,
          status: 'open',
          priority: 'medium',
          category: 'other'
        });

      if (error) throw error;

      setHasSubmitted(true);
      showToast('Review claim submitted! Our team will verify and credit your bonus within 24 hours.', 'success');
    } catch (error: any) {
      showToast(error.message || 'Failed to submit claim', 'error');
    } finally {
      setIsSubmitting(false);
    }
  };

  const testimonials = [
    {
      name: 'Michael R.',
      rating: 5,
      text: 'Amazing platform! Got my $5 bonus instantly after submitting my review. Great trading experience.',
      date: '2 days ago'
    },
    {
      name: 'Sarah L.',
      rating: 5,
      text: 'Best crypto exchange I have used. The review bonus was a nice surprise and the platform is very user-friendly.',
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
            <span className="text-yellow-400 text-sm font-semibold">QUICK & EASY BONUS</span>
          </div>

          <h1 className="text-5xl md:text-6xl font-bold text-white mb-6">
            Share Your Experience,<br />Earn <span className="text-yellow-400">$5 USDT</span> Instantly
          </h1>

          <p className="text-xl text-gray-300 max-w-3xl mx-auto mb-8">
            Leave an honest review on Trustpilot and get $5 USDT credited to your account.
            Help other traders discover our platform!
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
            <a
              href="https://www.trustpilot.com/review/sharktrades.com"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center gap-2 bg-yellow-500 hover:bg-yellow-600 text-gray-900 px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
            >
              Leave Your Review Now
              <ExternalLink className="w-5 h-5" />
            </a>
          )}
        </div>

        <div className="grid md:grid-cols-3 gap-6 mb-16">
          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6 text-center">
            <div className="w-12 h-12 bg-yellow-500/10 rounded-lg flex items-center justify-center mx-auto mb-4">
              <MessageSquare className="w-6 h-6 text-yellow-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Write Review</h3>
            <p className="text-gray-400">Share your honest experience</p>
          </div>

          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6 text-center">
            <div className="w-12 h-12 bg-green-500/10 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Check className="w-6 h-6 text-green-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Submit Username</h3>
            <p className="text-gray-400">Fill the form below with your details</p>
          </div>

          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6 text-center">
            <div className="w-12 h-12 bg-blue-500/10 rounded-lg flex items-center justify-center mx-auto mb-4">
              <Gift className="w-6 h-6 text-blue-400" />
            </div>
            <h3 className="text-xl font-bold text-white mb-2">Get $5 USDT</h3>
            <p className="text-gray-400">Bonus credited within 24 hours</p>
          </div>
        </div>

        <div className="grid lg:grid-cols-2 gap-8 mb-16">
          <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8">
            <h2 className="text-2xl font-bold text-white mb-6">How to Claim Your Review Bonus</h2>

            <div className="space-y-6">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-10 h-10 bg-yellow-500 rounded-full flex items-center justify-center text-gray-900 font-bold">
                  1
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
                  2
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Write Your Review</h3>
                  <p className="text-gray-400">Share your honest experience with Shark Trades. Rate our platform from 1-5 stars and write about your trading experience.</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-10 h-10 bg-yellow-500 rounded-full flex items-center justify-center text-gray-900 font-bold">
                  3
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Submit Your Username</h3>
                  <p className="text-gray-400">Fill out the form below with your Trustpilot username so we can verify your review and credit your bonus.</p>
                </div>
              </div>

              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-10 h-10 bg-yellow-500 rounded-full flex items-center justify-center text-gray-900 font-bold">
                  4
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-white mb-2">Receive Your Bonus</h3>
                  <p className="text-gray-400">Our team will verify your review and credit $5 USDT to your account within 24 hours.</p>
                </div>
              </div>
            </div>

            <div className="mt-8 bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-4">
              <h4 className="text-sm font-semibold text-yellow-400 mb-2">Important Notes:</h4>
              <ul className="text-sm text-gray-400 space-y-1">
                <li>• Reviews must be genuine and honest</li>
                <li>• One bonus per user account</li>
                <li>• Bonus is credited as locked trading funds</li>
                <li>• Complete volume requirements to unlock</li>
              </ul>
            </div>
          </div>

          <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8">
            <h2 className="text-2xl font-bold text-white mb-6">Claim Your $5 USDT Bonus</h2>

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
            ) : hasSubmitted ? (
              <div className="text-center py-12">
                <Check className="w-16 h-16 text-green-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-white mb-2">Claim Submitted!</h3>
                <p className="text-gray-400 mb-6">
                  Thank you for your review! Our team will verify it and credit your $5 USDT bonus within 24 hours.
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
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-3 text-white placeholder-gray-400 focus:border-yellow-500 focus:outline-none"
                  />
                  <p className="text-xs text-gray-400 mt-1">
                    Your Trustpilot username (not email). Find it on your Trustpilot profile.
                  </p>
                </div>

                <div className="bg-gray-700/30 border border-gray-600 rounded-lg p-4">
                  <h4 className="text-sm font-semibold text-white mb-2">Review Checklist:</h4>
                  <div className="space-y-2">
                    <label className="flex items-center gap-2">
                      <input type="checkbox" required className="rounded border-gray-600" />
                      <span className="text-sm text-gray-300">I have left a review on Trustpilot</span>
                    </label>
                    <label className="flex items-center gap-2">
                      <input type="checkbox" required className="rounded border-gray-600" />
                      <span className="text-sm text-gray-300">My review is honest and genuine</span>
                    </label>
                    <label className="flex items-center gap-2">
                      <input type="checkbox" required className="rounded border-gray-600" />
                      <span className="text-sm text-gray-300">I understand this is a one-time bonus</span>
                    </label>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full bg-yellow-500 hover:bg-yellow-600 disabled:bg-gray-600 text-gray-900 font-semibold py-4 rounded-lg transition-colors flex items-center justify-center gap-2"
                >
                  {isSubmitting ? 'Submitting...' : 'Submit & Claim $5 USDT'}
                  <ArrowRight className="w-5 h-5" />
                </button>
              </form>
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
              <p className="text-gray-400 mb-4">Get $20 USDT free with KYC verification. No deposit required!</p>
              <div className="text-green-400 font-semibold">Claim $20 USDT →</div>
            </a>

            <a href="/refer-friends-bonus" className="bg-gray-900/50 border border-gray-700 rounded-xl p-6 hover:border-blue-500/50 transition-colors">
              <TrendingUp className="w-8 h-8 text-blue-400 mb-3" />
              <h3 className="text-xl font-bold text-white mb-2">Refer Friends</h3>
              <p className="text-gray-400 mb-4">Earn $20 per friend plus lifetime commissions up to 70%.</p>
              <div className="text-blue-400 font-semibold">Start Referring →</div>
            </a>

            <a href="/bonusterms" className="bg-gray-900/50 border border-gray-700 rounded-xl p-6 hover:border-purple-500/50 transition-colors">
              <Award className="w-8 h-8 text-purple-400 mb-3" />
              <h3 className="text-xl font-bold text-white mb-2">Welcome Package</h3>
              <p className="text-gray-400 mb-4">Get up to $1,630 in deposit match bonuses when you fund your account.</p>
              <div className="text-purple-400 font-semibold">View Bonuses →</div>
            </a>
          </div>
        </div>

        <div className="bg-gradient-to-r from-yellow-500/10 to-orange-500/10 border border-yellow-500/20 rounded-2xl p-8 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">Your Opinion Matters</h2>
          <p className="text-xl text-gray-300 mb-8">
            Help us improve and earn $5 USDT. It only takes 2 minutes!
          </p>
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
  );
}
