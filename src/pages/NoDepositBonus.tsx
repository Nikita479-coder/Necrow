import { useState } from 'react';
import { Gift, Check, ArrowRight, Shield, Clock, Users, Star, TrendingUp, BadgeCheck, MessageSquare } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function NoDepositBonus() {
  const { user } = useAuth();
  const [claimed, setClaimed] = useState(0);

  useState(() => {
    const interval = setInterval(() => {
      setClaimed(prev => prev < 247 ? prev + 1 : 247);
    }, 100);
    return () => clearInterval(interval);
  });

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 bg-green-500/10 border border-green-500/20 rounded-full px-4 py-2 mb-6">
            <Gift className="w-4 h-4 text-green-400" />
            <span className="text-green-400 text-sm font-semibold">LIMITED TIME OFFER</span>
          </div>

          <h1 className="text-5xl md:text-6xl font-bold text-white mb-6">
            Get Up to <span className="text-green-400">$25 USDT</span> in Verification Bonuses
          </h1>

          <p className="text-xl text-gray-300 max-w-3xl mx-auto mb-8">
            Start trading completely free! Earn a $20 USDT locked bonus instantly when your KYC is approved,
            plus an additional $5 USDT for leaving a TrustPilot review. No deposit required.
          </p>

          <div className="flex items-center justify-center gap-4 mb-8">
            <div className="flex -space-x-2">
              {[1, 2, 3, 4, 5].map(i => (
                <div key={i} className="w-10 h-10 rounded-full bg-gradient-to-br from-green-400 to-blue-500 border-2 border-gray-900" />
              ))}
            </div>
            <p className="text-gray-400">
              <span className="text-green-400 font-bold">{claimed}</span> traders claimed today
            </p>
          </div>

          {!user ? (
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="/signup"
                className="inline-flex items-center justify-center gap-2 bg-green-500 hover:bg-green-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Claim Your Bonus Now
                <ArrowRight className="w-5 h-5" />
              </a>
              <a
                href="/signin"
                className="inline-flex items-center justify-center gap-2 bg-gray-700 hover:bg-gray-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Already Have Account?
              </a>
            </div>
          ) : (
            <a
              href="/kyc"
              className="inline-flex items-center justify-center gap-2 bg-green-500 hover:bg-green-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
            >
              Complete Verification to Claim
              <ArrowRight className="w-5 h-5" />
            </a>
          )}
        </div>

        <div className="grid md:grid-cols-2 gap-6 mb-16">
          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-14 h-14 bg-green-500/10 rounded-xl flex items-center justify-center">
                <BadgeCheck className="w-7 h-7 text-green-400" />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white">KYC Verification</h3>
                <p className="text-green-400 font-bold text-lg">$20 USDT</p>
              </div>
            </div>
            <p className="text-gray-400">Verify your identity to unlock trading features. Your $20 USDT locked bonus is credited automatically upon approval.</p>
          </div>

          <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-xl p-6">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-14 h-14 bg-blue-500/10 rounded-xl flex items-center justify-center">
                <MessageSquare className="w-7 h-7 text-blue-400" />
              </div>
              <div>
                <h3 className="text-xl font-bold text-white">TrustPilot Review</h3>
                <p className="text-blue-400 font-bold text-lg">$5 USDT</p>
              </div>
            </div>
            <p className="text-gray-400">Share your experience on TrustPilot and claim an additional $5 USDT locked bonus. Submit your review link via support.</p>
          </div>
        </div>

        <div className="bg-gradient-to-br from-green-500/10 to-blue-500/10 border border-green-500/20 rounded-2xl p-8 text-center mb-16">
          <h2 className="text-2xl font-bold text-white mb-4">Total Verification Bonuses</h2>
          <div className="text-6xl font-bold text-green-400 mb-2">$25 USDT</div>
          <p className="text-gray-400 mb-6">Complete both steps to maximize your earnings - each bonus is awarded separately</p>
          <div className="flex justify-center gap-8">
            <div className="text-center">
              <BadgeCheck className="w-8 h-8 text-green-400 mx-auto mb-2" />
              <p className="text-white font-semibold">KYC</p>
              <p className="text-green-400">$20</p>
            </div>
            <div className="text-2xl text-gray-500 self-center">+</div>
            <div className="text-center">
              <Star className="w-8 h-8 text-yellow-400 mx-auto mb-2" />
              <p className="text-white font-semibold">Review</p>
              <p className="text-blue-400">$5</p>
            </div>
            <div className="text-2xl text-gray-500 self-center">=</div>
            <div className="text-center">
              <Gift className="w-8 h-8 text-green-400 mx-auto mb-2" />
              <p className="text-white font-semibold">Total</p>
              <p className="text-green-400 font-bold">$25</p>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-gray-800 to-gray-900 border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">How to Claim Your Bonuses</h2>

          <div className="grid md:grid-cols-4 gap-8">
            <div className="relative">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-xl">
                  1
                </div>
                <div>
                  <h3 className="text-xl font-semibold text-white mb-2">Sign Up Free</h3>
                  <p className="text-gray-400">Create your account in under 2 minutes. No credit card required.</p>
                </div>
              </div>
              <div className="hidden md:block absolute top-6 left-full w-full h-0.5 bg-gradient-to-r from-green-500 to-transparent -translate-x-6" />
            </div>

            <div className="relative">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-xl">
                  2
                </div>
                <div>
                  <h3 className="text-xl font-semibold text-white mb-2">Complete KYC</h3>
                  <p className="text-gray-400">Verify your identity and receive <span className="text-green-400 font-semibold">$20 USDT</span> locked bonus automatically.</p>
                </div>
              </div>
              <div className="hidden md:block absolute top-6 left-full w-full h-0.5 bg-gradient-to-r from-green-500 to-transparent -translate-x-6" />
            </div>

            <div className="relative">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-xl">
                  3
                </div>
                <div>
                  <h3 className="text-xl font-semibold text-white mb-2">Leave Review</h3>
                  <p className="text-gray-400">Share your experience on TrustPilot for <span className="text-blue-400 font-semibold">$5 USDT</span> more.</p>
                </div>
              </div>
              <div className="hidden md:block absolute top-6 left-full w-full h-0.5 bg-gradient-to-r from-blue-500 to-transparent -translate-x-6" />
            </div>

            <div className="flex items-start gap-4">
              <div className="flex-shrink-0 w-12 h-12 bg-green-500 rounded-full flex items-center justify-center text-white font-bold text-xl">
                4
              </div>
              <div>
                <h3 className="text-xl font-semibold text-white mb-2">Start Trading</h3>
                <p className="text-gray-400">Your locked bonuses are ready for futures trading!</p>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <div className="grid md:grid-cols-2 gap-8 items-center">
            <div>
              <h2 className="text-3xl font-bold text-white mb-6">Why Choose Our Verification Bonus?</h2>

              <div className="space-y-4">
                <div className="flex items-start gap-3">
                  <Check className="w-6 h-6 text-green-400 flex-shrink-0 mt-1" />
                  <div>
                    <h3 className="text-lg font-semibold text-white mb-1">100% Risk-Free</h3>
                    <p className="text-gray-400">Trade with real money without risking your own capital</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Check className="w-6 h-6 text-green-400 flex-shrink-0 mt-1" />
                  <div>
                    <h3 className="text-lg font-semibold text-white mb-1">Full Platform Access</h3>
                    <p className="text-gray-400">Trade futures, spot, and use all advanced features</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Check className="w-6 h-6 text-green-400 flex-shrink-0 mt-1" />
                  <div>
                    <h3 className="text-lg font-semibold text-white mb-1">Withdraw Your Profits</h3>
                    <p className="text-gray-400">Complete trading volume requirements and withdraw earnings</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Check className="w-6 h-6 text-green-400 flex-shrink-0 mt-1" />
                  <div>
                    <h3 className="text-lg font-semibold text-white mb-1">Stack Additional Bonuses</h3>
                    <p className="text-gray-400">Combine with deposit bonuses for up to $1,635 total</p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Check className="w-6 h-6 text-green-400 flex-shrink-0 mt-1" />
                  <div>
                    <h3 className="text-lg font-semibold text-white mb-1">Zero Trading Fees</h3>
                    <p className="text-gray-400">Enjoy 7 days of zero trading fees after KYC verification</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-green-500/10 to-blue-500/10 border border-green-500/20 rounded-xl p-8">
              <div className="text-center mb-6">
                <div className="inline-flex items-center justify-center w-20 h-20 bg-green-500/20 rounded-full mb-4">
                  <Gift className="w-10 h-10 text-green-400" />
                </div>
                <h3 className="text-2xl font-bold text-white mb-2">Total Welcome Package</h3>
                <div className="text-5xl font-bold text-green-400 mb-2">$1,635</div>
                <p className="text-gray-400">When you combine all bonuses</p>
              </div>

              <div className="space-y-3 text-sm">
                <div className="flex justify-between items-center py-2 border-b border-gray-700">
                  <span className="text-gray-400">KYC Verification Bonus</span>
                  <span className="text-white font-semibold">$20</span>
                </div>
                <div className="flex justify-between items-center py-2 border-b border-gray-700">
                  <span className="text-gray-400">TrustPilot Review Bonus</span>
                  <span className="text-white font-semibold">$5</span>
                </div>
                <div className="flex justify-between items-center py-2 border-b border-gray-700">
                  <span className="text-gray-400">1st Deposit Match (100%)</span>
                  <span className="text-white font-semibold">$500</span>
                </div>
                <div className="flex justify-between items-center py-2 border-b border-gray-700">
                  <span className="text-gray-400">2nd Deposit Match (50%)</span>
                  <span className="text-white font-semibold">$500</span>
                </div>
                <div className="flex justify-between items-center py-2 border-b border-gray-700">
                  <span className="text-gray-400">3rd Deposit Match (20%)</span>
                  <span className="text-white font-semibold">$610</span>
                </div>
                <div className="flex justify-between items-center py-3 bg-green-500/10 -mx-4 px-4 rounded-lg mt-4">
                  <span className="text-white font-bold">Total Bonus Value</span>
                  <span className="text-green-400 font-bold text-xl">$1,635</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-gray-800/50 backdrop-blur border border-gray-700 rounded-2xl p-8 md:p-12 mb-16">
          <h2 className="text-3xl font-bold text-white mb-8 text-center">Frequently Asked Questions</h2>

          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <h3 className="text-lg font-semibold text-white mb-2">Is this really free?</h3>
              <p className="text-gray-400">Yes! You get $20 USDT automatically when your KYC is approved, plus $5 more for a TrustPilot review. No deposit required.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">Can I withdraw the bonus?</h3>
              <p className="text-gray-400">The bonus is locked for trading. Complete the volume requirements to unlock and withdraw your profits.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">How long does KYC take?</h3>
              <p className="text-gray-400">Our KYC process typically takes 5-10 minutes. The $20 bonus is credited immediately after approval.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">How do I get the review bonus?</h3>
              <p className="text-gray-400">After KYC approval, leave a review on TrustPilot and submit the link in your rewards section. The $5 bonus is credited within 24 hours.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">Can I get more bonuses?</h3>
              <p className="text-gray-400">Yes! Stack this with deposit bonuses, referral rewards, and our copy trading bonus for maximum value.</p>
            </div>

            <div>
              <h3 className="text-lg font-semibold text-white mb-2">Is there a time limit?</h3>
              <p className="text-gray-400">Claim your bonus anytime! However, volume requirements must be met within 30 days for withdrawal.</p>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-r from-green-500/10 to-blue-500/10 border border-green-500/20 rounded-2xl p-8 text-center">
          <div className="max-w-3xl mx-auto">
            <h2 className="text-3xl font-bold text-white mb-4">Ready to Claim Your Verification Bonuses?</h2>
            <p className="text-xl text-gray-300 mb-8">
              Join thousands of traders who started with our verification bonuses. Zero risk, real profits.
            </p>

            <div className="flex items-center justify-center gap-6 mb-8">
              <div className="text-center">
                <div className="text-3xl font-bold text-green-400">247</div>
                <div className="text-sm text-gray-400">Claimed Today</div>
              </div>
              <div className="w-px h-12 bg-gray-700" />
              <div className="text-center">
                <div className="text-3xl font-bold text-green-400">12,459</div>
                <div className="text-sm text-gray-400">Total Claims</div>
              </div>
              <div className="w-px h-12 bg-gray-700" />
              <div className="text-center">
                <div className="text-3xl font-bold text-green-400">4.9</div>
                <div className="text-sm text-gray-400">TrustPilot Rating</div>
              </div>
            </div>

            {!user ? (
              <a
                href="/signup"
                className="inline-flex items-center justify-center gap-2 bg-green-500 hover:bg-green-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Claim Your Bonus Now
                <ArrowRight className="w-5 h-5" />
              </a>
            ) : (
              <a
                href="/kyc"
                className="inline-flex items-center justify-center gap-2 bg-green-500 hover:bg-green-600 text-white px-8 py-4 rounded-lg font-semibold text-lg transition-colors"
              >
                Complete Verification to Claim
                <ArrowRight className="w-5 h-5" />
              </a>
            )}
          </div>
        </div>

        <div className="mt-12 grid grid-cols-2 md:grid-cols-4 gap-6">
          <div className="text-center">
            <Shield className="w-8 h-8 text-green-400 mx-auto mb-2" />
            <h4 className="text-sm font-semibold text-white mb-1">Secure Platform</h4>
            <p className="text-xs text-gray-400">Bank-grade security</p>
          </div>
          <div className="text-center">
            <Users className="w-8 h-8 text-blue-400 mx-auto mb-2" />
            <h4 className="text-sm font-semibold text-white mb-1">50K+ Users</h4>
            <p className="text-xs text-gray-400">Trusted worldwide</p>
          </div>
          <div className="text-center">
            <Star className="w-8 h-8 text-yellow-400 mx-auto mb-2" />
            <h4 className="text-sm font-semibold text-white mb-1">4.9/5 Rating</h4>
            <p className="text-xs text-gray-400">Excellent reviews</p>
          </div>
          <div className="text-center">
            <Clock className="w-8 h-8 text-cyan-400 mx-auto mb-2" />
            <h4 className="text-sm font-semibold text-white mb-1">24/7 Support</h4>
            <p className="text-xs text-gray-400">Always here to help</p>
          </div>
        </div>
      </div>
    </div>
  );
}
