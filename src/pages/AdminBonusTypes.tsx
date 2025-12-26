import { useState, useEffect } from 'react';
import { ArrowLeft, Plus, Edit2, Trash2, Gift, Search, Lock } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { useToast } from '../hooks/useToast';
import { loggingService } from '../services/loggingService';
import Navbar from '../components/Navbar';

interface BonusType {
  id: string;
  name: string;
  description: string;
  default_amount: number;
  category: string;
  expiry_days: number | null;
  is_active: boolean;
  is_locked_bonus: boolean;
  created_at: string;
}

export default function AdminBonusTypes() {
  const { user, loading: authLoading } = useAuth();
  const { navigateTo } = useNavigation();
  const { showToast } = useToast();
  const [bonusTypes, setBonusTypes] = useState<BonusType[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingBonus, setEditingBonus] = useState<BonusType | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);

  const [formData, setFormData] = useState({
    name: '',
    description: '',
    default_amount: '',
    category: 'special',
    expiry_days: '',
    is_active: true,
    is_locked_bonus: false,
  });

  useEffect(() => {
    if (authLoading) return;
    checkAdminAndLoadBonusTypes();
  }, [user, authLoading]);

  const checkAdminAndLoadBonusTypes = async () => {
    if (authLoading) return;

    if (!user) {
      navigateTo('signin');
      return;
    }

    const { data } = await supabase
      .from('user_profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();

    if (!data?.is_admin) {
      navigateTo('home');
      return;
    }

    setIsAdmin(true);
    await loadBonusTypes();
  };

  const loadBonusTypes = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('bonus_types')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setBonusTypes(data || []);
    } catch (error: any) {
      showToast('Failed to load bonus types: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const dataToSubmit = {
        name: formData.name,
        description: formData.description,
        default_amount: parseFloat(formData.default_amount),
        category: formData.category,
        expiry_days: formData.is_locked_bonus
          ? (formData.expiry_days ? parseInt(formData.expiry_days) : 7)
          : (formData.expiry_days ? parseInt(formData.expiry_days) : null),
        is_active: formData.is_active,
        is_locked_bonus: formData.is_locked_bonus,
      };

      if (editingBonus) {
        const { error } = await supabase
          .from('bonus_types')
          .update({
            ...dataToSubmit,
            updated_at: new Date().toISOString(),
          })
          .eq('id', editingBonus.id);

        if (error) throw error;

        await loggingService.logAdminActivity({
          action_type: 'bonus_type_update',
          action_description: `Updated bonus type: ${formData.name}`,
          metadata: {
            bonus_type_id: editingBonus.id,
            old_data: {
              name: editingBonus.name,
              amount: editingBonus.default_amount,
              category: editingBonus.category
            },
            new_data: dataToSubmit
          }
        });

        showToast('Bonus type updated successfully', 'success');
      } else {
        const { data: insertedData, error } = await supabase
          .from('bonus_types')
          .insert({
            ...dataToSubmit,
            created_by: user!.id,
          })
          .select()
          .single();

        if (error) throw error;

        await loggingService.logAdminActivity({
          action_type: 'bonus_type_create',
          action_description: `Created new bonus type: ${formData.name}`,
          metadata: {
            bonus_type_id: insertedData.id,
            bonus_data: dataToSubmit
          }
        });

        showToast('Bonus type created successfully', 'success');
      }

      setShowModal(false);
      setEditingBonus(null);
      resetForm();
      await loadBonusTypes();
    } catch (error: any) {
      showToast('Failed to save bonus type: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (bonus: BonusType) => {
    setEditingBonus(bonus);
    setFormData({
      name: bonus.name,
      description: bonus.description,
      default_amount: bonus.default_amount.toString(),
      category: bonus.category,
      expiry_days: bonus.expiry_days?.toString() || '',
      is_active: bonus.is_active,
      is_locked_bonus: bonus.is_locked_bonus || false,
    });
    setShowModal(true);
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this bonus type?')) return;

    try {
      const bonusToDelete = bonusTypes.find(b => b.id === id);

      const { error } = await supabase
        .from('bonus_types')
        .delete()
        .eq('id', id);

      if (error) throw error;

      if (bonusToDelete) {
        await loggingService.logAdminActivity({
          action_type: 'bonus_type_delete',
          action_description: `Deleted bonus type: ${bonusToDelete.name}`,
          metadata: {
            bonus_type_id: id,
            deleted_data: {
              name: bonusToDelete.name,
              amount: bonusToDelete.default_amount,
              category: bonusToDelete.category
            }
          }
        });
      }

      showToast('Bonus type deleted successfully', 'success');
      await loadBonusTypes();
    } catch (error: any) {
      showToast('Failed to delete bonus type: ' + error.message, 'error');
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      description: '',
      default_amount: '',
      category: 'special',
      expiry_days: '',
      is_active: true,
      is_locked_bonus: false,
    });
  };

  const filteredBonusTypes = bonusTypes.filter(b =>
    b.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    b.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
    b.category.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      welcome: 'bg-green-500/10 text-green-400 border-green-500/30',
      deposit: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
      trading: 'bg-orange-500/10 text-orange-400 border-orange-500/30',
      vip: 'bg-purple-500/10 text-purple-400 border-purple-500/30',
      referral: 'bg-pink-500/10 text-pink-400 border-pink-500/30',
      promotion: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30',
      special: 'bg-red-500/10 text-red-400 border-red-500/30',
    };
    return colors[category] || colors.special;
  };

  if (!isAdmin) return null;

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <Navbar />

      <div className="max-w-7xl mx-auto px-4 py-8">
        <button
          onClick={() => navigateTo('admindashboard')}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors mb-6"
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Back to Dashboard</span>
        </button>

        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h1 className="text-3xl font-bold text-white mb-2">Bonus Types</h1>
              <p className="text-gray-400">Define and manage bonus types that can be awarded to users</p>
            </div>
            <button
              onClick={() => {
                resetForm();
                setEditingBonus(null);
                setShowModal(true);
              }}
              className="flex items-center gap-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black px-6 py-3 rounded-lg font-bold transition-all"
            >
              <Plus className="w-5 h-5" />
              New Bonus Type
            </button>
          </div>

          <div className="relative mb-6">
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search bonus types..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full bg-[#1a1d24] border border-gray-800 rounded-xl pl-12 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors"
            />
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b]"></div>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredBonusTypes.map((bonus) => (
              <div
                key={bonus.id}
                className={`bg-[#1a1d24] rounded-xl p-6 border transition-colors ${bonus.is_locked_bonus ? 'border-[#f0b90b]/30 hover:border-[#f0b90b]/50' : 'border-gray-800 hover:border-gray-700'}`}
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-2">
                      {bonus.is_locked_bonus ? (
                        <Lock className="w-5 h-5 text-[#f0b90b]" />
                      ) : (
                        <Gift className="w-5 h-5 text-[#f0b90b]" />
                      )}
                      <h3 className="text-lg font-bold text-white">{bonus.name}</h3>
                    </div>
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className={`inline-flex items-center px-2 py-1 rounded-lg border text-xs font-medium ${getCategoryColor(bonus.category)}`}>
                        {bonus.category.toUpperCase()}
                      </span>
                      {bonus.is_locked_bonus && (
                        <span className="inline-flex items-center gap-1 px-2 py-1 rounded-lg border text-xs font-medium bg-[#f0b90b]/10 text-[#f0b90b] border-[#f0b90b]/30">
                          <Lock className="w-3 h-3" />
                          LOCKED
                        </span>
                      )}
                    </div>
                  </div>
                  <div className={`w-3 h-3 rounded-full ${bonus.is_active ? 'bg-green-400' : 'bg-gray-600'}`}></div>
                </div>

                <p className="text-gray-400 text-sm mb-4">{bonus.description}</p>

                <div className="grid grid-cols-2 gap-4 mb-4">
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Default Amount</p>
                    <p className="text-white font-bold">${bonus.default_amount}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Expiry</p>
                    <p className="text-white font-bold">{bonus.expiry_days ? `${bonus.expiry_days} days` : 'Never'}</p>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => handleEdit(bonus)}
                    className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-gray-500/10 hover:bg-gray-500/20 text-gray-400 rounded-lg border border-gray-500/30 transition-colors text-sm"
                  >
                    <Edit2 className="w-4 h-4" />
                    Edit
                  </button>
                  <button
                    onClick={() => handleDelete(bonus.id)}
                    className="flex items-center justify-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 transition-colors text-sm"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}

            {filteredBonusTypes.length === 0 && (
              <div className="col-span-full text-center py-20">
                <Gift className="w-16 h-16 text-gray-600 mx-auto mb-4" />
                <p className="text-gray-400">No bonus types found</p>
              </div>
            )}
          </div>
        )}
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-2xl w-full max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-gray-800">
              <h2 className="text-2xl font-bold text-white">
                {editingBonus ? 'Edit Bonus Type' : 'Create Bonus Type'}
              </h2>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Bonus Name</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                  placeholder="Welcome Bonus"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Category</label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                >
                  <option value="special">Special</option>
                  <option value="welcome">Welcome</option>
                  <option value="deposit">Deposit</option>
                  <option value="trading">Trading</option>
                  <option value="vip">VIP</option>
                  <option value="referral">Referral</option>
                  <option value="promotion">Promotion</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Description</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  rows={3}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                  placeholder="Describe this bonus type..."
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">Default Amount (USDT)</label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    value={formData.default_amount}
                    onChange={(e) => setFormData({ ...formData, default_amount: e.target.value })}
                    className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                    placeholder="100.00"
                    required
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">Expiry (days)</label>
                  <input
                    type="number"
                    min="0"
                    value={formData.expiry_days}
                    onChange={(e) => setFormData({ ...formData, expiry_days: e.target.value })}
                    className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                    placeholder="Never (leave empty)"
                  />
                </div>
              </div>

              <div className="p-4 rounded-lg border border-gray-700 bg-[#0b0e11]">
                <label className="flex items-center gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.is_locked_bonus}
                    onChange={(e) => setFormData({
                      ...formData,
                      is_locked_bonus: e.target.checked,
                      expiry_days: e.target.checked && !formData.expiry_days ? '7' : formData.expiry_days
                    })}
                    className="w-5 h-5 rounded border-gray-600 bg-gray-700 text-[#f0b90b] focus:ring-[#f0b90b]"
                  />
                  <div className="flex items-center gap-2">
                    <Lock className="w-5 h-5 text-[#f0b90b]" />
                    <span className="text-white font-medium">Locked Bonus Type</span>
                  </div>
                </label>
                {formData.is_locked_bonus && (
                  <div className="mt-3 p-3 rounded-lg bg-[#f0b90b]/10 border border-[#f0b90b]/30">
                    <p className="text-xs text-[#f0b90b] font-medium mb-1">Locked Bonus Rules:</p>
                    <ul className="text-xs text-gray-300 space-y-0.5">
                      <li>- Cannot be withdrawn by users</li>
                      <li>- Can be used for futures trading</li>
                      <li>- Profits are withdrawable</li>
                      <li>- Expires after set period (default: 7 days)</li>
                    </ul>
                  </div>
                )}
              </div>

              <div className="flex items-center gap-3">
                <input
                  type="checkbox"
                  id="is_active"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                  className="w-5 h-5 rounded border-gray-700 bg-[#0b0e11] text-[#f0b90b] focus:ring-[#f0b90b] focus:ring-offset-0"
                />
                <label htmlFor="is_active" className="text-sm text-gray-400">
                  Bonus type is active
                </label>
              </div>

              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false);
                    setEditingBonus(null);
                    resetForm();
                  }}
                  className="flex-1 px-6 py-3 bg-gray-500/10 hover:bg-gray-500/20 text-gray-400 rounded-lg border border-gray-500/30 transition-colors font-medium"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 px-6 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-bold transition-colors disabled:opacity-50"
                >
                  {editingBonus ? 'Update' : 'Create'} Bonus Type
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
