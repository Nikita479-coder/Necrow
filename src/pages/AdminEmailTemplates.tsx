import { useState, useEffect } from 'react';
import { ArrowLeft, Plus, Edit2, Trash2, Mail, Eye, Search, Send, X, Users, Check, Filter, Code, Monitor } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { useToast } from '../hooks/useToast';
import Navbar from '../components/Navbar';

const CATEGORIES = [
  { value: 'trading', label: 'Trading', color: 'bg-orange-500/10 text-orange-400 border-orange-500/30' },
  { value: 'copy_trading', label: 'Copy Trading', color: 'bg-purple-500/10 text-purple-400 border-purple-500/30' },
  { value: 'account', label: 'Account', color: 'bg-blue-500/10 text-blue-400 border-blue-500/30' },
  { value: 'financial', label: 'Financial', color: 'bg-green-500/10 text-green-400 border-green-500/30' },
  { value: 'shark_card', label: 'Shark Card', color: 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30' },
  { value: 'vip', label: 'VIP', color: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30' },
  { value: 'system', label: 'System', color: 'bg-gray-500/10 text-gray-400 border-gray-500/30' },
  { value: 'welcome', label: 'Welcome', color: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30' },
  { value: 'kyc', label: 'KYC', color: 'bg-indigo-500/10 text-indigo-400 border-indigo-500/30' },
  { value: 'bonus', label: 'Bonus', color: 'bg-pink-500/10 text-pink-400 border-pink-500/30' },
  { value: 'promotion', label: 'Promotion', color: 'bg-rose-500/10 text-rose-400 border-rose-500/30' },
  { value: 'alert', label: 'Alert', color: 'bg-red-500/10 text-red-400 border-red-500/30' },
  { value: 'general', label: 'General', color: 'bg-slate-500/10 text-slate-400 border-slate-500/30' },
];

interface EmailTemplate {
  id: string;
  name: string;
  subject: string;
  body: string;
  category: string;
  is_active: boolean;
  created_at: string;
}

interface User {
  id: string;
  email: string;
  username: string;
  full_name: string;
}

export default function AdminEmailTemplates() {
  const { user, loading: authLoading } = useAuth();
  const { navigateTo } = useNavigation();
  const { showToast } = useToast();
  const [templates, setTemplates] = useState<EmailTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');
  const [showModal, setShowModal] = useState(false);
  const [showPreviewModal, setShowPreviewModal] = useState(false);
  const [showSendModal, setShowSendModal] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<EmailTemplate | null>(null);
  const [previewTemplate, setPreviewTemplate] = useState<EmailTemplate | null>(null);
  const [sendingTemplate, setSendingTemplate] = useState<EmailTemplate | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [users, setUsers] = useState<User[]>([]);
  const [userSearchTerm, setUserSearchTerm] = useState('');
  const [selectedUsers, setSelectedUsers] = useState<Set<string>>(new Set());
  const [sending, setSending] = useState(false);
  const [previewMode, setPreviewMode] = useState<'html' | 'code'>('html');

  const [formData, setFormData] = useState({
    name: '',
    subject: '',
    body: '',
    category: 'general',
    is_active: true,
  });

  useEffect(() => {
    if (authLoading) return;
    checkAdminAndLoadTemplates();
  }, [user, authLoading]);

  useEffect(() => {
    if (showSendModal) {
      loadUsers();
    }
  }, [userSearchTerm]);

  const checkAdminAndLoadTemplates = async () => {
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
    await loadTemplates();
  };

  const loadTemplates = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('email_templates')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setTemplates(data || []);
    } catch (error: any) {
      showToast('Failed to load templates: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      if (editingTemplate) {
        const { error } = await supabase
          .from('email_templates')
          .update({
            ...formData,
            updated_at: new Date().toISOString(),
          })
          .eq('id', editingTemplate.id);

        if (error) throw error;
        showToast('Template updated successfully', 'success');
      } else {
        const { error } = await supabase
          .from('email_templates')
          .insert({
            ...formData,
            created_by: user!.id,
          });

        if (error) throw error;
        showToast('Template created successfully', 'success');
      }

      setShowModal(false);
      setEditingTemplate(null);
      resetForm();
      await loadTemplates();
    } catch (error: any) {
      showToast('Failed to save template: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (template: EmailTemplate) => {
    setEditingTemplate(template);
    setFormData({
      name: template.name,
      subject: template.subject,
      body: template.body,
      category: template.category,
      is_active: template.is_active,
    });
    setShowModal(true);
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this template?')) return;

    try {
      const { error } = await supabase
        .from('email_templates')
        .delete()
        .eq('id', id);

      if (error) throw error;
      showToast('Template deleted successfully', 'success');
      await loadTemplates();
    } catch (error: any) {
      showToast('Failed to delete template: ' + error.message, 'error');
    }
  };

  const handlePreview = (template: EmailTemplate) => {
    setPreviewTemplate(template);
    setShowPreviewModal(true);
  };

  const resetForm = () => {
    setFormData({
      name: '',
      subject: '',
      body: '',
      category: 'general',
      is_active: true,
    });
  };

  const loadUsers = async () => {
    try {
      const { data, error } = await supabase.rpc('admin_list_all_users', {
        p_search: userSearchTerm || null,
        p_limit: 50,
        p_offset: 0
      });

      if (error) {
        console.error('Failed to load users:', error);
        showToast('Failed to load users: ' + error.message, 'error');
        setUsers([]);
        return;
      }

      const usersList = (data || []).map((u: any) => ({
        id: u.user_id,
        email: u.email,
        username: u.username,
        full_name: u.full_name || u.username
      }));

      setUsers(usersList);
    } catch (error: any) {
      console.error('Failed to load users:', error);
      showToast('Failed to load users: ' + error.message, 'error');
      setUsers([]);
    }
  };

  const handleSend = (template: EmailTemplate) => {
    setSendingTemplate(template);
    setShowSendModal(true);
    loadUsers();
  };

  const toggleUserSelection = (userId: string) => {
    setSelectedUsers(prev => {
      const next = new Set(prev);
      if (next.has(userId)) {
        next.delete(userId);
      } else {
        next.add(userId);
      }
      return next;
    });
  };

  const selectAllUsers = () => {
    setSelectedUsers(new Set(users.map(u => u.id)));
  };

  const deselectAllUsers = () => {
    setSelectedUsers(new Set());
  };

  const handleSendToUsers = async () => {
    if (selectedUsers.size === 0) {
      showToast('Please select at least one user', 'error');
      return;
    }

    if (!sendingTemplate) return;

    if (!confirm(`Send "${sendingTemplate.name}" to ${selectedUsers.size} user(s)?`)) {
      return;
    }

    setSending(true);
    let successCount = 0;
    let failCount = 0;

    try {
      const session = await supabase.auth.getSession();
      const token = session.data.session?.access_token;

      if (!token) {
        throw new Error('Not authenticated');
      }

      const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-email`;

      for (const userId of Array.from(selectedUsers)) {
        try {
          const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              user_id: userId,
              template_id: sendingTemplate.id,
              subject: sendingTemplate.subject,
              body: sendingTemplate.body,
            }),
          });

          const result = await response.json();

          if (response.ok && result.success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (error) {
          console.error(`Failed to send to user ${userId}:`, error);
          failCount++;
        }
      }

      if (successCount > 0) {
        showToast(`Successfully sent ${successCount} email(s)!`, 'success');
      }

      if (failCount > 0) {
        showToast(`Failed to send ${failCount} email(s)`, 'error');
      }

      setShowSendModal(false);
      setSendingTemplate(null);
      setSelectedUsers(new Set());
      setUserSearchTerm('');
    } catch (error: any) {
      showToast('Failed to send emails: ' + error.message, 'error');
    } finally {
      setSending(false);
    }
  };

  const filteredTemplates = templates.filter(t => {
    const matchesSearch = t.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      t.subject.toLowerCase().includes(searchTerm.toLowerCase()) ||
      t.category.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || t.category === categoryFilter;
    return matchesSearch && matchesCategory;
  });

  const getCategoryColor = (category: string) => {
    const found = CATEGORIES.find(c => c.value === category);
    return found?.color || 'bg-gray-500/10 text-gray-400 border-gray-500/30';
  };

  const getCategoryLabel = (category: string) => {
    const found = CATEGORIES.find(c => c.value === category);
    return found?.label || category;
  };

  const templatesByCategory = templates.reduce((acc, t) => {
    acc[t.category] = (acc[t.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

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
              <h1 className="text-3xl font-bold text-white mb-2">Email Templates</h1>
              <p className="text-gray-400">Create and manage email templates for user communications</p>
            </div>
            <button
              onClick={() => {
                resetForm();
                setEditingTemplate(null);
                setShowModal(true);
              }}
              className="flex items-center gap-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black px-6 py-3 rounded-lg font-bold transition-all"
            >
              <Plus className="w-5 h-5" />
              New Template
            </button>
          </div>

          <div className="flex gap-4 mb-6">
            <div className="relative flex-1">
              <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <input
                type="text"
                placeholder="Search templates..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full bg-[#1a1d24] border border-gray-800 rounded-xl pl-12 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors"
              />
            </div>
            <div className="relative">
              <Filter className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="bg-[#1a1d24] border border-gray-800 rounded-xl pl-12 pr-8 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors appearance-none cursor-pointer min-w-[200px]"
              >
                <option value="all">All Categories ({templates.length})</option>
                {CATEGORIES.map(cat => (
                  templatesByCategory[cat.value] ? (
                    <option key={cat.value} value={cat.value}>
                      {cat.label} ({templatesByCategory[cat.value]})
                    </option>
                  ) : null
                ))}
              </select>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20">
            <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-[#f0b90b]"></div>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredTemplates.map((template) => (
              <div
                key={template.id}
                className="bg-[#1a1d24] rounded-xl p-6 border border-gray-800 hover:border-gray-700 transition-colors"
              >
                <div className="flex items-start justify-between mb-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-2">
                      <Mail className="w-5 h-5 text-[#f0b90b]" />
                      <h3 className="text-lg font-bold text-white">{template.name}</h3>
                    </div>
                    <span className={`inline-flex items-center px-2 py-1 rounded-lg border text-xs font-medium ${getCategoryColor(template.category)}`}>
                      {getCategoryLabel(template.category)}
                    </span>
                  </div>
                  <div className={`w-3 h-3 rounded-full ${template.is_active ? 'bg-green-400' : 'bg-gray-600'}`}></div>
                </div>

                <div className="mb-4">
                  <p className="text-sm text-gray-400 mb-2">Subject:</p>
                  <p className="text-white text-sm line-clamp-2">{template.subject}</p>
                </div>

                <div className="mb-4">
                  <p className="text-sm text-gray-400 mb-2">Preview:</p>
                  <p className="text-gray-300 text-sm line-clamp-3">{template.body.replace(/<[^>]*>/g, '')}</p>
                </div>

                <div className="space-y-2">
                  <button
                    onClick={() => handleSend(template)}
                    className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-medium transition-colors text-sm"
                  >
                    <Send className="w-4 h-4" />
                    Send to Users
                  </button>
                  <div className="flex gap-2">
                    <button
                      onClick={() => handlePreview(template)}
                      className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors text-sm"
                    >
                      <Eye className="w-4 h-4" />
                      Preview
                    </button>
                    <button
                      onClick={() => handleEdit(template)}
                      className="flex items-center justify-center gap-2 px-4 py-2 bg-gray-500/10 hover:bg-gray-500/20 text-gray-400 rounded-lg border border-gray-500/30 transition-colors text-sm"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDelete(template.id)}
                      className="flex items-center justify-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 transition-colors text-sm"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}

            {filteredTemplates.length === 0 && (
              <div className="col-span-full text-center py-20">
                <Mail className="w-16 h-16 text-gray-600 mx-auto mb-4" />
                <p className="text-gray-400">No templates found</p>
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
                {editingTemplate ? 'Edit Template' : 'Create Template'}
              </h2>
            </div>

            <form onSubmit={handleSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Template Name</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                  placeholder="Welcome Email"
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
                  {CATEGORIES.map(cat => (
                    <option key={cat.value} value={cat.value}>{cat.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Email Subject</label>
                <input
                  type="text"
                  value={formData.subject}
                  onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
                  placeholder="Welcome to {{platform_name}}"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Email Body</label>
                <textarea
                  value={formData.body}
                  onChange={(e) => setFormData({ ...formData, body: e.target.value })}
                  rows={10}
                  className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors font-mono text-sm"
                  placeholder="Hello {{username}},&#10;&#10;Welcome to our platform..."
                  required
                />
                <p className="text-xs text-gray-500 mt-2">
                  Available variables: {'{{username}}'}, {'{{email}}'}, {'{{full_name}}'}, {'{{balance}}'}, {'{{kyc_level}}'}, {'{{platform_name}}'}, {'{{support_email}}'}
                </p>
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
                  Template is active
                </label>
              </div>

              <div className="flex gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false);
                    setEditingTemplate(null);
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
                  {editingTemplate ? 'Update' : 'Create'} Template
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showPreviewModal && previewTemplate && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
            <div className="p-6 border-b border-gray-800 flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-bold text-white mb-2">Preview: {previewTemplate.name}</h2>
                <span className={`inline-flex items-center px-3 py-1 rounded-lg border text-sm font-medium ${getCategoryColor(previewTemplate.category)}`}>
                  {getCategoryLabel(previewTemplate.category)}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setPreviewMode('html')}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-colors text-sm font-medium ${
                    previewMode === 'html'
                      ? 'bg-[#f0b90b] text-black'
                      : 'bg-gray-500/10 text-gray-400 hover:bg-gray-500/20'
                  }`}
                >
                  <Monitor className="w-4 h-4" />
                  Preview
                </button>
                <button
                  onClick={() => setPreviewMode('code')}
                  className={`flex items-center gap-2 px-4 py-2 rounded-lg transition-colors text-sm font-medium ${
                    previewMode === 'code'
                      ? 'bg-[#f0b90b] text-black'
                      : 'bg-gray-500/10 text-gray-400 hover:bg-gray-500/20'
                  }`}
                >
                  <Code className="w-4 h-4" />
                  Code
                </button>
              </div>
            </div>

            <div className="p-6 space-y-4 overflow-y-auto flex-1">
              <div>
                <p className="text-sm font-medium text-gray-400 mb-2">Subject:</p>
                <p className="text-white bg-[#0b0e11] rounded-lg p-4">{previewTemplate.subject}</p>
              </div>

              <div>
                <p className="text-sm font-medium text-gray-400 mb-2">Body:</p>
                {previewMode === 'html' ? (
                  <div className="bg-white rounded-lg overflow-hidden">
                    <iframe
                      srcDoc={previewTemplate.body}
                      className="w-full h-[500px] border-0"
                      title="Email Preview"
                      sandbox="allow-same-origin"
                    />
                  </div>
                ) : (
                  <div className="text-gray-300 bg-[#0b0e11] rounded-lg p-4 whitespace-pre-wrap font-mono text-xs overflow-x-auto max-h-[500px]">
                    {previewTemplate.body}
                  </div>
                )}
              </div>
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => {
                  setShowPreviewModal(false);
                  setPreviewMode('html');
                }}
                className="flex-1 px-6 py-3 bg-gray-500/10 hover:bg-gray-500/20 text-gray-400 rounded-lg border border-gray-500/30 transition-colors font-medium"
              >
                Close
              </button>
              <button
                onClick={() => {
                  setShowPreviewModal(false);
                  handleEdit(previewTemplate);
                }}
                className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-bold transition-colors"
              >
                <Edit2 className="w-5 h-5" />
                Edit Template
              </button>
            </div>
          </div>
        </div>
      )}

      {showSendModal && sendingTemplate && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d24] rounded-xl border border-gray-800 max-w-3xl w-full max-h-[90vh] overflow-hidden flex flex-col">
            <div className="p-6 border-b border-gray-800 flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-bold text-white mb-1">Send Email Template</h2>
                <p className="text-gray-400 text-sm">{sendingTemplate.name}</p>
              </div>
              <button
                onClick={() => {
                  setShowSendModal(false);
                  setSendingTemplate(null);
                  setSelectedUsers(new Set());
                  setUserSearchTerm('');
                }}
                className="text-gray-400 hover:text-white transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <div className="p-6 space-y-4 overflow-y-auto flex-1">
              <div className="bg-[#0b0e11] rounded-lg p-4 border border-gray-800">
                <p className="text-sm font-medium text-gray-400 mb-2">Subject:</p>
                <p className="text-white mb-4">{sendingTemplate.subject}</p>
                <p className="text-sm font-medium text-gray-400 mb-2">Preview:</p>
                <p className="text-gray-300 text-sm line-clamp-3">{sendingTemplate.body.replace(/<[^>]*>/g, '')}</p>
              </div>

              <div>
                <div className="flex items-center justify-between mb-3">
                  <label className="text-sm font-medium text-white flex items-center gap-2">
                    <Users className="w-4 h-4" />
                    Select Recipients ({selectedUsers.size} selected)
                  </label>
                  <div className="flex gap-2">
                    <button
                      onClick={selectAllUsers}
                      className="text-xs text-blue-400 hover:text-blue-300 transition-colors"
                    >
                      Select All
                    </button>
                    <span className="text-gray-600">|</span>
                    <button
                      onClick={deselectAllUsers}
                      className="text-xs text-gray-400 hover:text-gray-300 transition-colors"
                    >
                      Deselect All
                    </button>
                  </div>
                </div>

                <div className="relative mb-3">
                  <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    placeholder="Search users by email or username..."
                    value={userSearchTerm}
                    onChange={(e) => setUserSearchTerm(e.target.value)}
                    className="w-full bg-[#0b0e11] border border-gray-800 rounded-lg pl-11 pr-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors text-sm"
                  />
                </div>

                <div className="bg-[#0b0e11] rounded-lg border border-gray-800 max-h-[300px] overflow-y-auto">
                  {users.length === 0 ? (
                    <div className="p-8 text-center">
                      <Users className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                      <p className="text-gray-400">No users found</p>
                    </div>
                  ) : (
                    <div className="divide-y divide-gray-800">
                      {users.map((u) => (
                        <div
                          key={u.id}
                          onClick={() => toggleUserSelection(u.id)}
                          className="p-4 hover:bg-[#1a1d24] cursor-pointer transition-colors flex items-center justify-between"
                        >
                          <div className="flex-1">
                            <p className="text-white font-medium text-sm">{u.full_name}</p>
                            <p className="text-gray-400 text-xs">{u.email}</p>
                          </div>
                          <div className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-colors ${
                            selectedUsers.has(u.id)
                              ? 'bg-[#f0b90b] border-[#f0b90b]'
                              : 'border-gray-600'
                          }`}>
                            {selectedUsers.has(u.id) && (
                              <Check className="w-3 h-3 text-black" />
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>

            <div className="p-6 border-t border-gray-800 flex gap-3">
              <button
                onClick={() => {
                  setShowSendModal(false);
                  setSendingTemplate(null);
                  setSelectedUsers(new Set());
                  setUserSearchTerm('');
                }}
                disabled={sending}
                className="flex-1 px-6 py-3 bg-gray-500/10 hover:bg-gray-500/20 text-gray-400 rounded-lg border border-gray-500/30 transition-colors font-medium disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSendToUsers}
                disabled={sending || selectedUsers.size === 0}
                className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-bold transition-colors disabled:opacity-50"
              >
                <Send className="w-5 h-5" />
                {sending ? `Sending... (${selectedUsers.size})` : `Send to ${selectedUsers.size} User(s)`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
