import { useNavigation } from '../App';
import Navbar from '../components/Navbar';
import { ArrowLeft, Gift, AlertTriangle, Clock, DollarSign, TrendingUp, Shield, Info } from 'lucide-react';

export default function BonusTermsPage() {
  const { navigateTo } = useNavigation();

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-800">
      <Navbar />

      <div className="max-w-4xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('home')}
          className="flex items-center gap-2 text-slate-400 hover:text-white mb-6 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>

        <div className="bg-slate-800/50 backdrop-blur-sm rounded-xl border border-slate-700 overflow-hidden">
          <div className="bg-gradient-to-r from-[#f0b90b]/20 to-[#d9a506]/20 p-6 border-b border-slate-600">
            <div className="flex items-center gap-3">
              <Gift className="w-8 h-8 text-[#f0b90b]" />
              <div>
                <h1 className="text-2xl font-bold text-white">Promotional Bonus Terms and Conditions</h1>
                <div className="flex items-center gap-4 mt-2 text-sm text-slate-300">
                  <span>Version 1.0</span>
                  <span>Effective December 2024</span>
                </div>
              </div>
            </div>
          </div>

          <div className="p-8 space-y-8">
            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <Info className="w-5 h-5 text-blue-400" />
                1. Introduction
              </h2>
              <p className="text-slate-300 leading-relaxed mb-4">
                Welcome to the Shark Trades promotional bonus program. These terms and conditions govern the
                promotional bonuses offered to new users, including the KYC Verification Bonus and First
                Deposit Match Bonus. By participating in these promotions, you agree to be bound by these terms.
              </p>
              <div className="bg-slate-700/50 rounded-lg p-4 border border-slate-600">
                <p className="text-slate-300 text-sm">
                  <strong className="text-[#f0b90b]">What is a Locked Bonus?</strong> A locked bonus is trading
                  credit that can be used as margin for futures trading but cannot be withdrawn directly. Only
                  profits generated from trading with this bonus can be withdrawn. The bonus itself remains
                  locked and expires after a specified period.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <Shield className="w-5 h-5 text-green-400" />
                2. KYC Verification Bonus ($20 Free Credit)
              </h2>
              <div className="space-y-4">
                <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4">
                  <h3 className="font-semibold text-green-400 mb-2">Eligibility</h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Available to new users only</li>
                    <li>User must complete full KYC verification</li>
                    <li>KYC must be approved by our verification team</li>
                    <li>One-time offer per user/account</li>
                  </ul>
                </div>

                <div className="grid md:grid-cols-2 gap-4">
                  <div className="bg-slate-700/50 rounded-lg p-4">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <DollarSign className="w-4 h-4 text-[#f0b90b]" />
                      Award Amount
                    </h3>
                    <p className="text-slate-300 text-sm">
                      $20 USD credited as locked trading bonus instantly upon KYC approval
                    </p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <Clock className="w-4 h-4 text-[#f0b90b]" />
                      Validity Period
                    </h3>
                    <p className="text-slate-300 text-sm">
                      7 days from the date of award. Unused bonus expires automatically.
                    </p>
                  </div>
                </div>

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Usage Rules</h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Can be used as margin for futures trading only</li>
                    <li>The bonus amount can <strong className="text-red-400">NEVER</strong> be withdrawn</li>
                    <li>Only profits generated from trading with this bonus can be withdrawn</li>
                    <li>Losses are deducted from the locked bonus balance</li>
                    <li>When the locked bonus is depleted, no further trading with bonus is possible</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <TrendingUp className="w-5 h-5 text-[#f0b90b]" />
                3. First Deposit Match Bonus (100% up to $100)
              </h2>
              <div className="space-y-4">
                <div className="bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-lg p-4">
                  <h3 className="font-semibold text-[#f0b90b] mb-2">Eligibility</h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Available to new users making their first deposit</li>
                    <li>No minimum deposit amount required</li>
                    <li>Only the first deposit qualifies for this bonus</li>
                    <li>One-time offer per user/account</li>
                  </ul>
                </div>

                <div className="grid md:grid-cols-2 gap-4">
                  <div className="bg-slate-700/50 rounded-lg p-4">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <DollarSign className="w-4 h-4 text-[#f0b90b]" />
                      Award Calculation
                    </h3>
                    <p className="text-slate-300 text-sm">
                      100% match of your deposit amount, with a maximum bonus of $100 USD
                    </p>
                    <div className="mt-2 text-xs text-slate-400">
                      Examples: $50 deposit = $50 bonus | $150 deposit = $100 bonus (capped)
                    </div>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <Clock className="w-4 h-4 text-[#f0b90b]" />
                      Validity Period
                    </h3>
                    <p className="text-slate-300 text-sm">
                      7 days from the date of award. Unused bonus expires automatically.
                    </p>
                  </div>
                </div>

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Usage Rules</h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Can be used as margin for futures trading only</li>
                    <li>The bonus amount can <strong className="text-red-400">NEVER</strong> be withdrawn</li>
                    <li>Only profits generated from trading with this bonus can be withdrawn</li>
                    <li>Losses are deducted from the locked bonus balance</li>
                    <li>When the locked bonus is depleted, no further trading with bonus is possible</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">4. General Terms</h2>
              <div className="space-y-4 text-slate-300">
                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Multiple Bonuses</h3>
                  <p className="text-sm">
                    Users can receive both the KYC Verification Bonus and First Deposit Match Bonus
                    (up to $120 total). Each bonus is tracked and awarded separately.
                  </p>
                </div>

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Account Restrictions</h3>
                  <ul className="list-disc list-inside text-sm space-y-1">
                    <li>One account per person - multiple accounts will forfeit all bonuses</li>
                    <li>KYC verification is required for any withdrawal</li>
                    <li>Bonuses are non-transferable between accounts</li>
                  </ul>
                </div>

                <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4">
                  <h3 className="font-semibold text-red-400 mb-2 flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4" />
                    Bonus Abuse
                  </h3>
                  <p className="text-sm mb-2">
                    Shark Trades reserves the right to void bonuses and any associated profits for bonus abuse, including:
                  </p>
                  <ul className="list-disc list-inside text-sm space-y-1">
                    <li>Creating multiple accounts to claim bonuses</li>
                    <li>Hedging across accounts for risk-free arbitrage</li>
                    <li>Using third-party software to manipulate trading</li>
                    <li>Any other activity deemed as bonus abuse</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">5. Profit Calculation</h2>
              <div className="bg-slate-700/50 rounded-lg p-4 text-slate-300">
                <p className="mb-3">Profits from locked bonus trading are calculated as:</p>
                <div className="bg-slate-800 rounded p-3 font-mono text-sm text-center text-[#f0b90b]">
                  Profit = Position Close Value - Position Open Value - Trading Fees
                </div>
                <ul className="list-disc list-inside text-sm space-y-1 mt-3">
                  <li>Profits are added to your main wallet and can be withdrawn</li>
                  <li>Losses reduce the locked bonus balance directly</li>
                  <li>When locked bonus reaches zero, no further bonus trading is possible</li>
                  <li>Your deposited funds remain separate and unaffected by bonus losses</li>
                </ul>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">6. Expiration Policy</h2>
              <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4 text-slate-300">
                <ul className="list-disc list-inside text-sm space-y-2">
                  <li>The 7-day countdown begins at the moment the bonus is credited to your account</li>
                  <li>There are no automatic notifications before expiry - it is your responsibility to track</li>
                  <li>Expired bonuses are automatically removed from your account</li>
                  <li>Any open positions using bonus margin at expiry may be liquidated</li>
                  <li>Unrealized profits on positions at expiry are forfeited with the bonus</li>
                  <li>No extensions are granted under any circumstances</li>
                </ul>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">7. Modifications and Discontinuation</h2>
              <div className="text-slate-300 text-sm space-y-2">
                <p>
                  Shark Trades reserves the right to modify, suspend, or discontinue these promotional
                  bonuses at any time without prior notice.
                </p>
                <p>
                  Any changes will not affect bonuses that have already been awarded to users. The terms
                  in effect at the time of bonus award will apply for the duration of that bonus.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">8. Acceptance</h2>
              <div className="bg-slate-700/50 rounded-lg p-4 text-slate-300">
                <p className="text-sm">
                  By registering an account and participating in any promotional bonus program, you
                  acknowledge that you have read, understood, and agree to be bound by these Promotional
                  Bonus Terms and Conditions, as well as our general{' '}
                  <button
                    onClick={() => navigateTo('terms')}
                    className="text-[#f0b90b] hover:underline"
                  >
                    Terms and Conditions
                  </button>.
                </p>
              </div>
            </section>

            <div className="border-t border-slate-700 pt-6 mt-8">
              <p className="text-sm text-slate-400 mb-4">
                Last updated: December 2024
              </p>
              <div className="flex items-center gap-4">
                <button
                  onClick={() => navigateTo('signup')}
                  className="px-6 py-2 bg-gradient-to-r from-[#f0b90b] to-[#d9a506] text-black font-semibold rounded-lg hover:from-[#d9a506] hover:to-[#c49b05] transition-all"
                >
                  Create Account
                </button>
                <button
                  onClick={() => navigateTo('home')}
                  className="px-6 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 transition-colors"
                >
                  Back to Home
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
