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
  Loader
} from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface PopupBanner {
  popup_id: string;
  title: string;
  image_url: string;
  is_active: boolean;
  created_at: string;
  total_views: number;
  unique_viewers: number;
  view_percentage: number;
}

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

  useEffect(() => {
    loadPopups();
  }, []);

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

      const { error: insertError } = await supabase
        .from('popup_banners')
        .insert({
          title: formData.title.trim(),
          description: formData.description.trim() || null,
          image_url: urlData.publicUrl,
          image_path: filePath,
          created_by: user?.id,
          is_active: true
        });

      if (insertError) {
        await supabase.storage.from('popup-banners').remove([filePath]);
        throw insertError;
      }

      setSuccess('Popup banner created successfully!');
      setShowCreateForm(false);
      setSelectedFile(null);
      setPreviewImage(null);
      setFormData({ title: '', description: '' });
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
    setError(null);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white mb-2">Popup Banners</h2>
          <p className="text-gray-400">Create and manage popup announcements for users</p>
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
        <div className="bg-[#0b0e11] rounded-xl border border-gray-800 p-6 space-y-4">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-bold text-white">Create New Popup Banner</h3>
            <button onClick={resetForm} className="text-gray-400 hover:text-white">
              <X className="w-5 h-5" />
            </button>
          </div>

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
              className="border-2 border-dashed border-gray-700 hover:border-[#f0b90b] rounded-xl p-8 text-center cursor-pointer transition-colors bg-[#1a1d24]"
            >
              {previewImage ? (
                <div className="space-y-4">
                  <img
                    src={previewImage}
                    alt="Preview"
                    className="max-h-64 mx-auto rounded-lg"
                  />
                  <p className="text-gray-400 text-sm">Click to change image</p>
                </div>
              ) : (
                <div className="space-y-3">
                  <Upload className="w-12 h-12 text-gray-500 mx-auto" />
                  <div>
                    <p className="text-white font-medium">Click to upload or drag and drop</p>
                    <p className="text-gray-500 text-sm mt-1">PNG, JPG, GIF up to 5MB</p>
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

          <div className="flex items-center gap-3 pt-4">
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

                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-[#1a1d24] rounded-lg p-3">
                    <div className="flex items-center gap-2 mb-1">
                      <Users className="w-4 h-4 text-blue-400" />
                      <span className="text-gray-400 text-xs">Viewers</span>
                    </div>
                    <p className="text-white font-bold">{popup.unique_viewers}</p>
                  </div>
                  <div className="bg-[#1a1d24] rounded-lg p-3">
                    <div className="flex items-center gap-2 mb-1">
                      <TrendingUp className="w-4 h-4 text-green-400" />
                      <span className="text-gray-400 text-xs">Reach</span>
                    </div>
                    <p className="text-white font-bold">{popup.view_percentage}%</p>
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
