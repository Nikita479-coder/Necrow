import { useState, useEffect } from 'react';
import { Star } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface ExclusiveAffiliate {
  id: string;
  user_id: string;
  username: string | null;
  full_name: string | null;
  email: string;
  is_active: boolean;
  deposit_commission_rates: Record<string, number> | null;
  fee_share_rates: Record<string, number> | null;
  copy_profit_rates: Record<string, number> | null;
  created_at: string;
  network_size: number;
}

export default function PromoterExclusiveAffiliates() {
  const [affiliates, setAffiliates] = useState<ExclusiveAffiliate[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadAffiliates();
  }, []);

  const loadAffiliates = async () => {
    try {
      const { data, error } = await supabase.rpc('promoter_get_exclusive_affiliates');
      if (error) throw error;
      if (data?.success) {
        setAffiliates(data.affiliates || []);
      }
    } catch (err) {
      console.error('Failed to load affiliates:', err);
    } finally {
      setLoading(false);
    }
  };

  const formatRates = (rates: Record<string, number> | null) => {
    if (!rates) return '-';
    const entries = Object.entries(rates).filter(([, v]) => v > 0);
    if (entries.length === 0) return '-';
    return entries.slice(0, 3).map(([k, v]) => `L${k}: ${v}%`).join(', ') + (entries.length > 3 ? '...' : '');
  };

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white">Exclusive Affiliates</h2>
        <p className="text-sm text-gray-400">Exclusive affiliate partners within your referral tree</p>
      </div>

      {affiliates.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <Star className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No exclusive affiliates in your tree</p>
        </div>
      ) : (
        <div className="space-y-4">
          {affiliates.map(aff => (
            <div key={aff.id} className="bg-[#1a1d24] rounded-xl border border-gray-800 p-5">
              <div className="flex items-start justify-between mb-4">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="text-white font-medium">{aff.full_name || aff.username || 'N/A'}</h3>
                    <span className={`text-xs px-2 py-0.5 rounded-md font-medium ${
                      aff.is_active ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'
                    }`}>
                      {aff.is_active ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                  <p className="text-sm text-gray-400">{aff.email}</p>
                </div>
                <div className="text-right">
                  <p className="text-xs text-gray-400">Network Size</p>
                  <p className="text-lg font-bold text-blue-400">{aff.network_size}</p>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Deposit Rates</p>
                  <p className="text-sm text-emerald-400 font-medium">{formatRates(aff.deposit_commission_rates)}</p>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Fee Share Rates</p>
                  <p className="text-sm text-blue-400 font-medium">{formatRates(aff.fee_share_rates)}</p>
                </div>
                <div className="bg-[#0b0e11] rounded-lg p-3">
                  <p className="text-xs text-gray-500 mb-1">Copy Profit Rates</p>
                  <p className="text-sm text-[#f0b90b] font-medium">{formatRates(aff.copy_profit_rates)}</p>
                </div>
              </div>

              <p className="text-xs text-gray-600 mt-3">Enrolled: {new Date(aff.created_at).toLocaleDateString()}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
