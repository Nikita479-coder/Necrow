import { useNavigation } from '../App';
import Navbar from '../components/Navbar';
import { ArrowLeft, Gift, AlertTriangle, Clock, DollarSign, TrendingUp, Shield, Info, Users, Copy, Zap } from 'lucide-react';

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
                  <span>Version 2.0</span>
                  <span>Effective January 2025</span>
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
                Welcome to the Shark Trades promotional bonus program. These terms and conditions govern all
                promotional bonuses offered on our platform, including the Copy Trading Bonus, Referral Bonuses,
                Zero Fee Promotions, and Performance Rewards. By participating in these promotions, you agree to be bound by these terms.
              </p>
              <div className="bg-slate-700/50 rounded-lg p-4 border border-slate-600">
                <p className="text-slate-300 text-sm">
                  <strong className="text-[#f0b90b]">What is a Locked Bonus?</strong> A locked bonus is trading
                  credit that can be used for copy trading or futures trading but cannot be withdrawn directly.
                  Profits generated from trading with this bonus can be withdrawn. The bonus itself remains
                  locked until specific conditions are met or it expires.
                </p>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <Gift className="w-5 h-5 text-emerald-400" />
                2. Welcome Package Bonus (Up to $1,635)
              </h2>
              <div className="space-y-4">
                <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-lg p-4">
                  <h3 className="font-semibold text-emerald-400 mb-2">Deposit Match Bonuses</h3>
                  <p className="text-slate-300 text-sm mb-3">
                    New users can receive up to $1,635 in total bonuses including verification bonus and deposit matches!
                  </p>
                </div>

                <div className="grid md:grid-cols-3 gap-4">
                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-emerald-500">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <span className="text-[#f0b90b]">1st Deposit</span>
                    </h3>
                    <p className="text-slate-300 text-sm mb-2">
                      <strong className="text-emerald-400">100% Match</strong> up to $500
                    </p>
                    <p className="text-xs text-slate-400">Deposit $500, get $500 bonus</p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-blue-500">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <span className="text-[#f0b90b]">2nd Deposit</span>
                    </h3>
                    <p className="text-slate-300 text-sm mb-2">
                      <strong className="text-blue-400">50% Match</strong> up to $500
                    </p>
                    <p className="text-xs text-slate-400">Deposit $1,000, get $500 bonus</p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-purple-500">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <span className="text-[#f0b90b]">3rd Deposit</span>
                    </h3>
                    <p className="text-slate-300 text-sm mb-2">
                      <strong className="text-purple-400">20% Match</strong> up to $610
                    </p>
                    <p className="text-xs text-slate-400">Deposit $3,050, get $610 bonus</p>
                  </div>
                </div>

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Welcome Package Terms</h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Each deposit bonus is a locked bonus (30-day lock period)</li>
                    <li>Bonuses can be used for futures trading immediately</li>
                    <li>Profits from trading with bonus are withdrawable after lock period</li>
                    <li>Each tier can only be claimed once per account</li>
                    <li>Deposits must be made within 30 days of account creation</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <Shield className="w-5 h-5 text-emerald-400" />
                3. Verification Bonus ($25 USDT)
              </h2>
              <div className="space-y-4">
                <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-lg p-4">
                  <h3 className="font-semibold text-emerald-400 mb-2">Combined KYC + TrustPilot Bonus</h3>
                  <p className="text-slate-300 text-sm mb-3">
                    Complete BOTH identity verification AND TrustPilot review to earn a single $25 USDT locked trading bonus!
                  </p>
                  <div className="bg-[#f0b90b]/10 border-l-4 border-[#f0b90b] p-3 mt-3">
                    <p className="text-slate-300 text-sm">
                      <strong className="text-[#f0b90b]">Important:</strong> This is a single combined bonus. You must complete BOTH requirements before the bonus is awarded. No partial credit is given for completing only one requirement.
                    </p>
                  </div>
                </div>

                <div className="grid md:grid-cols-2 gap-4">
                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-emerald-500">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <span className="text-emerald-400">Requirement 1: KYC Verification</span>
                    </h3>
                    <p className="text-slate-300 text-sm mb-2">
                      Complete identity verification by submitting required documents
                    </p>
                    <p className="text-xs text-slate-400">Upload ID and proof of address for verification</p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-blue-500">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <span className="text-blue-400">Requirement 2: TrustPilot Review</span>
                    </h3>
                    <p className="text-slate-300 text-sm mb-2">
                      Leave a review on TrustPilot and submit for verification
                    </p>
                    <p className="text-xs text-slate-400">Share your experience with our platform</p>
                  </div>
                </div>

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Verification Bonus Terms</h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li><strong className="text-[#f0b90b]">$25 USDT total bonus</strong> awarded only after BOTH requirements are completed and verified</li>
                    <li>Bonus is awarded as locked trading credit after manual verification</li>
                    <li>No automatic or immediate approval - admin review required</li>
                    <li>Must complete 30 consecutive trading days to unlock the bonus</li>
                    <li>Required: 2+ trades per day, minimum 15 minutes each</li>
                    <li>Trading volume requirement: $12,500 (500x bonus amount)</li>
                    <li>Profits earned from trading are withdrawable at any time</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <Copy className="w-5 h-5 text-[#f0b90b]" />
                4. Copy Trading Bonus ($100)
              </h2>
              <div className="space-y-4">
                <div className="bg-[#f0b90b]/10 border border-[#f0b90b]/30 rounded-lg p-4">
                  <h3 className="font-semibold text-[#f0b90b] mb-2">Featured Promotion</h3>
                  <p className="text-slate-300 text-sm mb-3">
                    Allocate $500 or more to your Copy Trading wallet and receive an instant $100 bonus!
                  </p>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Minimum allocation: $500 USDT to Copy Trading wallet</li>
                    <li>Bonus amount: $100 USDT credited instantly</li>
                    <li>Lock period: 30 days from activation</li>
                    <li>One-time offer per user/account</li>
                  </ul>
                </div>

                <div className="grid md:grid-cols-2 gap-4">
                  <div className="bg-slate-700/50 rounded-lg p-4">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <DollarSign className="w-4 h-4 text-[#f0b90b]" />
                      How It Works
                    </h3>
                    <p className="text-slate-300 text-sm">
                      Transfer $500+ to your Copy Trading wallet, start copying expert traders, and your $100 bonus is added automatically.
                    </p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4">
                    <h3 className="font-semibold text-white mb-2 flex items-center gap-2">
                      <Clock className="w-4 h-4 text-[#f0b90b]" />
                      After 30 Days
                    </h3>
                    <p className="text-slate-300 text-sm">
                      Keep your funds active for 30 days. After the lock period, both your bonus AND all profits become fully withdrawable.
                    </p>
                  </div>
                </div>

                <div className="bg-emerald-900/20 border border-emerald-600/30 rounded-lg p-4">
                  <h3 className="font-semibold text-emerald-400 mb-2">Withdrawal Rules</h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Profits can be withdrawn anytime after the 30-day lock period</li>
                    <li>The $100 bonus becomes fully withdrawable after 30 days</li>
                    <li>Early withdrawal forfeits the bonus (your original funds are always safe)</li>
                    <li>Stopping copy trading before 30 days will forfeit the bonus</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <Zap className="w-5 h-5 text-green-400" />
                5. Zero Trading Fees Promotion
              </h2>
              <div className="space-y-4">
                <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4">
                  <h3 className="font-semibold text-green-400 mb-2">7 Days of Zero Fees</h3>
                  <p className="text-slate-300 text-sm mb-3">
                    Complete KYC verification and enjoy 7 days of zero trading fees on all futures trades!
                  </p>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Available after completing KYC verification</li>
                    <li>Applies to all futures trading pairs</li>
                    <li>7-day period starts immediately upon KYC approval</li>
                    <li>No minimum trade size required</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <Users className="w-5 h-5 text-blue-400" />
                6. Referral Bonuses
              </h2>
              <div className="space-y-4">
                <div className="bg-blue-500/10 border border-blue-500/30 rounded-lg p-4">
                  <h3 className="font-semibold text-blue-400 mb-2">Earn by Referring Friends</h3>
                  <p className="text-slate-300 text-sm mb-3">
                    Share your referral code and earn bonuses when your friends join and trade! Referrals must deposit $100+ to qualify.
                  </p>
                </div>

                <div className="grid md:grid-cols-2 gap-4">
                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-[#f0b90b]">
                    <h3 className="font-semibold text-white mb-2">First Referral Bonus</h3>
                    <p className="text-slate-300 text-sm">
                      <strong className="text-[#f0b90b]">$5 USDT</strong> - Instant bonus when your first referred friend deposits $100+
                    </p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-blue-400">
                    <h3 className="font-semibold text-white mb-2">5 Referrals Milestone</h3>
                    <p className="text-slate-300 text-sm">
                      <strong className="text-blue-400">$25 USDT</strong> - Bonus for inviting 5 friends who each deposit $100+
                    </p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-emerald-400">
                    <h3 className="font-semibold text-white mb-2">10 Referrals Milestone</h3>
                    <p className="text-slate-300 text-sm">
                      <strong className="text-emerald-400">$70 USDT</strong> - Bonus for inviting 10 friends who each deposit $100+
                    </p>
                  </div>

                  <div className="bg-slate-700/50 rounded-lg p-4 border-l-4 border-purple-400">
                    <h3 className="font-semibold text-white mb-2">Ongoing Commissions</h3>
                    <p className="text-slate-300 text-sm">
                      Earn a percentage of trading fees from all your referrals' trades, forever! Commission rates increase with VIP tier.
                    </p>
                  </div>
                </div>

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Referral Milestone Summary</h3>
                  <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-slate-600">
                          <th className="text-left py-2 text-slate-400">Milestone</th>
                          <th className="text-right py-2 text-slate-400">Reward</th>
                          <th className="text-right py-2 text-slate-400">Type</th>
                        </tr>
                      </thead>
                      <tbody className="text-slate-300">
                        <tr className="border-b border-slate-700">
                          <td className="py-2">1st Qualified Referral</td>
                          <td className="text-right text-[#f0b90b] font-medium">$5 USDT</td>
                          <td className="text-right text-emerald-400">Instant</td>
                        </tr>
                        <tr className="border-b border-slate-700">
                          <td className="py-2">5 Qualified Referrals</td>
                          <td className="text-right text-[#f0b90b] font-medium">$25 USDT</td>
                          <td className="text-right text-emerald-400">Instant</td>
                        </tr>
                        <tr>
                          <td className="py-2">10 Qualified Referrals</td>
                          <td className="text-right text-[#f0b90b] font-medium">$70 USDT</td>
                          <td className="text-right text-emerald-400">Instant</td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                <TrendingUp className="w-5 h-5 text-[#f0b90b]" />
                7. Performance & VIP Bonuses
              </h2>
              <div className="space-y-4">
                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Trading Volume Milestones</h3>
                  <p className="text-slate-300 text-sm mb-2">
                    Reach specific trading volume milestones to earn bonus rewards:
                  </p>
                  <ul className="list-disc list-inside text-slate-300 space-y-1 text-sm">
                    <li>Entry Level: $100 bonus for $3,000+ deposits and $1M+ monthly volume</li>
                    <li>Advanced: $800 bonus for $50,000+ deposits and $15M+ monthly volume</li>
                    <li>Institutional: $30,000 bonus for $250,000+ deposits and $150M+ monthly volume</li>
                  </ul>
                </div>

                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">VIP Tier Upgrades</h3>
                  <p className="text-slate-300 text-sm">
                    Progress through VIP tiers to unlock exclusive bonuses, reduced fees, and priority support.
                    VIP tier upgrade bonuses range from $100 to $500 depending on the tier achieved.
                  </p>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">8. General Terms</h2>
              <div className="space-y-4 text-slate-300">
                <div className="bg-slate-700/50 rounded-lg p-4">
                  <h3 className="font-semibold text-white mb-2">Account Restrictions</h3>
                  <ul className="list-disc list-inside text-sm space-y-1">
                    <li>One account per person - multiple accounts will forfeit all bonuses</li>
                    <li>KYC verification is required for any withdrawal</li>
                    <li>Bonuses are non-transferable between accounts</li>
                    <li>Bonus eligibility may vary by region</li>
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
                    <li>Withdrawing immediately after receiving bonuses without trading activity</li>
                    <li>Any other activity deemed as bonus abuse</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">9. Unlock Requirements (General)</h2>
              <div className="bg-gradient-to-r from-blue-900/30 to-blue-800/20 border border-blue-600/40 rounded-xl p-6 space-y-4">
                <div className="flex items-start gap-3">
                  <Shield className="w-6 h-6 text-blue-400 flex-shrink-0 mt-1" />
                  <div className="flex-1">
                    <h3 className="font-semibold text-blue-400 mb-3">How Locked Bonuses Work</h3>
                    <p className="text-slate-300 text-sm mb-4">
                      Some bonuses are "locked" meaning they can be used for trading but not withdrawn directly.
                      Each bonus type has specific unlock conditions:
                    </p>
                  </div>
                </div>

                <div className="space-y-3 ml-9">
                  <div className="bg-slate-800/50 rounded-lg p-4 border border-blue-500/20">
                    <div className="flex items-center gap-2 mb-2">
                      <Clock className="w-5 h-5 text-[#f0b90b]" />
                      <h4 className="font-semibold text-white">Time-Based Unlock</h4>
                    </div>
                    <p className="text-slate-300 text-sm">
                      Some bonuses unlock automatically after a specified period (e.g., 30 days for Copy Trading Bonus).
                      Keep your funds active during this period to retain the bonus.
                    </p>
                  </div>

                  <div className="bg-slate-800/50 rounded-lg p-4 border border-blue-500/20">
                    <div className="flex items-center gap-2 mb-2">
                      <TrendingUp className="w-5 h-5 text-[#f0b90b]" />
                      <h4 className="font-semibold text-white">Activity-Based Unlock</h4>
                    </div>
                    <p className="text-slate-300 text-sm">
                      Some bonuses require meeting trading volume or activity requirements.
                      Progress is tracked automatically in your wallet dashboard.
                    </p>
                  </div>
                </div>

                <div className="bg-emerald-900/20 border border-emerald-600/30 rounded-lg p-4 ml-9">
                  <h4 className="font-semibold text-emerald-400 mb-2">Once Unlocked</h4>
                  <ul className="list-disc list-inside text-slate-300 text-sm space-y-1">
                    <li>The bonus amount becomes fully withdrawable</li>
                    <li>You'll receive an instant notification</li>
                    <li>You can withdraw or continue trading with the unlocked amount</li>
                  </ul>
                </div>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">10. Profit Calculation</h2>
              <div className="bg-slate-700/50 rounded-lg p-4 text-slate-300">
                <p className="mb-3">Profits from bonus trading are calculated as:</p>
                <div className="bg-slate-800 rounded p-3 font-mono text-sm text-center text-[#f0b90b]">
                  Profit = Position Close Value - Position Open Value - Trading Fees
                </div>
                <ul className="list-disc list-inside text-sm space-y-1 mt-3">
                  <li>Profits are yours to keep and can be withdrawn (subject to lock periods)</li>
                  <li>Losses reduce your bonus balance directly</li>
                  <li>When bonus reaches zero, no further bonus trading is possible</li>
                  <li>Your deposited funds remain separate and unaffected by bonus losses</li>
                </ul>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">11. Expiration Policy</h2>
              <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4 text-slate-300">
                <ul className="list-disc list-inside text-sm space-y-2">
                  <li>Each bonus has a specific validity period (7-30 days depending on type)</li>
                  <li>Countdown begins at the moment the bonus is credited to your account</li>
                  <li>Expired bonuses are automatically removed from your account</li>
                  <li>Any open positions using bonus margin at expiry may be liquidated</li>
                  <li>Unrealized profits on positions at expiry are forfeited with the bonus</li>
                  <li>No extensions are granted under any circumstances</li>
                </ul>
              </div>
            </section>

            <section>
              <h2 className="text-xl font-bold text-white mb-4">12. Modifications and Discontinuation</h2>
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
              <h2 className="text-xl font-bold text-white mb-4">13. Acceptance</h2>
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
                Last updated: January 2025
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
