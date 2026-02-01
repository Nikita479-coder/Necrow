import { useState, useEffect } from 'react';
import { Gift, Plus, Clock, CheckCircle, XCircle, Ban, Lock, Unlock, Calendar, AlertTriangle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';
import { useAuth } from '../../context/AuthContext';

interface Props {
  userId: string;
  userData: any;
  onRefresh: () => void;
}

interface BonusType {
  id: string;
  name: string;
  description: string;
  default_amount: number;
  category: string;
  expiry_days: number | null;
  is_locked_bonus: boolean;
}

interface UserBonus {
  id: string;
  bonus_type_name: string;
  amount: number;
  status: string;
  awarded_at: string;
  claimed_at: string | null;
  expires_at: string | null;
  awarded_by_username: string;
  notes: string | null;
}

interface LockedBonus {
  id: string;
  original_amount: number;
  current_amount: number;
  realized_profits: number;
  bonus_type_name: string;
  status: string;
  expires_at: string;
  days_remaining: number;
  created_at: string;
  bonus_trading_volume_completed: number;
  bonus_trading_volume_required: number;
  consecutive_trading_days_required: number | null;
  current_consecutive_days: number;
  daily_trades_required: number | null;
  daily_trade_duration_minutes: number | null;
  daily_trade_count_today: number;
  last_qualifying_trade_date: string | null;
}

export default function AdminBonusManager({ userId, userData, onRefresh }: Props) {
  const { user: adminUser } = useAuth();
  const { showToast } = useToast();
  const [bonusTypes, setBonusTypes] = useState<BonusType[]>([]);
  const [userBonuses, setUserBonuses] = useState<UserBonus[]>([]);
  const [lockedBonuses, setLockedBonuses] = useState<LockedBonus[]>([]);
  const [loading, setLoading] = useState(false);
  const [showAwardModal, setShowAwardModal] = useState(false);

  const [formData, setFormData] = useState({
    bonus_type_id: '',
    amount: '',
    expiry_days: '7',
    notes: '',
    is_locked: false,
  });

  useEffect(() => {
    loadBonusTypes();
    loadUserBonuses();
    loadLockedBonuses();
  }, [userId]);

  const loadBonusTypes = async () => {
    try {
      const { data, error } = await supabase
        .from('bonus_types')
        .select('*')
        .eq('is_active', true)
        .order('name');

      if (error) throw error;
      setBonusTypes(data || []);
    } catch (error: any) {
      showToast('Failed to load bonus types: ' + error.message, 'error');
    }
  };

  const loadUserBonuses = async () => {
    try {
      const { data, error } = await supabase.rpc('get_user_bonus_history', {
        p_user_id: userId,
        p_limit: 20,
        p_offset: 0
      });

      if (error) throw error;
      setUserBonuses(data || []);
    } catch (error: any) {
      console.error('Failed to load user bonuses:', error);
    }
  };

  const loadLockedBonuses = async () => {
    try {
      const { data, error } = await supabase.rpc('get_user_locked_bonuses', {
        p_user_id: userId
      });

      if (error) throw error;
      setLockedBonuses(data || []);
    } catch (error: any) {
      console.error('Failed to load locked bonuses:', error);
    }
  };

  const handleBonusTypeChange = (bonusTypeId: string) => {
    const bonusType = bonusTypes.find(bt => bt.id === bonusTypeId);
    if (bonusType) {
      setFormData({
        ...formData,
        bonus_type_id: bonusTypeId,
        amount: bonusType.default_amount.toString(),
        expiry_days: bonusType.expiry_days?.toString() || '7',
        is_locked: bonusType.is_locked_bonus,
      });
    }
  };

  const handleAwardBonus = async () => {
    if (!formData.bonus_type_id || !formData.amount) {
      showToast('Please select a bonus type and amount', 'error');
      return;
    }

    if (!adminUser?.id) {
      showToast('Admin session expired. Please refresh the page.', 'error');
      return;
    }

    const amount = parseFloat(formData.amount);
    if (isNaN(amount) || amount <= 0) {
      showToast('Bonus amount must be greater than 0', 'error');
      return;
    }

    if (formData.is_locked && (!formData.expiry_days || parseInt(formData.expiry_days) < 1)) {
      showToast('Locked bonus requires expiry days (minimum 1 day)', 'error');
      return;
    }

    setLoading(true);
    try {
      let data, error;

      if (formData.is_locked) {
        console.log('Awarding locked bonus:', { userId, amount, bonus_type_id: formData.bonus_type_id });
        const result = await supabase.rpc('award_locked_bonus', {
          p_user_id: userId,
          p_bonus_type_id: formData.bonus_type_id,
          p_amount: amount,
          p_awarded_by: adminUser.id,
          p_notes: formData.notes || null,
          p_expiry_days: parseInt(formData.expiry_days) || 7
        });
        console.log('Locked bonus result:', result);
        data = result.data;
        error = result.error;
      } else {
        console.log('Awarding regular bonus:', { userId, amount, bonus_type_id: formData.bonus_type_id });
        const result = await supabase.rpc('award_user_bonus', {
          p_user_id: userId,
          p_bonus_type_id: formData.bonus_type_id,
          p_amount: amount,
          p_awarded_by: adminUser.id,
          p_notes: formData.notes || null,
          p_expiry_days: formData.expiry_days ? parseInt(formData.expiry_days) : null
        });
        console.log('Regular bonus result:', result);
        data = result.data;
        error = result.error;
      }

      if (error) {
        console.error('Bonus award error:', error);
        throw error;
      }

      if (!data?.success) {
        throw new Error(data?.error || 'Failed to award bonus');
      }

      showToast(data.message || 'Bonus awarded successfully!', 'success');
      setShowAwardModal(false);
      setFormData({
        bonus_type_id: '',
        amount: '',
        expiry_days: '7',
        notes: '',
        is_locked: false,
      });
      await loadUserBonuses();
      await loadLockedBonuses();
      onRefresh();
    } catch (error: any) {
      console.error('Award bonus failed:', error);
      showToast('Failed to award bonus: ' + (error.message || 'Unknown error'), 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleCancelBonus = async (bonusId: string) => {
    const reason = prompt('Enter cancellation reason (optional):');
    if (reason === null) return;

    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('cancel_user_bonus', {
        p_bonus_id: bonusId,
        p_cancelled_by: adminUser!.id,
        p_reason: reason || null
      });

      if (error) throw error;

      if (!data.success) {
        throw new Error(data.error || 'Failed to cancel bonus');
      }

      showToast('Bonus cancelled successfully', 'success');
      await loadUserBonuses();
      onRefresh();
    } catch (error: any) {
      showToast('Failed to cancel bonus: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'claimed': return 'bg-green-500/10 text-green-400 border-green-500/30';
      case 'active': return 'bg-blue-500/10 text-blue-400 border-blue-500/30';
      case 'pending': return 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30';
      case 'expired': return 'bg-gray-500/10 text-gray-400 border-gray-500/30';
      case 'cancelled': return 'bg-red-500/10 text-red-400 border-red-500/30';
      case 'depleted': return 'bg-orange-500/10 text-orange-400 border-orange-500/30';
      default: return 'bg-gray-500/10 text-gray-400 border-gray-500/30';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'claimed': return <CheckCircle className="w-4 h-4" />;
      case 'active': return <Gift className="w-4 h-4" />;
      case 'expired': return <Clock className="w-4 h-4" />;
      case 'cancelled': return <Ban className="w-4 h-4" />;
      case 'depleted': return <XCircle className="w-4 h-4" />;
      default: return <Gift className="w-4 h-4" />;
    }
  };

  const activeLockedBonusTotal = lockedBonuses
    .filter(b => b.status === 'active')
    .reduce((sum, b) => sum + b.current_amount, 0);

  return (
    <div className="space-y-6">
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold text-white">Award Bonus</h2>
          <button
            onClick={() => setShowAwardModal(true)}
            disabled={loading}
            className="flex items-center gap-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black px-6 py-3 rounded-lg font-bold transition-all disabled:opacity-50"
          >
            <Plus className="w-5 h-5" />
            Award Bonus
          </button>
        </div>

        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
          <p className="text-gray-400 text-sm mb-4">
            Award bonuses to users. Regular bonuses are credited to wallet. Locked bonuses can only be used for trading - profits are withdrawable but the bonus itself expires after the set period.
          </p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <p className="text-xs text-gray-500 mb-1">Available Bonus Types</p>
              <p className="text-white font-bold text-xl">{bonusTypes.length}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500 mb-1">Total Bonuses Awarded</p>
              <p className="text-white font-bold text-xl">{userBonuses.length}</p>
            </div>
            <div>
              <p className="text-xs text-gray-500 mb-1">Total Bonus Value</p>
              <p className="text-green-400 font-bold text-xl">
                ${userBonuses.reduce((sum, b) => sum + parseFloat(b.amount.toString()), 0).toFixed(2)}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500 mb-1">Active Locked Bonus</p>
              <p className="text-[#f0b90b] font-bold text-xl">
                ${activeLockedBonusTotal.toFixed(2)}
              </p>
            </div>
          </div>
        </div>
      </div>

      {lockedBonuses.length > 0 && (
        <div>
          <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
            <Lock className="w-5 h-5 text-[#f0b90b]" />
            Locked Bonuses
          </h2>
          <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
            <div className="divide-y divide-gray-800">
              {lockedBonuses.map((bonus) => (
                <div key={bonus.id} className="p-4 hover:bg-[#1a1d24] transition-colors">
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-2">
                        <Lock className="w-5 h-5 text-[#f0b90b]" />
                        <h3 className="text-white font-bold">{bonus.bonus_type_name}</h3>
                        <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-lg border text-xs font-medium ${getStatusColor(bonus.status)}`}>
                          {getStatusIcon(bonus.status)}
                          {bonus.status.toUpperCase()}
                        </span>
                      </div>
                      <div className="flex items-center gap-4 flex-wrap">
                        <div>
                          <p className="text-xs text-gray-500">Current Balance</p>
                          <p className="text-xl font-bold text-[#f0b90b]">
                            ${bonus.current_amount.toFixed(2)}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Original</p>
                          <p className="text-lg font-medium text-gray-400">
                            ${bonus.original_amount.toFixed(2)}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Profits</p>
                          <p className="text-lg font-medium text-green-400">
                            +${(bonus.realized_profits || 0).toFixed(2)}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Losses</p>
                          <p className="text-lg font-medium text-red-400">
                            -${Math.max(0, bonus.original_amount + (bonus.realized_profits || 0) - bonus.current_amount).toFixed(2)}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500">Net P&L</p>
                          <p className={`text-lg font-medium ${(bonus.current_amount - bonus.original_amount) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                            {(bonus.current_amount - bonus.original_amount) >= 0 ? '+' : ''}${(bonus.current_amount - bonus.original_amount).toFixed(2)}
                          </p>
                        </div>
                      </div>
                    </div>
                    {bonus.status === 'active' && (
                      <div className="text-right">
                        <p className="text-xs text-gray-500 mb-1">Expires in</p>
                        <p className={`text-lg font-bold ${bonus.days_remaining <= 2 ? 'text-red-400' : 'text-yellow-400'}`}>
                          {bonus.days_remaining} days
                        </p>
                      </div>
                    )}
                  </div>

                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm mt-3 pt-3 border-t border-gray-800">
                    <div>
                      <p className="text-gray-500 mb-1">Created</p>
                      <p className="text-white">{new Date(bonus.created_at).toLocaleDateString()}</p>
                    </div>
                    <div>
                      <p className="text-gray-500 mb-1">Expires</p>
                      <p className={new Date(bonus.expires_at) < new Date() ? 'text-red-400' : 'text-yellow-400'}>
                        {new Date(bonus.expires_at).toLocaleDateString()}
                      </p>
                    </div>
                    <div>
                      <p className="text-gray-500 mb-1">Trading Volume</p>
                      <p className="text-white font-medium">
                        ${bonus.bonus_trading_volume_completed.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                      </p>
                    </div>
                    <div>
                      <p className="text-gray-500 mb-1">Volume Required</p>
                      <p className={`font-medium ${bonus.bonus_trading_volume_completed >= bonus.bonus_trading_volume_required ? 'text-green-400' : 'text-orange-400'}`}>
                        ${bonus.bonus_trading_volume_required.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        {bonus.bonus_trading_volume_required > 0 && (
                          <span className="text-xs text-gray-500 ml-1">
                            ({((bonus.bonus_trading_volume_completed / bonus.bonus_trading_volume_required) * 100).toFixed(1)}%)
                          </span>
                        )}
                      </p>
                    </div>
                  </div>

                  {bonus.consecutive_trading_days_required && (
                    <div className="mt-3 pt-3 border-t border-gray-800">
                      <div className="flex items-center gap-2 mb-3">
                        <Calendar className="w-4 h-4 text-blue-400" />
                        <span className="text-sm font-medium text-white">Consecutive Trading Progress</span>
                        {bonus.daily_trade_count_today < (bonus.daily_trades_required || 2) && bonus.status === 'active' && (
                          <span className="flex items-center gap-1 px-2 py-0.5 bg-orange-500/10 border border-orange-500/30 rounded text-xs text-orange-400">
                            <AlertTriangle className="w-3 h-3" />
                            Needs trading today
                          </span>
                        )}
                      </div>
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <p className="text-gray-500 mb-1">Consecutive Days</p>
                          <p className={`font-bold ${bonus.current_consecutive_days >= bonus.consecutive_trading_days_required ? 'text-green-400' : 'text-blue-400'}`}>
                            {bonus.current_consecutive_days} / {bonus.consecutive_trading_days_required}
                            <span className="text-xs text-gray-500 ml-1">
                              ({((bonus.current_consecutive_days / bonus.consecutive_trading_days_required) * 100).toFixed(0)}%)
                            </span>
                          </p>
                        </div>
                        <div>
                          <p className="text-gray-500 mb-1">Today's Trades</p>
                          <p className={`font-medium ${bonus.daily_trade_count_today >= (bonus.daily_trades_required || 2) ? 'text-green-400' : 'text-yellow-400'}`}>
                            {bonus.daily_trade_count_today} / {bonus.daily_trades_required || 2}
                            {bonus.daily_trade_count_today >= (bonus.daily_trades_required || 2) && (
                              <CheckCircle className="w-4 h-4 inline ml-1 text-green-400" />
                            )}
                          </p>
                        </div>
                        <div>
                          <p className="text-gray-500 mb-1">Min Trade Duration</p>
                          <p className="text-white">{bonus.daily_trade_duration_minutes || 15} minutes</p>
                        </div>
                        <div>
                          <p className="text-gray-500 mb-1">Last Qualifying Day</p>
                          <p className={bonus.last_qualifying_trade_date ? 'text-white' : 'text-gray-500'}>
                            {bonus.last_qualifying_trade_date
                              ? new Date(bonus.last_qualifying_trade_date).toLocaleDateString()
                              : 'No trades yet'}
                          </p>
                        </div>
                      </div>
                      <div className="mt-2 bg-gray-900/50 rounded-lg p-2">
                        <div className="flex justify-between text-xs mb-1">
                          <span className="text-gray-500">Day Progress</span>
                          <span className="text-gray-400">{bonus.current_consecutive_days} / {bonus.consecutive_trading_days_required} days</span>
                        </div>
                        <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
                          <div
                            className={`h-full transition-all ${bonus.current_consecutive_days >= bonus.consecutive_trading_days_required ? 'bg-green-500' : 'bg-blue-500'}`}
                            style={{ width: `${Math.min(100, (bonus.current_consecutive_days / bonus.consecutive_trading_days_required) * 100)}%` }}
                          />
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Bonus History</h2>
        <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
          {userBonuses.length === 0 ? (
            <div className="p-8 text-center">
              <Gift className="w-12 h-12 text-gray-600 mx-auto mb-3" />
              <p className="text-gray-400">No bonuses awarded to this user yet</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-800">
              {userBonuses.map((bonus) => (
                <div key={bonus.id} className="p-4 hover:bg-[#1a1d24] transition-colors">
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-2">
                        {bonus.bonus_type_name.includes('Locked') ? (
                          <Lock className="w-5 h-5 text-[#f0b90b]" />
                        ) : (
                          <Gift className="w-5 h-5 text-[#f0b90b]" />
                        )}
                        <h3 className="text-white font-bold">{bonus.bonus_type_name}</h3>
                        <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-lg border text-xs font-medium ${getStatusColor(bonus.status)}`}>
                          {getStatusIcon(bonus.status)}
                          {bonus.status.toUpperCase()}
                        </span>
                      </div>
                      <p className="text-2xl font-bold text-green-400 mb-2">
                        +${parseFloat(bonus.amount.toString()).toFixed(2)} USDT
                      </p>
                    </div>
                    {(bonus.status === 'active' || bonus.status === 'pending') && (
                      <button
                        onClick={() => handleCancelBonus(bonus.id)}
                        disabled={loading}
                        className="flex items-center gap-2 px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 transition-colors text-sm disabled:opacity-50"
                      >
                        <XCircle className="w-4 h-4" />
                        Cancel
                      </button>
                    )}
                  </div>

                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                    <div>
                      <p className="text-gray-500 mb-1">Awarded By</p>
                      <p className="text-white">{bonus.awarded_by_username}</p>
                    </div>
                    <div>
                      <p className="text-gray-500 mb-1">Awarded At</p>
                      <p className="text-white">{new Date(bonus.awarded_at).toLocaleString()}</p>
                    </div>
                    {bonus.claimed_at && (
                      <div>
                        <p className="text-gray-500 mb-1">Claimed At</p>
                        <p className="text-green-400">{new Date(bonus.claimed_at).toLocaleString()}</p>
                      </div>
                    )}
                    {bonus.expires_at && (
                      <div>
                        <p className="text-gray-500 mb-1">Expires At</p>
                        <p className={new Date(bonus.expires_at) < new Date() ? 'text-red-400' : 'text-yellow-400'}>
                          {new Date(bonus.expires_at).toLocaleString()}
                        </p>
                      </div>
                    )}
                  </div>

                  {bonus.notes && (
                    <div className="mt-3 p-3 bg-[#1a1d24] rounded-lg border border-gray-800">
                      <p className="text-gray-500 text-xs mb-1">Notes:</p>
                      <p className="text-gray-300 text-sm">{bonus.notes}</p>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {showAwardModal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-md w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-800">
              <h2 className="text-2xl font-bold text-white">Award Bonus</h2>
            </div>

            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Bonus Type</label>
                <select
                  value={formData.bonus_type_id}
                  onChange={(e) => handleBonusTypeChange(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                  disabled={loading}
                  required
                >
                  <option value="">Select Bonus Type</option>
                  {bonusTypes.map(type => (
                    <option key={type.id} value={type.id}>
                      {type.name} - ${type.default_amount} ({type.category}){type.is_locked_bonus ? ' [LOCKED]' : ''}
                    </option>
                  ))}
                </select>
              </div>

              {formData.bonus_type_id && (
                <>
                  <div className="p-4 rounded-lg border border-gray-700 bg-[#0b0e11]">
                    <label className="flex items-center gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={formData.is_locked}
                        onChange={(e) => setFormData({ ...formData, is_locked: e.target.checked })}
                        className="w-5 h-5 rounded border-gray-600 bg-gray-700 text-[#f0b90b] focus:ring-[#f0b90b]"
                        disabled={loading}
                      />
                      <div className="flex items-center gap-2">
                        {formData.is_locked ? (
                          <Lock className="w-5 h-5 text-[#f0b90b]" />
                        ) : (
                          <Unlock className="w-5 h-5 text-gray-400" />
                        )}
                        <span className="text-white font-medium">Locked Bonus</span>
                      </div>
                    </label>
                    {formData.is_locked && (
                      <p className="text-xs text-gray-400 mt-2 ml-8">
                        Cannot be withdrawn. Can be used for futures trading. Profits are withdrawable. Expires after set days.
                      </p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-2">Amount (USDT)</label>
                    <input
                      type="number"
                      step="0.01"
                      min="0.01"
                      value={formData.amount}
                      onChange={(e) => setFormData({ ...formData, amount: e.target.value })}
                      className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      disabled={loading}
                      required
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-2">
                      Expiry Days {formData.is_locked && <span className="text-red-400">*</span>}
                    </label>
                    <input
                      type="number"
                      min="1"
                      value={formData.expiry_days}
                      onChange={(e) => setFormData({ ...formData, expiry_days: e.target.value })}
                      className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      placeholder={formData.is_locked ? "Required for locked bonus (default: 7)" : "Leave empty for no expiry"}
                      disabled={loading}
                      required={formData.is_locked}
                    />
                    {formData.is_locked && (
                      <p className="text-xs text-gray-500 mt-1">Default: 7 days</p>
                    )}
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-2">Admin Notes (optional)</label>
                    <textarea
                      value={formData.notes}
                      onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                      rows={3}
                      className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                      placeholder="Reason for awarding this bonus..."
                      disabled={loading}
                    />
                  </div>

                  {formData.is_locked && (
                    <div className="p-4 rounded-lg bg-[#f0b90b]/10 border border-[#f0b90b]/30">
                      <p className="text-sm text-[#f0b90b] font-medium mb-2">Locked Bonus Rules:</p>
                      <ul className="text-xs text-gray-300 space-y-1">
                        <li>- Cannot be withdrawn by the user</li>
                        <li>- Can be used as margin for futures trading</li>
                        <li>- Trading losses are deducted from bonus first</li>
                        <li>- Trading profits go to regular wallet (withdrawable)</li>
                        <li>- Remaining bonus expires after {formData.expiry_days || 7} days</li>
                      </ul>
                    </div>
                  )}
                </>
              )}

              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowAwardModal(false);
                    setFormData({
                      bonus_type_id: '',
                      amount: '',
                      expiry_days: '7',
                      notes: '',
                      is_locked: false,
                    });
                  }}
                  disabled={loading}
                  className="flex-1 px-6 py-3 bg-gray-500/10 hover:bg-gray-500/20 text-gray-400 rounded-lg border border-gray-500/30 transition-colors font-medium disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handleAwardBonus}
                  disabled={loading || !formData.bonus_type_id || !formData.amount}
                  className="flex-1 px-6 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-bold transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {formData.is_locked && <Lock className="w-4 h-4" />}
                  {loading ? 'Awarding...' : formData.is_locked ? 'Award Locked Bonus' : 'Award Bonus'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
