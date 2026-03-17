import { Shield, Lock, AlertTriangle, Mail, MessageCircle, Globe, Clock } from 'lucide-react';
import { useNavigation } from '../App';

function Footer() {
  const { navigateTo } = useNavigation();

  return (
    <footer className="bg-[#0b0e11] border-t border-gray-800">
      <div className="bg-gradient-to-r from-amber-900/20 to-orange-900/20 border-b border-amber-500/20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
            <div>
              <p className="text-amber-200/90 text-sm font-medium mb-1">Important Risk Warning</p>
              <p className="text-amber-200/60 text-xs leading-relaxed">
                Trading cryptocurrencies and derivatives involves substantial risk of loss and is not suitable for every investor.
                The high degree of leverage can work against you as well as for you. Before deciding to trade, you should carefully
                consider your investment objectives, level of experience, and risk appetite. The possibility exists that you could
                sustain a loss of some or all of your initial investment. You should be aware of all the risks associated with
                cryptocurrency trading and seek advice from an independent financial advisor if you have any doubts.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-8 mb-8">
          <div className="col-span-2">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-8 h-8 bg-[#f0b90b] rounded-lg flex items-center justify-center">
                <span className="text-black font-bold text-lg">S</span>
              </div>
              <span className="text-white font-bold text-xl">Shark Trades</span>
            </div>
            <p className="text-gray-500 text-sm mb-4">
              A leading cryptocurrency trading platform providing secure, fast, and reliable trading services for digital assets worldwide.
            </p>

            <div className="flex flex-wrap gap-3 mb-4">
              <div className="flex items-center gap-1.5 bg-emerald-500/10 border border-emerald-500/20 rounded-lg px-3 py-1.5">
                <Shield className="w-3.5 h-3.5 text-emerald-400" />
                <span className="text-emerald-400 text-xs font-medium">SSL Secured</span>
              </div>
              <div className="flex items-center gap-1.5 bg-blue-500/10 border border-blue-500/20 rounded-lg px-3 py-1.5">
                <Lock className="w-3.5 h-3.5 text-blue-400" />
                <span className="text-blue-400 text-xs font-medium">2FA Protected</span>
              </div>
            </div>

            <div className="text-gray-500 text-xs space-y-1">
              <div className="flex items-center gap-2">
                <Mail className="w-3.5 h-3.5" />
                <span>support@sharktrades.com</span>
              </div>
              <div className="flex items-center gap-2">
                <Clock className="w-3.5 h-3.5" />
                <span>24/7 Customer Support</span>
              </div>
            </div>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-4">Products</h4>
            <ul className="space-y-2">
              <li><button onClick={() => navigateTo('futures')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Futures Trading</button></li>
              <li><button onClick={() => navigateTo('swap')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Spot/Swap</button></li>
              <li><button onClick={() => navigateTo('copytrading')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Copy Trading</button></li>
              <li><button onClick={() => navigateTo('earn')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Earn</button></li>
              <li><button onClick={() => navigateTo('markets')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Markets</button></li>
            </ul>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-4">Programs</h4>
            <ul className="space-y-2">
              <li><button onClick={() => navigateTo('referral')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Referral</button></li>
              <li><button onClick={() => navigateTo('affiliate')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Affiliate</button></li>
              <li><button onClick={() => navigateTo('vip')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">VIP Program</button></li>
              <li><button onClick={() => navigateTo('rewardshub')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Rewards Hub</button></li>
              <li><button onClick={() => navigateTo('giveaway')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Giveaways</button></li>
            </ul>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-4">Support</h4>
            <ul className="space-y-2">
              <li><button onClick={() => navigateTo('support')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Help Center</button></li>
              <li><button onClick={() => navigateTo('kyc')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Verification (KYC)</button></li>
              <li><button onClick={() => navigateTo('deposit')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Deposit Funds</button></li>
              <li><button onClick={() => navigateTo('withdraw')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Withdraw Funds</button></li>
            </ul>
          </div>

          <div>
            <h4 className="text-white font-semibold mb-4">Legal</h4>
            <ul className="space-y-2">
              <li><button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Legal Center</button></li>
              <li><button onClick={() => navigateTo('terms')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Terms of Service</button></li>
              <li><button onClick={() => navigateTo('privacy')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Privacy Policy</button></li>
              <li><button onClick={() => navigateTo('bonusterms')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Bonus Terms</button></li>
              <li><button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">Risk Disclosure</button></li>
              <li><button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] text-sm transition-colors">AML/KYC Policy</button></li>
            </ul>
          </div>
        </div>

        <div className="border-t border-gray-800 pt-6 mb-6">
          <div className="bg-[#181a20] rounded-xl p-4 border border-gray-800">
            <div className="flex items-start gap-3">
              <Globe className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />
              <div>
                <p className="text-gray-300 text-sm font-medium mb-2">Regional Restrictions</p>
                <p className="text-gray-500 text-xs leading-relaxed">
                  Our services are not available to residents of the following jurisdictions: United States of America,
                  Cuba, Iran, North Korea, Syria, Crimea region, and other sanctioned territories. Users from restricted
                  regions are prohibited from accessing our platform. By using our services, you confirm that you are not
                  a resident of any restricted jurisdiction.
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="border-t border-gray-800 pt-6">
          <div className="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4 mb-4">
            <div className="flex flex-wrap gap-4 text-xs">
              <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">Privacy Policy</button>
              <span className="text-gray-700">|</span>
              <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">Cookie Policy</button>
              <span className="text-gray-700">|</span>
              <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">Risk Disclosure</button>
              <span className="text-gray-700">|</span>
              <button onClick={() => navigateTo('legal')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">AML/KYC Policy</button>
              <span className="text-gray-700">|</span>
              <button onClick={() => navigateTo('terms')} className="text-gray-400 hover:text-[#f0b90b] transition-colors">Terms of Service</button>
            </div>

            <div className="flex items-center gap-4">
              <a
                href="https://t.me/SharkTradesOfficial"
                target="_blank"
                rel="noopener noreferrer"
                className="text-gray-400 hover:text-[#0088cc] transition-colors"
                aria-label="Telegram"
              >
                <MessageCircle className="w-5 h-5" />
              </a>
            </div>
          </div>

          <div className="text-center lg:text-left">
            <p className="text-gray-500 text-xs mb-2">
              2024-2025 Shark Trades. All rights reserved.
            </p>
            <p className="text-gray-600 text-[10px] leading-relaxed max-w-4xl">
              Cryptocurrency trading carries a high level of risk, and may not be suitable for all investors. Before deciding
              to trade cryptocurrency you should carefully consider your investment objectives, level of experience, and risk
              appetite. Shark Trades is not a financial advisor, and this website does not provide financial advice. All trading
              decisions are made at your own risk and discretion. Trading in financial instruments and/or cryptocurrencies
              involves high risks including the risk of losing some, or all, of your investment amount.
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}

export default Footer;
