import { useState, useEffect } from 'react';
import { AlertTriangle, Shield, Flag, Activity, RefreshCw, BookOpen, Info } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import RiskManagementDocs from './RiskManagementDocs';

interface RiskScore {
  overall_score: number;
  trading_score: number;
  kyc_score: number;
  behavior_score: number;
  risk_level: string;
  last_calculated_at: string;
  factors: any;
}

interface RiskAlert {
  id: string;
  alert_type: string;
  severity: string;
  description: string;
  status: string;
  triggered_at: string;
}

interface RiskFlag {
  id: string;
  flag_type: string;
  reason: string;
  is_active: boolean;
  created_at: string;
  expires_at: string | null;
}

interface Props {
  userId: string;
}

export default function AdminUserRisk({ userId }: Props) {
  const [riskScore, setRiskScore] = useState<RiskScore | null>(null);
  const [alerts, setAlerts] = useState<RiskAlert[]>([]);
  const [flags, setFlags] = useState<RiskFlag[]>([]);
  const [loading, setLoading] = useState(true);
  const [recalculating, setRecalculating] = useState(false);
  const [showDocs, setShowDocs] = useState(false);

  useEffect(() => {
    loadRiskData();
  }, [userId]);

  const loadRiskData = async () => {
    try {
      const [scoreRes, alertsRes, flagsRes] = await Promise.all([
        supabase.from('risk_scores').select('*').eq('user_id', userId).single(),
        supabase.from('risk_alerts').select('*').eq('user_id', userId).order('triggered_at', { ascending: false }).limit(10),
        supabase.from('user_risk_flags').select('*').eq('user_id', userId).eq('is_active', true),
      ]);

      if (scoreRes.data) setRiskScore(scoreRes.data);
      if (alertsRes.data) setAlerts(alertsRes.data);
      if (flagsRes.data) setFlags(flagsRes.data);
    } catch (error) {
      console.error('Error loading risk data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRecalculate = async () => {
    setRecalculating(true);
    try {
      const { error } = await supabase.rpc('update_user_risk_score', { p_user_id: userId });
      if (error) throw error;

      await supabase.rpc('check_and_generate_risk_alerts', { p_user_id: userId });

      await loadRiskData();
    } catch (error) {
      console.error('Error recalculating risk score:', error);
      alert('Failed to recalculate risk score');
    } finally {
      setRecalculating(false);
    }
  };

  const getRiskLevelColor = (level: string) => {
    switch (level) {
      case 'low':
        return 'text-green-500';
      case 'medium':
        return 'text-yellow-500';
      case 'high':
        return 'text-orange-500';
      case 'critical':
        return 'text-red-500';
      default:
        return 'text-gray-500';
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'low':
        return 'bg-blue-500/10 text-blue-500';
      case 'medium':
        return 'bg-yellow-500/10 text-yellow-500';
      case 'high':
        return 'bg-orange-500/10 text-orange-500';
      case 'critical':
        return 'bg-red-500/10 text-red-500';
      default:
        return 'bg-gray-500/10 text-gray-500';
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-white">Risk Management</h2>
          <p className="text-sm text-gray-400 mt-1">Automated risk scoring and monitoring</p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={() => setShowDocs(!showDocs)}
            className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors flex items-center gap-2"
          >
            <BookOpen className="w-4 h-4" />
            {showDocs ? 'Hide' : 'Show'} Documentation
          </button>
          <button
            onClick={handleRecalculate}
            disabled={recalculating}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <RefreshCw className={`w-4 h-4 ${recalculating ? 'animate-spin' : ''}`} />
            Recalculate Score
          </button>
        </div>
      </div>

      {showDocs && <RiskManagementDocs />}

      {riskScore && (
        <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold text-white flex items-center gap-2">
              <Shield className="w-5 h-5" />
              Risk Score Overview
            </h3>
            <span className={`text-2xl font-bold ${getRiskLevelColor(riskScore.risk_level)}`}>
              {riskScore.risk_level.toUpperCase()}
            </span>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="text-sm text-gray-400 mb-1">Overall</div>
              <div className="text-2xl font-bold text-white">{riskScore.overall_score.toFixed(1)}</div>
              <div className="text-xs text-gray-500 mt-1">/ 100 points</div>
            </div>
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="text-sm text-gray-400 mb-1">Trading</div>
              <div className="text-2xl font-bold text-white">{riskScore.trading_score.toFixed(1)}</div>
              <div className="text-xs text-gray-500 mt-1">/ 30 points</div>
            </div>
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="text-sm text-gray-400 mb-1">KYC</div>
              <div className="text-2xl font-bold text-white">{riskScore.kyc_score.toFixed(1)}</div>
              <div className="text-xs text-gray-500 mt-1">/ 30 points</div>
            </div>
            <div className="bg-gray-900/50 rounded-lg p-4">
              <div className="text-sm text-gray-400 mb-1">Behavior</div>
              <div className="text-2xl font-bold text-white">{riskScore.behavior_score.toFixed(1)}</div>
              <div className="text-xs text-gray-500 mt-1">/ 25 points</div>
            </div>
          </div>

          {riskScore.factors?.calculation_details && (
            <div className="border-t border-gray-700 pt-4 mt-4">
              <h4 className="text-sm font-semibold text-white mb-3 flex items-center gap-2">
                <Info className="w-4 h-4" />
                Risk Factors
              </h4>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-3 text-sm">
                <div className="bg-gray-900/30 rounded p-3">
                  <div className="text-gray-400">KYC Status</div>
                  <div className="text-white font-medium capitalize">
                    {riskScore.factors.calculation_details.kyc_status}
                  </div>
                </div>
                <div className="bg-gray-900/30 rounded p-3">
                  <div className="text-gray-400">Account Age</div>
                  <div className="text-white font-medium">
                    {riskScore.factors.calculation_details.account_age_days} days
                  </div>
                </div>
                <div className="bg-gray-900/30 rounded p-3">
                  <div className="text-gray-400">Recent Liquidations</div>
                  <div className="text-white font-medium">
                    {riskScore.factors.calculation_details.recent_liquidations}
                  </div>
                </div>
                <div className="bg-gray-900/30 rounded p-3">
                  <div className="text-gray-400">High Leverage Positions</div>
                  <div className="text-white font-medium">
                    {riskScore.factors.calculation_details.high_leverage_positions}
                  </div>
                </div>
                <div className="bg-gray-900/30 rounded p-3">
                  <div className="text-gray-400">Failed Logins (7d)</div>
                  <div className="text-white font-medium">
                    {riskScore.factors.calculation_details.failed_logins_7d}
                  </div>
                </div>
                <div className="bg-gray-900/30 rounded p-3">
                  <div className="text-gray-400">Devices (30d)</div>
                  <div className="text-white font-medium">
                    {riskScore.factors.calculation_details.device_count_30d}
                  </div>
                </div>
              </div>
            </div>
          )}

          <div className="text-sm text-gray-400 mt-4">
            Last calculated: {new Date(riskScore.last_calculated_at).toLocaleString()}
          </div>
        </div>
      )}

      {flags.length > 0 && (
        <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
          <h3 className="text-lg font-semibold text-white flex items-center gap-2 mb-4">
            <Flag className="w-5 h-5" />
            Active Flags ({flags.length})
          </h3>
          <div className="space-y-3">
            {flags.map((flag) => (
              <div key={flag.id} className="bg-gray-900/50 rounded-lg p-4">
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <h4 className="font-medium text-white capitalize">
                      {flag.flag_type.replace('_', ' ')}
                    </h4>
                    <p className="text-sm text-gray-400 mt-1">{flag.reason}</p>
                  </div>
                  {flag.expires_at && (
                    <span className="text-xs text-gray-500">
                      Expires: {new Date(flag.expires_at).toLocaleDateString()}
                    </span>
                  )}
                </div>
                <div className="text-xs text-gray-500">
                  Created: {new Date(flag.created_at).toLocaleString()}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-6">
        <h3 className="text-lg font-semibold text-white flex items-center gap-2 mb-4">
          <AlertTriangle className="w-5 h-5" />
          Recent Alerts ({alerts.length})
        </h3>
        {alerts.length === 0 ? (
          <p className="text-gray-400 text-center py-8">No alerts found</p>
        ) : (
          <div className="space-y-3">
            {alerts.map((alert) => (
              <div key={alert.id} className="bg-gray-900/50 rounded-lg p-4">
                <div className="flex items-start justify-between mb-2">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <span className={`px-2 py-0.5 rounded text-xs font-medium ${getSeverityColor(alert.severity)}`}>
                        {alert.severity}
                      </span>
                      <span className="text-xs text-gray-500 capitalize">
                        {alert.alert_type.replace('_', ' ')}
                      </span>
                    </div>
                    <p className="text-sm text-white">{alert.description}</p>
                  </div>
                  <span className={`px-2 py-0.5 rounded text-xs font-medium ${
                    alert.status === 'active' ? 'bg-red-500/10 text-red-500' :
                    alert.status === 'investigating' ? 'bg-yellow-500/10 text-yellow-500' :
                    'bg-green-500/10 text-green-500'
                  }`}>
                    {alert.status}
                  </span>
                </div>
                <div className="text-xs text-gray-500">
                  {new Date(alert.triggered_at).toLocaleString()}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
