import { useState, useEffect } from 'react';
import { FileText, Plus, Edit2, Trash2, Copy, Eye, X, Check, AlertCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Template {
  id: string;
  name: string;
  content: string;
  variables: string[];
  category: string;
  parse_mode: string;
  is_active: boolean;
  use_count: number;
  created_at: string;
}

interface Props {
  userId: string;
  onSelectTemplate?: (template: Template) => void;
}

const CATEGORIES = ['general', 'announcement', 'promotion', 'alert', 'update', 'newsletter'];
const PARSE_MODES = ['HTML', 'Markdown', 'MarkdownV2', 'None'];

export default function TelegramTemplateManager({ userId, onSelectTemplate }: Props) {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<Template | null>(null);
  const [previewTemplate, setPreviewTemplate] = useState<Template | null>(null);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('all');

  const [formData, setFormData] = useState({
    name: '',
    content: '',
    category: 'general',
    parse_mode: 'HTML',
    is_active: true,
  });

  useEffect(() => {
    fetchTemplates();
  }, [userId]);

  const fetchTemplates = async () => {
    try {
      const { data, error } = await supabase
        .from('telegram_templates')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setTemplates(data || []);
    } catch (err) {
      console.error('Error fetching templates:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!formData.name.trim() || !formData.content.trim()) {
      setError('Name and content are required');
      return;
    }

    try {
      setError('');

      if (editingTemplate) {
        const { error } = await supabase
          .from('telegram_templates')
          .update({
            name: formData.name,
            content: formData.content,
            category: formData.category,
            parse_mode: formData.parse_mode,
            is_active: formData.is_active,
          })
          .eq('id', editingTemplate.id);

        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('telegram_templates')
          .insert({
            created_by: userId,
            name: formData.name,
            content: formData.content,
            category: formData.category,
            parse_mode: formData.parse_mode,
            is_active: formData.is_active,
          });

        if (error) throw error;
      }

      setShowModal(false);
      setEditingTemplate(null);
      resetForm();
      fetchTemplates();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save template');
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this template?')) return;

    try {
      const { error } = await supabase
        .from('telegram_templates')
        .delete()
        .eq('id', id);

      if (error) throw error;
      fetchTemplates();
    } catch (err) {
      console.error('Error deleting template:', err);
    }
  };

  const handleEdit = (template: Template) => {
    setEditingTemplate(template);
    setFormData({
      name: template.name,
      content: template.content,
      category: template.category,
      parse_mode: template.parse_mode,
      is_active: template.is_active,
    });
    setShowModal(true);
  };

  const handleDuplicate = async (template: Template) => {
    try {
      const { error } = await supabase
        .from('telegram_templates')
        .insert({
          created_by: userId,
          name: `${template.name} (Copy)`,
          content: template.content,
          category: template.category,
          parse_mode: template.parse_mode,
          is_active: true,
        });

      if (error) throw error;
      fetchTemplates();
    } catch (err) {
      console.error('Error duplicating template:', err);
    }
  };

  const resetForm = () => {
    setFormData({
      name: '',
      content: '',
      category: 'general',
      parse_mode: 'HTML',
      is_active: true,
    });
  };

  const extractVariables = (content: string): string[] => {
    const matches = content.match(/\{\{(\w+)\}\}/g) || [];
    return [...new Set(matches.map(m => m.replace(/[{}]/g, '')))];
  };

  const filteredTemplates = templates.filter(t =>
    filter === 'all' || t.category === filter
  );

  if (loading) {
    return (
      <div className="bg-[#1a1d21] rounded-lg p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-700 rounded w-1/3"></div>
          <div className="grid grid-cols-2 gap-4">
            {[1, 2, 3, 4].map(i => (
              <div key={i} className="h-32 bg-gray-700 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-[#1a1d21] rounded-lg p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <FileText className="w-6 h-6 text-[#00bcd4]" />
          <h3 className="text-lg font-semibold text-white">Message Templates</h3>
          <span className="text-sm text-gray-400">({templates.length})</span>
        </div>
        <button
          onClick={() => {
            resetForm();
            setEditingTemplate(null);
            setShowModal(true);
          }}
          className="flex items-center gap-2 px-4 py-2 bg-[#00bcd4] text-black font-semibold rounded-lg hover:bg-[#00bcd4]/90 transition-colors"
        >
          <Plus className="w-4 h-4" />
          New Template
        </button>
      </div>

      <div className="flex gap-2 mb-4 overflow-x-auto pb-2">
        <button
          onClick={() => setFilter('all')}
          className={`px-3 py-1.5 rounded-lg text-sm whitespace-nowrap transition-colors ${
            filter === 'all' ? 'bg-[#00bcd4] text-black' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
          }`}
        >
          All
        </button>
        {CATEGORIES.map(cat => (
          <button
            key={cat}
            onClick={() => setFilter(cat)}
            className={`px-3 py-1.5 rounded-lg text-sm capitalize whitespace-nowrap transition-colors ${
              filter === cat ? 'bg-[#00bcd4] text-black' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            {cat}
          </button>
        ))}
      </div>

      {filteredTemplates.length === 0 ? (
        <div className="text-center py-12 text-gray-400">
          <FileText className="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No templates found</p>
          <p className="text-sm mt-1">Create your first template to get started</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredTemplates.map(template => (
            <div
              key={template.id}
              className={`bg-[#0b0e11] rounded-lg p-4 border transition-colors ${
                template.is_active ? 'border-gray-700 hover:border-[#00bcd4]/50' : 'border-gray-800 opacity-60'
              }`}
            >
              <div className="flex items-start justify-between mb-2">
                <div>
                  <h4 className="font-medium text-white">{template.name}</h4>
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-xs px-2 py-0.5 rounded bg-gray-700 text-gray-300 capitalize">
                      {template.category}
                    </span>
                    <span className="text-xs text-gray-500">{template.parse_mode}</span>
                    {!template.is_active && (
                      <span className="text-xs px-2 py-0.5 rounded bg-red-500/20 text-red-400">
                        Inactive
                      </span>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setPreviewTemplate(template)}
                    className="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                    title="Preview"
                  >
                    <Eye className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleEdit(template)}
                    className="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                    title="Edit"
                  >
                    <Edit2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleDuplicate(template)}
                    className="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                    title="Duplicate"
                  >
                    <Copy className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(template.id)}
                    className="p-1.5 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded transition-colors"
                    title="Delete"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>

              <p className="text-sm text-gray-400 line-clamp-2 mb-3">
                {template.content.substring(0, 100)}...
              </p>

              {template.variables && template.variables.length > 0 && (
                <div className="flex flex-wrap gap-1 mb-3">
                  {template.variables.map((v: string) => (
                    <span key={v} className="text-xs px-2 py-0.5 rounded bg-[#00bcd4]/20 text-[#00bcd4]">
                      {`{{${v}}}`}
                    </span>
                  ))}
                </div>
              )}

              <div className="flex items-center justify-between text-xs text-gray-500">
                <span>Used {template.use_count || 0} times</span>
                {onSelectTemplate && (
                  <button
                    onClick={() => onSelectTemplate(template)}
                    className="text-[#00bcd4] hover:underline"
                  >
                    Use Template
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d21] rounded-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-6 border-b border-gray-700">
              <h3 className="text-lg font-semibold text-white">
                {editingTemplate ? 'Edit Template' : 'Create Template'}
              </h3>
              <button
                onClick={() => {
                  setShowModal(false);
                  setEditingTemplate(null);
                  resetForm();
                }}
                className="text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 space-y-4">
              {error && (
                <div className="p-3 bg-red-500/20 border border-red-500/30 rounded-lg flex items-center gap-2 text-red-400 text-sm">
                  <AlertCircle className="w-4 h-4" />
                  {error}
                </div>
              )}

              <div>
                <label className="block text-sm text-gray-400 mb-2">Template Name</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g., Weekly Newsletter"
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Category</label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
                  >
                    {CATEGORIES.map(cat => (
                      <option key={cat} value={cat} className="capitalize">{cat}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Parse Mode</label>
                  <select
                    value={formData.parse_mode}
                    onChange={(e) => setFormData({ ...formData, parse_mode: e.target.value })}
                    className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
                  >
                    {PARSE_MODES.map(mode => (
                      <option key={mode} value={mode}>{mode}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-2">
                  Message Content
                  <span className="text-xs text-gray-500 ml-2">
                    Use {"{{variable}}"} for dynamic content
                  </span>
                </label>
                <textarea
                  value={formData.content}
                  onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                  placeholder={`Example:\n<b>Hello {{name}}!</b>\n\nWelcome to our channel. Today's update:\n{{message}}\n\n<i>Stay tuned for more!</i>`}
                  rows={8}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none font-mono text-sm"
                />
              </div>

              {extractVariables(formData.content).length > 0 && (
                <div className="p-3 bg-[#0b0e11] rounded-lg">
                  <p className="text-xs text-gray-400 mb-2">Detected Variables:</p>
                  <div className="flex flex-wrap gap-2">
                    {extractVariables(formData.content).map(v => (
                      <span key={v} className="text-sm px-2 py-1 rounded bg-[#00bcd4]/20 text-[#00bcd4]">
                        {`{{${v}}}`}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              <label className="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={formData.is_active}
                  onChange={(e) => setFormData({ ...formData, is_active: e.target.checked })}
                  className="sr-only"
                />
                <div className={`w-10 h-6 rounded-full transition-colors ${formData.is_active ? 'bg-[#00bcd4]' : 'bg-gray-600'}`}>
                  <div className={`w-4 h-4 rounded-full bg-white transform transition-transform mt-1 ${formData.is_active ? 'translate-x-5' : 'translate-x-1'}`} />
                </div>
                <span className="text-sm text-gray-300">Template is active</span>
              </label>
            </div>

            <div className="flex gap-3 p-6 border-t border-gray-700">
              <button
                onClick={() => {
                  setShowModal(false);
                  setEditingTemplate(null);
                  resetForm();
                }}
                className="flex-1 px-4 py-3 border border-gray-600 text-gray-300 rounded-lg hover:bg-gray-700 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                className="flex-1 px-4 py-3 bg-[#00bcd4] text-black font-semibold rounded-lg hover:bg-[#00bcd4]/90 transition-colors flex items-center justify-center gap-2"
              >
                <Check className="w-4 h-4" />
                {editingTemplate ? 'Update Template' : 'Create Template'}
              </button>
            </div>
          </div>
        </div>
      )}

      {previewTemplate && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d21] rounded-xl w-full max-w-lg">
            <div className="flex items-center justify-between p-6 border-b border-gray-700">
              <h3 className="text-lg font-semibold text-white">Preview: {previewTemplate.name}</h3>
              <button
                onClick={() => setPreviewTemplate(null)}
                className="text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6">
              <div className="bg-[#0b0e11] rounded-lg p-4 whitespace-pre-wrap text-gray-300 font-mono text-sm">
                {previewTemplate.content}
              </div>
              <div className="mt-4 flex items-center justify-between text-sm text-gray-500">
                <span>Parse Mode: {previewTemplate.parse_mode}</span>
                <span>Category: {previewTemplate.category}</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
