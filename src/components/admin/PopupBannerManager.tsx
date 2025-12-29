import { useState, useEffect, useRef } from 'react';
import {
  Image as ImageIcon,
  Upload,
  Trash2,
  Eye,
  EyeOff,
  Users,
  TrendingUp,
  AlertCircle,
  Check,
  X,
  Loader,
  Target,
  ChevronDown,
  ChevronRight,
  Search,
  UserPlus,
  Filter
} from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface PopupBanner {
  popup_id: string;
  title: string;
  description: string | null;
  image_url: string;
  is_active: boolean;
  created_at: string;
  total_views: number;
  unique_viewers: number;
  view_percentage: number;
  target_audiences: string[] | null;
  target_user_ids: string[] | null;
  audience_logic: string;
  potential_reach: number;
}

interface AudienceType {
  category: string;
  audience_type: string;
  label: string;
  description: string;
}

interface AudienceCount {
  audience_type: string;
  user_count: number;
}

interface SelectedUser {
  user_id: string;
  email: string;
  full_name: string | null;
  username: string | null;
}

const AUDIENCE_CATEGORIES = [
  { id: 'Activity', icon: TrendingUp, color: 'text-blue-400' },
  { id: 'Deposits', icon: Target, color: 'text-green-400' },
  { id: 'Referrals', icon: Users, color: 'text-yellow-400' },
  { id: 'VIP & Status', icon: Target, color: 'text-cyan-400' },
  { id: 'Copy Trading', icon: Users, color: 'text-orange-400' },
  { id: 'Staking', icon: TrendingUp, color: 'text-teal-400' },
  { id: 'Shark Card', icon: Target, color: 'text-rose-400' },
  { id: 'Custom', icon: UserPlus, color: 'text-gray-400' }
];

