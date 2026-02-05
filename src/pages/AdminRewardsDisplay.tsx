import { useState, useEffect } from 'react';
import { ArrowLeft, Plus, Edit2, Trash2, Gift, Search, Eye, EyeOff, ArrowUp, ArrowDown, ExternalLink } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { useToast } from '../hooks/useToast';
import { loggingService } from '../services/loggingService';
import Navbar from '../components/Navbar';

const REWARD_TYPES = [
  { value: 'locked_bonus', label: 'Locked Bonus' },
  { value: 'balance', label: 'Balance (Instant)' },
  { value: 'fee_rebate', label: 'Fee Rebate' },
];

interface RewardDisplayItem {
  id: string;
  title: string;
  description: string;
  reward_amount: number;
  reward_type: string;
  icon: string;
  external_link: string | null;
  sort_order: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export default function AdminRewardsDisplay() {
  const { user, loading: authLoading } = useAuth();
  const { navigateTo } = useNavigation();
  const { showToast } = useToast();
  const [items, setItems] = useState<RewardDisplayItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingItem, setEditingItem] = useState<RewardDisplayItem | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);

  const [formData, setFormData] = useState({
    title: '',
    description: '',
    reward_amount: '',
    reward_type: 'locked_bonus',
    icon: '🎁',
    external_link: '',
    sort_order: '0',
    is_active: true,
  });

  useEffect(() => {
    if (authLoading) return;
    checkAdminAndLoad();
  }, [user, authLoading]);

  const checkAdminAndLoad = async () => {
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
    await loadItems();
  };

  const loadItems = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('reward_display_items')
        .select('*')
        .order('sort_order', { ascending: true });

      if (error) throw error;
      setItems(data || []);
    } catch (error: any) {
      showToast('Failed to load reward items: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const dataToSubmit = {
        title: formData.title,
        description: formData.description,
        reward_amount: parseFloat(formData.reward_amount) || 0,
        reward_type: formData.reward_type,
        icon: formData.icon,
        external_link: formData.external_link || null,
        sort_order: parseInt(formData.sort_order) || 0,
        is_active: formData.is_active,
      };

      if (editingItem) {
        const { error } = await supabase
          .from('reward_display_items')
          .update({ ...dataToSubmit, updated_at: new Date().toISOString() })
          .eq('id', editingItem.id);

        if (error) throw error;

        await loggingService.logAdminActivity({
          action_type: 'reward_display_update',
          action_description: `Updated reward display item: ${formData.title}`,
          metadata: { item_id: editingItem.id, new_data: dataToSubmit }
        });

        showToast('Reward item updated successfully', 'success');
      } else {
        const { data: insertedData, error } = await supabase
          .from('reward_display_items')
          .insert(dataToSubmit)
          .select()
          .single();

        if (error) throw error;

        await loggingService.logAdminActivity({
          action_type: 'reward_display_create',
          action_description: `Created reward display item: ${formData.title}`,
          metadata: { item_id: insertedData.id, data: dataToSubmit }
        });

        showToast('Reward item created successfully', 'success');
      }

      setShowModal(false);
      setEditingItem(null);
      resetForm();
      await loadItems();
    } catch (error: any) {
      showToast('Failed to save reward item: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (item: RewardDisplayItem) => {
    setEditingItem(item);
    setFormData({
      title: item.title,
      description: item.description,
      reward_amount: item.reward_amount.toString(),
      reward_type: item.reward_type,
      icon: item.icon,
      external_link: item.external_link || '',
      sort_order: item.sort_order.toString(),
      is_active: item.is_active,
    });
    setShowModal(true);
  };

  const handleDelete = async (id: string) => {
    const itemToDelete = items.find(i => i.id === id);
    if (!confirm(`Are you sure you want to delete "${itemToDelete?.title}"?`)) return;

    try {
      const { error } = await supabase
        .from('reward_display_items')
        .delete()
        .eq('id', id);

      if (error) throw error;

      if (itemToDelete) {
        await loggingService.logAdminActivity({
          action_type: 'reward_display_delete',
          action_description: `Deleted reward display item: ${itemToDelete.title}`,
          metadata: { item_id: id, deleted_data: { title: itemToDelete.title, reward_amount: itemToDelete.reward_amount } }
        });
      }

      showToast('Reward item deleted successfully', 'success');
      await loadItems();
    } catch (error: any) {
      showToast('Failed to delete reward item: ' + error.message, 'error');
    }
  };

  const toggleActive = async (item: RewardDisplayItem) => {
    try {
      const { error } = await supabase
        .from('reward_display_items')
        .update({ is_active: !item.is_active, updated_at: new Date().toISOString() })
        .eq('id', item.id);

      if (error) throw error;

      await loggingService.logAdminActivity({
        action_type: 'reward_display_toggle',
        action_description: `${!item.is_active ? 'Enabled' : 'Disabled'} reward display item: ${item.title}`,
        metadata: { item_id: item.id, is_active: !item.is_active }
      });

      showToast(`${item.title} ${!item.is_active ? 'enabled' : 'disabled'}`, 'success');
      await loadItems();
    } catch (error: any) {
      showToast('Failed to toggle item: ' + error.message, 'error');
    }
  };

  const moveSortOrder = async (item: RewardDisplayItem, direction: 'up' | 'down') => {
    const sorted = [...items].sort((a, b) => a.sort_order - b.sort_order);
    const idx = sorted.findIndex(i => i.id === item.id);
    const swapIdx = direction === 'up' ? idx - 1 : idx + 1;
    if (swapIdx < 0 || swapIdx >= sorted.length) return;

    const swapItem = sorted[swapIdx];
    try {
      await supabase
        .from('reward_display_items')
        .update({ sort_order: swapItem.sort_order, updated_at: new Date().toISOString() })
        .eq('id', item.id);

      await supabase
        .from('reward_display_items')
        .update({ sort_order: item.sort_order, updated_at: new Date().toISOString() })
        .eq('id', swapItem.id);

      await loadItems();
    } catch (error: any) {
      showToast('Failed to reorder: ' + error.message, 'error');
    }
  };

  const resetForm = () => {
    setFormData({
      title: '',
      description: '',
      reward_amount: '',
      reward_type: 'locked_bonus',
      icon: '🎁',
      external_link: '',
      sort_order: ((items.length + 1) * 1).toString(),
      is_active: true,
    });
  };

  const filteredItems = items.filter(i =>
    i.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    i.description.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const getRewardTypeStyle = (type: string) => {
    const styles: Record<string, string> = {
      locked_bonus: 'bg-orange-500/10 text-orange-400 border-orange-500/30',
      balance: 'bg-green-500/10 text-green-400 border-green-500/30',
      fee_rebate: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
    };
    return styles[type] || styles.locked_bonus;
  };

  const getRewardTypeLabel = (type: string) => {
    return REWARD_TYPES.find(t => t.value === type)?.label || type;
  };

  if (!isAdmin) return null;

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex items-center gap-4 mb-8">
          <button
            onClick={() => navigateTo('admin')}
            className="p-2 hover:bg-[#2b3139] rounded-lg transition-colors"
          >
            <ArrowLeft className="w-5 h-5 text-[#848e9c]" />
          </button>
          <div className="flex-1">
            <h1 className="text-2xl font-bold text-white flex items-center gap-3">
              <Gift className="w-7 h-7 text-[#fcd535]" />
              Rewards Hub Display Management
            </h1>
            <p className="text-[#848e9c] text-sm mt-1">
              Manage which reward items appear in the user-facing Rewards Hub
            </p>
          </div>
          <button
            onClick={() => {
              setEditingItem(null);
              resetForm();
              setShowModal(true);
            }}
            className="bg-[#fcd535] hover:bg-[#f0b90b] text-black px-4 py-2.5 rounded-lg font-medium transition-all flex items-center gap-2"
          >
            <Plus className="w-4 h-4" />
            Add Reward Item
          </button>
        </div>

        <div className="mb-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-[#848e9c]" />
            <input
              type="text"
              placeholder="Search reward items..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 bg-[#2b3139] border border-[#363c45] rounded-lg text-white placeholder-[#848e9c] text-sm focus:outline-none focus:border-[#fcd535]"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-6">
          <div className="bg-[#1e2329] rounded-lg p-4 border border-[#2b3139]">
            <div className="text-[#848e9c] text-xs mb-1">Total Items</div>
            <div className="text-xl font-bold text-white">{items.length}</div>
          </div>
          <div className="bg-[#1e2329] rounded-lg p-4 border border-[#2b3139]">
            <div className="text-[#848e9c] text-xs mb-1">Active Items</div>
            <div className="text-xl font-bold text-[#0ecb81]">{items.filter(i => i.is_active).length}</div>
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#fcd535]"></div>
          </div>
        ) : filteredItems.length === 0 ? (
          <div className="text-center py-20 text-[#848e9c]">
            {searchTerm ? 'No reward items match your search' : 'No reward items configured yet'}
          </div>
        ) : (
          <div className="space-y-3">
            {filteredItems.sort((a, b) => a.sort_order - b.sort_order).map((item, idx) => (
              <div
                key={item.id}
                className={`bg-[#1e2329] rounded-xl border transition-all ${
                  item.is_active ? 'border-[#2b3139] hover:border-[#fcd535]/30' : 'border-[#2b3139] opacity-50'
                }`}
              >
                <div className="flex items-center gap-4 p-4">
                  <div className="flex flex-col items-center gap-1">
                    <button
                      onClick={() => moveSortOrder(item, 'up')}
                      disabled={idx === 0}
                      className="p-1 hover:bg-[#2b3139] rounded disabled:opacity-30 transition-colors"
                    >
                      <ArrowUp className="w-3.5 h-3.5 text-[#848e9c]" />
                    </button>
                    <span className="text-xs text-[#848e9c] font-mono">{item.sort_order}</span>
                    <button
                      onClick={() => moveSortOrder(item, 'down')}
                      disabled={idx === filteredItems.length - 1}
                      className="p-1 hover:bg-[#2b3139] rounded disabled:opacity-30 transition-colors"
                    >
                      <ArrowDown className="w-3.5 h-3.5 text-[#848e9c]" />
                    </button>
                  </div>

                  <div className="text-3xl w-12 text-center flex-shrink-0">{item.icon}</div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="text-sm font-semibold text-white truncate">{item.title}</h3>
                      {item.external_link && (
                        <ExternalLink className="w-3.5 h-3.5 text-[#848e9c] flex-shrink-0" />
                      )}
                    </div>
                    <p className="text-xs text-[#848e9c] line-clamp-1">{item.description}</p>
                    {item.external_link && (
                      <p className="text-[10px] text-[#565e67] mt-0.5 truncate">{item.external_link}</p>
                    )}
                  </div>

                  <div className="flex items-center gap-3 flex-shrink-0">
                    <div className="text-right">
                      <div className="text-sm font-bold text-[#fcd535]">${item.reward_amount}</div>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded border ${getRewardTypeStyle(item.reward_type)}`}>
                        {getRewardTypeLabel(item.reward_type)}
                      </span>
                    </div>

                    <button
                      onClick={() => toggleActive(item)}
                      className={`p-2 rounded-lg transition-colors ${
                        item.is_active
                          ? 'bg-[#0ecb81]/10 text-[#0ecb81] hover:bg-[#0ecb81]/20'
                          : 'bg-[#f6465d]/10 text-[#f6465d] hover:bg-[#f6465d]/20'
                      }`}
                      title={item.is_active ? 'Click to disable' : 'Click to enable'}
                    >
                      {item.is_active ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
                    </button>

                    <button
                      onClick={() => handleEdit(item)}
                      className="p-2 hover:bg-[#2b3139] rounded-lg transition-colors text-[#848e9c] hover:text-white"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>

                    <button
                      onClick={() => handleDelete(item.id)}
                      className="p-2 hover:bg-[#f6465d]/10 rounded-lg transition-colors text-[#848e9c] hover:text-[#f6465d]"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto border border-[#2b3139]">
            <div className="p-6 border-b border-[#2b3139]">
              <h2 className="text-lg font-bold text-white">
                {editingItem ? 'Edit Reward Item' : 'Add Reward Item'}
              </h2>
              <p className="text-xs text-[#848e9c] mt-1">
                {editingItem ? 'Update the reward display configuration' : 'Create a new reward item visible to users'}
              </p>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-xs text-[#848e9c] mb-1.5">Title</label>
                <input
                  type="text"
                  required
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-3 py-2 bg-[#0b0e11] border border-[#363c45] rounded-lg text-white text-sm focus:outline-none focus:border-[#fcd535]"
                  placeholder="e.g. KYC Verification Bonus"
                />
              </div>

              <div>
                <label className="block text-xs text-[#848e9c] mb-1.5">Description</label>
                <textarea
                  required
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  rows={2}
                  className="w-full px-3 py-2 bg-[#0b0e11] border border-[#363c45] rounded-lg text-white text-sm focus:outline-none focus:border-[#fcd535] resize-none"
                  placeholder="User-facing description of this reward"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs text-[#848e9c] mb-1.5">Reward Amount (USDT)</label>
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={formData.reward_amount}
                    onChange={(e) => setFormData({ ...formData, reward_amount: e.target.value })}
                    className="w-full px-3 py-2 bg-[#0b0e11] border border-[#363c45] rounded-lg text-white text-sm focus:outline-none focus:border-[#fcd535]"
                    placeholder="0.00"
                  />
                </div>

                <div>
                  <label className="block text-xs text-[#848e9c] mb-1.5">Reward Type</label>
                  <select
                    value={formData.reward_type}
                    onChange={(e) => setFormData({ ...formData, reward_type: e.target.value })}
                    className="w-full px-3 py-2 bg-[#0b0e11] border border-[#363c45] rounded-lg text-white text-sm focus:outline-none focus:border-[#fcd535]"
                  >
                    {REWARD_TYPES.map(t => (
                      <option key={t.value} value={t.value}>{t.label}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs text-[#848e9c] mb-1.5">Icon (emoji)</label>
                  <input
                    type="text"
                    value={formData.icon}
                    onChange={(e) => setFormData({ ...formData, icon: e.target.value })}
                    className="w-full px-3 py-2 bg-[#0b0e11] border border-[#363c45] rounded-lg text-white text-sm focus:outline-none focus:border-[#fcd535]"
                    placeholder="🎁"
                  />
                </div>

                <div>
                  <label className="block text-xs text-[#848e9c] mb-1.5">Sort Order</label>
                  <input
                    type="number"
                    value={formData.sort_order}
                    onChange={(e) => setFormData({ ...formData, sort_order: e.target.value })}
                    className="w-full px-3 py-2 bg-[#0b0e11] border border-[#363c45] rounded-lg text-white text-sm focus:outline-none focus:border-[#fcd535]"
                    placeholder="0"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs text-[#848e9c] mb-1.5">External Link (optional)</label>
                <input
                  type="text"
                  value={formData.external_link}
                  onChange={(e) => setFormData({ ...formData, external_link: e.target.value })}
                  className="w-full px-3 py-2 bg-[#0b0e11] border border-[#363c45] rounded-lg text-white text-sm focus:outline-none focus:border-[#fcd535]"
                  placeholder="e.g. /kyc or https://..."
                />
                <p className="text-[10px] text-[#565e67] mt-1">If set, users see a link button instead of a claim button</p>
              </div>

              <div className="flex items-center gap-3">
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                    className="sr-only peer"
                  />
                  <div className="w-9 h-5 bg-[#363c45] peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#0ecb81]"></div>
                </label>
                <span className="text-sm text-[#eaecef]">Active (visible to users)</span>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false);
                    setEditingItem(null);
                    resetForm();
                  }}
                  className="flex-1 py-2.5 bg-[#2b3139] text-[#848e9c] rounded-lg font-medium hover:bg-[#363c45] transition-colors text-sm"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 py-2.5 bg-[#fcd535] text-black rounded-lg font-medium hover:bg-[#f0b90b] transition-colors text-sm disabled:opacity-50"
                >
                  {editingItem ? 'Update' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
