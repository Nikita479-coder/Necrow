import { BookOpen, Shield, AlertTriangle, TrendingUp, Activity, Clock } from 'lucide-react';

export default function RiskManagementDocs() {
  return (
    <div className="space-y-6">
      <div className="bg-gradient-to-r from-blue-600/20 to-purple-600/20 border border-blue-500/30 rounded-lg p-6">
        <div className="flex items-center gap-3 mb-4">
          <BookOpen className="w-6 h-6 text-blue-400" />
          <h2 className="text-2xl font-bold text-white">Risk Management System Documentation</h2>
        </div>
        <p className="text-gray-300">
          Comprehensive automated risk scoring and monitoring system for user behavior analysis
        </p>
      </div>

      <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
          <Shield className="w-5 h-5" />
          Overview
        </h3>
        <p className="text-gray-300 leading-relaxed mb-4">
          The risk management system automatically calculates a comprehensive risk score for each user based on multiple factors.
          Scores range from 0-100, with higher scores indicating higher risk levels. The system runs automatically on every
          significant user action and generates alerts when thresholds are exceeded.
        </p>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
          <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4 text-center">
            <div className="text-2xl font-bold text-green-500">0-30</div>
            <div className="text-sm text-gray-400 mt-1">Low Risk</div>
          </div>
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 text-center">
            <div className="text-2xl font-bold text-yellow-500">31-50</div>
            <div className="text-sm text-gray-400 mt-1">Medium Risk</div>
          </div>
          <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4 text-center">
            <div className="text-2xl font-bold text-orange-500">51-70</div>
            <div className="text-sm text-gray-400 mt-1">High Risk</div>
          </div>
          <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4 text-center">
            <div className="text-2xl font-bold text-red-500">71-100</div>
            <div className="text-sm text-gray-400 mt-1">Critical Risk</div>
          </div>
        </div>
      </div>

      <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Risk Score Components</h3>
        <div className="space-y-4">
          <div className="bg-gray-900/50 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <h4 className="font-semibold text-white flex items-center gap-2">
                <Shield className="w-4 h-4 text-blue-400" />
                KYC Score (0-30 points)
              </h4>
              <span className="text-sm text-gray-400">Max 30 points</span>
            </div>
            <p className="text-gray-300 text-sm mb-3">
              Assesses identity verification status and documentation completeness
            </p>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Not Verified</span>
                <span className="text-red-400 font-medium">+30 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Pending Verification</span>
                <span className="text-yellow-400 font-medium">+15 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Fully Verified</span>
                <span className="text-green-400 font-medium">0 points</span>
              </div>
            </div>
          </div>

          <div className="bg-gray-900/50 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <h4 className="font-semibold text-white flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-blue-400" />
                Trading Score (0-30 points)
              </h4>
              <span className="text-sm text-gray-400">Max 30 points</span>
            </div>
            <p className="text-gray-300 text-sm mb-3">
              Analyzes trading patterns, leverage usage, and position management
            </p>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between items-center">
                <span className="text-gray-400">High Leverage Usage (&gt;50x, &gt;5 positions)</span>
                <span className="text-red-400 font-medium">+10 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Frequent Liquidations (&gt;3 in 30 days)</span>
                <span className="text-red-400 font-medium">+10 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Large Position Sizes (&gt;50% of balance)</span>
                <span className="text-orange-400 font-medium">+5 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">High PnL Volatility</span>
                <span className="text-yellow-400 font-medium">+5 points</span>
              </div>
            </div>
          </div>

          <div className="bg-gray-900/50 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <h4 className="font-semibold text-white flex items-center gap-2">
                <Activity className="w-4 h-4 text-blue-400" />
                Behavior Score (0-25 points)
              </h4>
              <span className="text-sm text-gray-400">Max 25 points</span>
            </div>
            <p className="text-gray-300 text-sm mb-3">
              Monitors account security and suspicious activity patterns
            </p>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Multiple Failed Logins (&gt;10 in 7 days)</span>
                <span className="text-red-400 font-medium">+10 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Many Devices (&gt;5 in 30 days)</span>
                <span className="text-orange-400 font-medium">+5 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Frequent IP Changes (&gt;10 in 7 days)</span>
                <span className="text-orange-400 font-medium">+5 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">High Transaction Velocity (&gt;50 in 1 hour)</span>
                <span className="text-yellow-400 font-medium">+5 points</span>
              </div>
            </div>
          </div>

          <div className="bg-gray-900/50 rounded-lg p-4">
            <div className="flex items-center justify-between mb-2">
              <h4 className="font-semibold text-white flex items-center gap-2">
                <Clock className="w-4 h-4 text-blue-400" />
                Account Age Score (0-15 points)
              </h4>
              <span className="text-sm text-gray-400">Max 15 points</span>
            </div>
            <p className="text-gray-300 text-sm mb-3">
              Newer accounts carry higher risk until trust is established
            </p>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Less than 7 days old</span>
                <span className="text-red-400 font-medium">+15 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Less than 30 days old</span>
                <span className="text-orange-400 font-medium">+10 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Less than 90 days old</span>
                <span className="text-yellow-400 font-medium">+5 points</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-400">Over 90 days old</span>
                <span className="text-green-400 font-medium">0 points</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
          <AlertTriangle className="w-5 h-5" />
          Automated Alerts
        </h3>
        <p className="text-gray-300 text-sm mb-4">
          The system automatically generates alerts when risk thresholds are exceeded:
        </p>
        <div className="space-y-3">
          <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4">
            <div className="font-medium text-red-400 mb-1">Critical Risk Level Alert</div>
            <p className="text-sm text-gray-300">Triggered when overall score reaches 71+ points</p>
          </div>
          <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4">
            <div className="font-medium text-orange-400 mb-1">High Leverage Warning</div>
            <p className="text-sm text-gray-300">Triggered when user opens &gt;5 positions with &gt;50x leverage in 30 days</p>
          </div>
          <div className="bg-orange-500/10 border border-orange-500/30 rounded-lg p-4">
            <div className="font-medium text-orange-400 mb-1">Frequent Liquidations</div>
            <p className="text-sm text-gray-300">Triggered when user is liquidated &gt;3 times in 30 days</p>
          </div>
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4">
            <div className="font-medium text-yellow-400 mb-1">Suspicious Login Activity</div>
            <p className="text-sm text-gray-300">Triggered when &gt;10 failed login attempts in 7 days</p>
          </div>
        </div>
      </div>

      <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Automatic Updates</h3>
        <p className="text-gray-300 text-sm mb-4">
          Risk scores are automatically recalculated when:
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div className="bg-gray-900/50 rounded-lg p-3 text-sm">
            <div className="text-white font-medium mb-1">Trading Actions</div>
            <div className="text-gray-400">Position opened, closed, or liquidated</div>
          </div>
          <div className="bg-gray-900/50 rounded-lg p-3 text-sm">
            <div className="text-white font-medium mb-1">KYC Changes</div>
            <div className="text-gray-400">Verification status updated</div>
          </div>
          <div className="bg-gray-900/50 rounded-lg p-3 text-sm">
            <div className="text-white font-medium mb-1">Security Events</div>
            <div className="text-gray-400">Failed logins, suspicious IPs detected</div>
          </div>
          <div className="bg-gray-900/50 rounded-lg p-3 text-sm">
            <div className="text-white font-medium mb-1">Large Withdrawals</div>
            <div className="text-gray-400">Withdrawal &gt;$10k or &gt;50% of balance</div>
          </div>
        </div>
      </div>

      <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
        <h3 className="text-xl font-semibold text-white mb-4">Withdrawal Approval System</h3>
        <p className="text-gray-300 text-sm mb-4">
          High-risk withdrawals are automatically flagged for manual approval:
        </p>
        <ul className="space-y-2 text-sm text-gray-300">
          <li className="flex items-start gap-2">
            <span className="text-blue-400 mt-1">•</span>
            <span>Withdrawals over $10,000</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-blue-400 mt-1">•</span>
            <span>Withdrawals exceeding 50% of total balance</span>
          </li>
          <li className="flex items-start gap-2">
            <span className="text-blue-400 mt-1">•</span>
            <span>Any withdrawal from high or critical risk users over $1,000</span>
          </li>
        </ul>
      </div>
    </div>
  );
}