export default function PopupBannerManager() {
  const { user } = useAuth();
  const [popups, setPopups] = useState<PopupBanner[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [previewImage, setPreviewImage] = useState<string | null>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [formData, setFormData] = useState({
    title: '',
    description: ''
  });
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [audienceTypes, setAudienceTypes] = useState<AudienceType[]>([]);
  const [audienceCounts, setAudienceCounts] = useState<Map<string, number>>(new Map());
  const [loadingCounts, setLoadingCounts] = useState(false);
  const [selectedAudiences, setSelectedAudiences] = useState<string[]>([]);
  const [audienceLogic, setAudienceLogic] = useState<'AND' | 'OR'>('OR');
  const [expandedCategories, setExpandedCategories] = useState<string[]>(['Activity', 'Deposits']);
  const [estimatedReach, setEstimatedReach] = useState<number | null>(null);
  const [loadingReach, setLoadingReach] = useState(false);

  const [showUserSearch, setShowUserSearch] = useState(false);
  const [userSearchTerm, setUserSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<SelectedUser[]>([]);
  const [selectedUsers, setSelectedUsers] = useState<SelectedUser[]>([]);
  const [searchingUsers, setSearchingUsers] = useState(false);

  useEffect(() => {
    loadPopups();
    loadAudienceTypes();
    loadAudienceCounts();
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      if (selectedAudiences.length > 0 || selectedUsers.length > 0) {
        calculateEstimatedReach();
      } else {
        setEstimatedReach(null);
      }
    }, 500);
    return () => clearTimeout(timer);
  }, [selectedAudiences, selectedUsers, audienceLogic]);

  const loadPopups = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_popup_statistics');
      if (error) throw error;
      setPopups(data || []);
    } catch (error: any) {
      console.error('Error loading popups:', error);
      setError('Failed to load popup banners');
    } finally {
      setLoading(false);
    }
  };

  const loadAudienceTypes = async () => {
    try {
      const { data, error } = await supabase.rpc('get_audience_types');
      if (error) throw error;
      setAudienceTypes(data || []);
    } catch (error) {
      console.error('Error loading audience types:', error);
    }
  };

  const loadAudienceCounts = async () => {
    setLoadingCounts(true);
    try {
      const { data, error } = await supabase.rpc('get_audience_type_counts');
      if (error) throw error;
      const countsMap = new Map<string, number>();
      (data || []).forEach((item: AudienceCount) => {
        countsMap.set(item.audience_type, item.user_count);
      });
      setAudienceCounts(countsMap);
    } catch (error) {
      console.error('Error loading audience counts:', error);
    } finally {
      setLoadingCounts(false);
    }
  };

  const calculateEstimatedReach = async () => {
    setLoadingReach(true);
    try {
      const audiences = selectedUsers.length > 0
        ? [...selectedAudiences, 'selected_users']
        : selectedAudiences;
      const userIds = selectedUsers.map(u => u.user_id);

      const { data, error } = await supabase.rpc('get_audience_user_count', {
        p_audiences: audiences,
        p_user_ids: userIds,
        p_logic: audienceLogic
      });
      if (error) throw error;
      setEstimatedReach(data);
    } catch (error) {
      console.error('Error calculating reach:', error);
    } finally {
      setLoadingReach(false);
    }
  };

  const searchUsers = async () => {
    if (!userSearchTerm.trim()) return;
    setSearchingUsers(true);
    try {
      const { data, error } = await supabase.rpc('search_users_for_targeting', {
        p_search_term: userSearchTerm.trim(),
        p_limit: 20
      });
      if (error) throw error;
      setSearchResults(data || []);
    } catch (error) {
      console.error('Error searching users:', error);
    } finally {
      setSearchingUsers(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      setError('Please select an image file');
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setError('Image size must be less than 5MB');
      return;
    }

    setSelectedFile(file);
    const reader = new FileReader();
    reader.onloadend = () => {
      setPreviewImage(reader.result as string);
    };
    reader.readAsDataURL(file);
    setError(null);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();

    const file = e.dataTransfer.files[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      setError('Please select an image file');
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      setError('Image size must be less than 5MB');
      return;
    }

    setSelectedFile(file);
    const reader = new FileReader();
    reader.onloadend = () => {
      setPreviewImage(reader.result as string);
    };
    reader.readAsDataURL(file);
    setError(null);
  };

  const handleCreatePopup = async () => {
    if (!selectedFile || !formData.title.trim()) {
      setError('Please provide a title and select an image');
      return;
    }

    setUploading(true);
    setError(null);

    try {
      const fileExt = selectedFile.name.split('.').pop();
      const fileName = `${Date.now()}-${Math.random().toString(36).substring(7)}.${fileExt}`;
      const filePath = fileName;

      const { error: uploadError } = await supabase.storage
        .from('popup-banners')
        .upload(filePath, selectedFile, {
          cacheControl: '3600',
          upsert: false
        });

      if (uploadError) throw uploadError;

      const { data: urlData } = supabase.storage
        .from('popup-banners')
        .getPublicUrl(filePath);

      const targetAudiences = selectedUsers.length > 0
        ? [...selectedAudiences, 'selected_users']
        : selectedAudiences;

      const { error: insertError } = await supabase
        .from('popup_banners')
        .insert({
          title: formData.title.trim(),
          description: formData.description.trim() || null,
          image_url: urlData.publicUrl,
          image_path: filePath,
          created_by: user?.id,
          is_active: true,
          target_audiences: targetAudiences.length > 0 ? targetAudiences : null,
          target_user_ids: selectedUsers.length > 0 ? selectedUsers.map(u => u.user_id) : null,
          audience_logic: audienceLogic
        });

      if (insertError) {
        await supabase.storage.from('popup-banners').remove([filePath]);
        throw insertError;
      }

      setSuccess('Popup banner created successfully!');
      resetForm();
      loadPopups();

      setTimeout(() => setSuccess(null), 3000);
    } catch (error: any) {
      console.error('Error creating popup:', error);
      setError(error.message || 'Failed to create popup banner');
    } finally {
      setUploading(false);
    }
  };

  const handleToggleActive = async (popupId: string, currentState: boolean) => {
    try {
      const { error } = await supabase
        .from('popup_banners')
        .update({ is_active: !currentState })
        .eq('id', popupId);

      if (error) throw error;

      setSuccess(`Popup ${!currentState ? 'activated' : 'deactivated'} successfully!`);
      loadPopups();
      setTimeout(() => setSuccess(null), 3000);
    } catch (error: any) {
      console.error('Error toggling popup:', error);
      setError('Failed to update popup status');
    }
  };

  const handleDeletePopup = async (popupId: string) => {
    if (!confirm('Are you sure you want to delete this popup banner? This action cannot be undone.')) {
      return;
    }

    try {
      const { data, error } = await supabase.rpc('delete_popup_banner', {
        p_popup_id: popupId
      });

      if (error) throw error;

      if (data?.image_path) {
        await supabase.storage
          .from('popup-banners')
          .remove([data.image_path]);
      }

      setSuccess('Popup banner deleted successfully!');
      loadPopups();
      setTimeout(() => setSuccess(null), 3000);
    } catch (error: any) {
      console.error('Error deleting popup:', error);
      setError('Failed to delete popup banner');
    }
  };

  const resetForm = () => {
    setShowCreateForm(false);
    setSelectedFile(null);
    setPreviewImage(null);
    setFormData({ title: '', description: '' });
    setSelectedAudiences([]);
    setSelectedUsers([]);
    setAudienceLogic('OR');
    setEstimatedReach(null);
    setError(null);
  };

  const toggleAudience = (audienceType: string) => {
    setSelectedAudiences(prev =>
      prev.includes(audienceType)
        ? prev.filter(a => a !== audienceType)
        : [...prev, audienceType]
    );
  };

  const toggleCategory = (category: string) => {
    setExpandedCategories(prev =>
      prev.includes(category)
        ? prev.filter(c => c !== category)
        : [...prev, category]
    );
  };

  const addUser = (user: SelectedUser) => {
    if (!selectedUsers.find(u => u.user_id === user.user_id)) {
      setSelectedUsers(prev => [...prev, user]);
    }
  };

  const removeUser = (userId: string) => {
    setSelectedUsers(prev => prev.filter(u => u.user_id !== userId));
  };

  const getAudienceLabel = (audienceType: string) => {
    const found = audienceTypes.find(a => a.audience_type === audienceType);
    return found?.label || audienceType;
  };

  const groupedAudiences = AUDIENCE_CATEGORIES.map(cat => ({
    ...cat,
    audiences: audienceTypes.filter(a => a.category === cat.id && a.audience_type !== 'selected_users')
  }));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white mb-2">Popup Banners</h2>
          <p className="text-gray-400">Create and manage targeted popup announcements</p>
        </div>
        <button
          onClick={() => setShowCreateForm(!showCreateForm)}
          className="flex items-center gap-2 px-4 py-2 bg-[#f0b90b] text-black rounded-xl font-medium hover:bg-[#d4a50a] transition-colors"
        >
          <Upload className="w-5 h-5" />
          Create Popup
        </button>
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-4 flex items-center gap-3">
          <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0" />
          <p className="text-red-400">{error}</p>
          <button onClick={() => setError(null)} className="ml-auto text-red-400 hover:text-red-300">
            <X className="w-5 h-5" />
          </button>
        </div>
      )}

      {success && (
        <div className="bg-green-500/10 border border-green-500/30 rounded-xl p-4 flex items-center gap-3">
          <Check className="w-5 h-5 text-green-400 flex-shrink-0" />
          <p className="text-green-400">{success}</p>
        </div>
      )}

      {showCreateForm && (
        <div className="bg-[#0b0e11] rounded-xl border border-gray-800 p-6 space-y-6">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-bold text-white">Create New Popup Banner</h3>
            <button onClick={resetForm} className="text-gray-400 hover:text-white">
              <X className="w-5 h-5" />
            </button>
          </div>

          <div className="grid lg:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Banner Title *
                </label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="Enter banner title..."
                  className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Description (Optional)
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Enter banner description..."
                  rows={3}
                  className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors resize-none"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Banner Image * (Max 5MB)
                </label>
                <div
                  onDragOver={handleDragOver}
                  onDrop={handleDrop}
                  onClick={() => fileInputRef.current?.click()}
                  className="border-2 border-dashed border-gray-700 hover:border-[#f0b90b] rounded-xl p-6 text-center cursor-pointer transition-colors bg-[#1a1d24]"
                >
                  {previewImage ? (
                    <div className="space-y-3">
                      <img
                        src={previewImage}
                        alt="Preview"
                        className="max-h-40 mx-auto rounded-lg"
                      />
                      <p className="text-gray-400 text-sm">Click to change image</p>
                    </div>
                  ) : (
                    <div className="space-y-2">
                      <Upload className="w-10 h-10 text-gray-500 mx-auto" />
                      <div>
                        <p className="text-white font-medium text-sm">Click to upload or drag and drop</p>
                        <p className="text-gray-500 text-xs mt-1">PNG, JPG, GIF up to 5MB</p>
                      </div>
                    </div>
                  )}
                </div>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleFileSelect}
                  className="hidden"
                />
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <div className="flex items-center justify-between mb-3">
                  <label className="text-sm font-medium text-gray-400 flex items-center gap-2">
                    <Target className="w-4 h-4" />
                    Target Audience
                  </label>
                  <div className="flex items-center gap-2 bg-[#1a1d24] rounded-lg p-1">
                    <button
                      onClick={() => setAudienceLogic('OR')}
                      className={`px-3 py-1 rounded text-xs font-medium transition-colors ${
                        audienceLogic === 'OR'
                          ? 'bg-[#f0b90b] text-black'
                          : 'text-gray-400 hover:text-white'
                      }`}
                    >
                      Match ANY
                    </button>
                    <button
                      onClick={() => setAudienceLogic('AND')}
                      className={`px-3 py-1 rounded text-xs font-medium transition-colors ${
                        audienceLogic === 'AND'
                          ? 'bg-[#f0b90b] text-black'
                          : 'text-gray-400 hover:text-white'
                      }`}
                    >
                      Match ALL
                    </button>
                  </div>
                </div>

                {estimatedReach !== null && (
                  <div className="mb-3 p-3 bg-[#1a1d24] rounded-lg border border-gray-700">
                    <div className="flex items-center justify-between">
                      <span className="text-gray-400 text-sm">Estimated Reach</span>
                      {loadingReach ? (
                        <Loader className="w-4 h-4 animate-spin text-gray-400" />
                      ) : (
                        <span className="text-white font-bold">{estimatedReach.toLocaleString()} users</span>
                      )}
                    </div>
                  </div>
                )}

                {selectedAudiences.length > 0 && (
                  <div className="mb-3 flex flex-wrap gap-2">
                    {selectedAudiences.map(aud => (
                      <span
                        key={aud}
                        className="inline-flex items-center gap-1 px-2 py-1 bg-[#f0b90b]/20 text-[#f0b90b] rounded text-xs"
                      >
                        {getAudienceLabel(aud)}
                        <button onClick={() => toggleAudience(aud)} className="hover:text-white">
                          <X className="w-3 h-3" />
                        </button>
                      </span>
                    ))}
                  </div>
                )}

                <div className="bg-[#1a1d24] rounded-lg border border-gray-700 max-h-64 overflow-y-auto">
                  {groupedAudiences.map(group => (
                    <div key={group.id} className="border-b border-gray-700 last:border-0">
                      <button
                        onClick={() => toggleCategory(group.id)}
                        className="w-full flex items-center justify-between p-3 hover:bg-gray-800/50 transition-colors"
                      >
                        <div className="flex items-center gap-2">
                          <group.icon className={`w-4 h-4 ${group.color}`} />
                          <span className="text-white text-sm font-medium">{group.id}</span>
                          {group.audiences.filter(a => selectedAudiences.includes(a.audience_type)).length > 0 && (
                            <span className="px-1.5 py-0.5 bg-[#f0b90b]/20 text-[#f0b90b] rounded text-xs">
                              {group.audiences.filter(a => selectedAudiences.includes(a.audience_type)).length}
                            </span>
                          )}
                        </div>
                        {expandedCategories.includes(group.id) ? (
                          <ChevronDown className="w-4 h-4 text-gray-400" />
                        ) : (
                          <ChevronRight className="w-4 h-4 text-gray-400" />
                        )}
                      </button>
                      {expandedCategories.includes(group.id) && (
                        <div className="px-3 pb-3 space-y-1">
                          {group.id === 'Custom' ? (
                            <div className="space-y-3">
                              <div className="flex items-center justify-between p-2 bg-gray-800/30 rounded">
                                <div>
                                  <p className="text-white text-sm">Selected Users</p>
                                  <p className="text-gray-500 text-xs">Manually select specific users to target</p>
                                </div>
                                <span className="text-xs px-2 py-0.5 rounded bg-[#f0b90b]/20 text-[#f0b90b] font-medium">
                                  {selectedUsers.length} selected
                                </span>
                              </div>
                              {selectedUsers.length > 0 ? (
                                <div className="space-y-1 max-h-32 overflow-y-auto">
                                  {selectedUsers.map(u => (
                                    <div key={u.user_id} className="flex items-center justify-between bg-gray-800/50 rounded px-2 py-1">
                                      <div>
                                        <p className="text-white text-sm">{u.full_name || u.username || 'Unknown'}</p>
                                        <p className="text-gray-500 text-xs">{u.email}</p>
                                      </div>
                                      <button
                                        onClick={() => removeUser(u.user_id)}
                                        className="text-gray-400 hover:text-red-400"
                                      >
                                        <X className="w-4 h-4" />
                                      </button>
                                    </div>
                                  ))}
                                </div>
                              ) : (
                                <p className="text-gray-600 text-xs text-center py-2">No users selected yet</p>
                              )}
                              <button
                                onClick={() => setShowUserSearch(true)}
                                className="w-full flex items-center justify-center gap-2 px-3 py-2 bg-[#f0b90b]/10 text-[#f0b90b] rounded text-sm font-medium hover:bg-[#f0b90b]/20 transition-colors"
                              >
                                <Search className="w-4 h-4" />
                                Search & Add Users
                              </button>
                            </div>
                          ) : (
                            group.audiences.map(audience => (
                              <label
                                key={audience.audience_type}
                                className="flex items-start gap-3 p-2 rounded hover:bg-gray-800/30 cursor-pointer"
                              >
                                <input
                                  type="checkbox"
                                  checked={selectedAudiences.includes(audience.audience_type)}
                                  onChange={() => toggleAudience(audience.audience_type)}
                                  className="mt-0.5 w-4 h-4 rounded border-gray-600 bg-gray-700 text-[#f0b90b] focus:ring-[#f0b90b] focus:ring-offset-0"
                                />
                                <div className="flex-1">
                                  <div className="flex items-center justify-between">
                                    <p className="text-white text-sm">{audience.label}</p>
                                    <span className="text-xs px-2 py-0.5 rounded bg-gray-800 text-gray-400 font-medium">
                                      {loadingCounts ? '...' : (audienceCounts.get(audience.audience_type) || 0).toLocaleString()}
                                    </span>
                                  </div>
                                  <p className="text-gray-500 text-xs">{audience.description}</p>
                                </div>
                              </label>
                            ))
                          )}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>

            </div>
          </div>

          <div className="flex items-center gap-3 pt-4 border-t border-gray-800">
            <button
              onClick={handleCreatePopup}
              disabled={uploading || !selectedFile || !formData.title.trim()}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-[#f0b90b] text-black rounded-xl font-medium hover:bg-[#d4a50a] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {uploading ? (
                <>
                  <Loader className="w-5 h-5 animate-spin" />
                  Creating...
                </>
              ) : (
                <>
                  <Check className="w-5 h-5" />
                  Create Popup Banner
                </>
              )}
            </button>
            <button
              onClick={resetForm}
              disabled={uploading}
              className="px-4 py-3 bg-gray-800 text-white rounded-xl font-medium hover:bg-gray-700 transition-colors disabled:opacity-50"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {showUserSearch && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => setShowUserSearch(false)} />
          <div className="relative bg-[#0b0e11] rounded-xl border border-gray-800 w-full max-w-lg p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-white">Search Users</h3>
              <button onClick={() => setShowUserSearch(false)} className="text-gray-400 hover:text-white">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
              <input
                type="text"
                value={userSearchTerm}
                onChange={(e) => setUserSearchTerm(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && searchUsers()}
                placeholder="Search by email, name, or username..."
                className="w-full bg-[#1a1d24] border border-gray-700 rounded-lg pl-10 pr-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
              />
            </div>

            <button
              onClick={searchUsers}
              disabled={searchingUsers || !userSearchTerm.trim()}
              className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-[#f0b90b] text-black rounded-lg font-medium hover:bg-[#d4a50a] transition-colors disabled:opacity-50"
            >
              {searchingUsers ? (
                <>
                  <Loader className="w-4 h-4 animate-spin" />
                  Searching...
                </>
              ) : (
                <>
                  <Search className="w-4 h-4" />
                  Search
                </>
              )}
            </button>

            {searchResults.length > 0 && (
              <div className="max-h-64 overflow-y-auto space-y-2">
                {searchResults.map(user => {
                  const isSelected = selectedUsers.some(u => u.user_id === user.user_id);
                  return (
                    <div
                      key={user.user_id}
                      className={`flex items-center justify-between p-3 rounded-lg border transition-colors ${
                        isSelected
                          ? 'bg-[#f0b90b]/10 border-[#f0b90b]/30'
                          : 'bg-[#1a1d24] border-gray-700 hover:border-gray-600'
                      }`}
                    >
                      <div>
                        <p className="text-white font-medium">{user.full_name || user.username || 'Unknown'}</p>
                        <p className="text-gray-400 text-sm">{user.email}</p>
                      </div>
                      {isSelected ? (
                        <button
                          onClick={() => removeUser(user.user_id)}
                          className="px-3 py-1 bg-red-500/20 text-red-400 rounded text-sm hover:bg-red-500/30"
                        >
                          Remove
                        </button>
                      ) : (
                        <button
                          onClick={() => addUser(user)}
                          className="px-3 py-1 bg-[#f0b90b]/20 text-[#f0b90b] rounded text-sm hover:bg-[#f0b90b]/30"
                        >
                          Add
                        </button>
                      )}
                    </div>
                  );
                })}
              </div>
            )}

            {searchResults.length === 0 && userSearchTerm && !searchingUsers && (
              <p className="text-center text-gray-500 py-4">No users found</p>
            )}

            <div className="flex justify-end pt-2 border-t border-gray-800">
              <button
                onClick={() => setShowUserSearch(false)}
                className="px-4 py-2 bg-gray-800 text-white rounded-lg font-medium hover:bg-gray-700"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {loading ? (
        <div className="text-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b] mx-auto"></div>
          <p className="text-gray-400 mt-4">Loading popup banners...</p>
        </div>
      ) : popups.length === 0 ? (
        <div className="bg-[#0b0e11] rounded-xl border border-gray-800 p-12 text-center">
          <ImageIcon className="w-16 h-16 text-gray-600 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-white mb-2">No Popup Banners</h3>
          <p className="text-gray-400 mb-6">Create your first popup banner to engage users</p>
          <button
            onClick={() => setShowCreateForm(true)}
            className="inline-flex items-center gap-2 px-6 py-3 bg-[#f0b90b] text-black rounded-xl font-medium hover:bg-[#d4a50a] transition-colors"
          >
            <Upload className="w-5 h-5" />
            Create Popup Banner
          </button>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {popups.map((popup) => (
            <div
              key={popup.popup_id}
              className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden hover:border-gray-700 transition-colors"
            >
              <div className="relative aspect-video bg-[#1a1d24]">
                <img
                  src={popup.image_url}
                  alt={popup.title}
                  className="w-full h-full object-cover"
                />
                <div className="absolute top-3 right-3">
                  <span
                    className={`px-3 py-1 rounded-full text-xs font-medium ${
                      popup.is_active
                        ? 'bg-green-500/20 text-green-400 border border-green-500/30'
                        : 'bg-gray-500/20 text-gray-400 border border-gray-500/30'
                    }`}
                  >
                    {popup.is_active ? 'Active' : 'Inactive'}
                  </span>
                </div>
              </div>

              <div className="p-4 space-y-4">
                <div>
                  <h4 className="text-white font-bold mb-1">{popup.title}</h4>
                  <p className="text-gray-500 text-xs">
                    Created {new Date(popup.created_at).toLocaleDateString()}
                  </p>
                </div>

                {popup.target_audiences && popup.target_audiences.length > 0 && (
                  <div className="flex flex-wrap gap-1">
                    {popup.target_audiences.slice(0, 3).map(aud => (
                      <span
                        key={aud}
                        className="px-2 py-0.5 bg-[#1a1d24] text-gray-400 rounded text-xs"
                      >
                        {getAudienceLabel(aud)}
                      </span>
                    ))}
                    {popup.target_audiences.length > 3 && (
                      <span className="px-2 py-0.5 bg-[#1a1d24] text-gray-500 rounded text-xs">
                        +{popup.target_audiences.length - 3} more
                      </span>
                    )}
                    <span className={`px-2 py-0.5 rounded text-xs ${
                      popup.audience_logic === 'AND'
                        ? 'bg-blue-500/20 text-blue-400'
                        : 'bg-green-500/20 text-green-400'
                    }`}>
                      {popup.audience_logic}
                    </span>
                  </div>
                )}

                <div className="grid grid-cols-3 gap-2">
                  <div className="bg-[#1a1d24] rounded-lg p-2 text-center">
                    <div className="flex items-center justify-center gap-1 mb-1">
                      <Users className="w-3 h-3 text-blue-400" />
                    </div>
                    <p className="text-white font-bold text-sm">{popup.unique_viewers}</p>
                    <p className="text-gray-500 text-xs">Viewers</p>
                  </div>
                  <div className="bg-[#1a1d24] rounded-lg p-2 text-center">
                    <div className="flex items-center justify-center gap-1 mb-1">
                      <Target className="w-3 h-3 text-green-400" />
                    </div>
                    <p className="text-white font-bold text-sm">{popup.potential_reach}</p>
                    <p className="text-gray-500 text-xs">Target</p>
                  </div>
                  <div className="bg-[#1a1d24] rounded-lg p-2 text-center">
                    <div className="flex items-center justify-center gap-1 mb-1">
                      <TrendingUp className="w-3 h-3 text-yellow-400" />
                    </div>
                    <p className="text-white font-bold text-sm">
                      {popup.potential_reach > 0
                        ? Math.round((popup.unique_viewers / popup.potential_reach) * 100)
                        : 0}%
                    </p>
                    <p className="text-gray-500 text-xs">Reach</p>
                  </div>
                </div>

                <div className="flex items-center gap-2 pt-2 border-t border-gray-800">
                  <button
                    onClick={() => handleToggleActive(popup.popup_id, popup.is_active)}
                    className={`flex-1 flex items-center justify-center gap-2 px-3 py-2 rounded-lg font-medium transition-colors ${
                      popup.is_active
                        ? 'bg-gray-800 text-gray-300 hover:bg-gray-700'
                        : 'bg-green-500/10 text-green-400 hover:bg-green-500/20 border border-green-500/30'
                    }`}
                  >
                    {popup.is_active ? (
                      <>
                        <EyeOff className="w-4 h-4" />
                        Deactivate
                      </>
                    ) : (
                      <>
                        <Eye className="w-4 h-4" />
                        Activate
                      </>
                    )}
                  </button>
                  <button
                    onClick={() => handleDeletePopup(popup.popup_id)}
                    className="p-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg transition-colors border border-red-500/30"
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
  );
}
