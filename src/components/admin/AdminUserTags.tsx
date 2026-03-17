import { useState, useEffect } from 'react';
import { Tag, Plus, X, Check } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface UserTag {
  id: string;
  name: string;
  color: string;
  description: string | null;
}

interface TagAssignment {
  tag_id: string;
  tag: UserTag;
  assigned_at: string;
}

interface Props {
  userId: string;
  compact?: boolean;
}

export default function AdminUserTags({ userId, compact = false }: Props) {
  const { user } = useAuth();
  const [assignedTags, setAssignedTags] = useState<TagAssignment[]>([]);
  const [availableTags, setAvailableTags] = useState<UserTag[]>([]);
  const [loading, setLoading] = useState(true);
  const [showTagSelector, setShowTagSelector] = useState(false);
  const [saving, setSaving] = useState<string | null>(null);

  useEffect(() => {
    loadTags();
  }, [userId]);

  const loadTags = async () => {
    setLoading(true);
    try {
      const { data: assigned } = await supabase
        .from('user_tag_assignments')
        .select('tag_id, assigned_at, tag:user_tags(*)')
        .eq('user_id', userId);

      const { data: allTags } = await supabase
        .from('user_tags')
        .select('*')
        .order('name');

      setAssignedTags(assigned || []);

      const assignedIds = new Set((assigned || []).map(a => a.tag_id));
      setAvailableTags((allTags || []).filter(t => !assignedIds.has(t.id)));
    } catch (error) {
      console.error('Error loading tags:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddTag = async (tagId: string) => {
    if (!user) return;
    setSaving(tagId);
    try {
      const { error } = await supabase
        .from('user_tag_assignments')
        .insert({
          user_id: userId,
          tag_id: tagId,
          assigned_by: user.id,
        });

      if (error) throw error;
      loadTags();
      setShowTagSelector(false);
    } catch (error) {
      console.error('Error adding tag:', error);
    } finally {
      setSaving(null);
    }
  };

  const handleRemoveTag = async (tagId: string) => {
    setSaving(tagId);
    try {
      const { error } = await supabase
        .from('user_tag_assignments')
        .delete()
        .eq('user_id', userId)
        .eq('tag_id', tagId);

      if (error) throw error;
      loadTags();
    } catch (error) {
      console.error('Error removing tag:', error);
    } finally {
      setSaving(null);
    }
  };

  if (loading) {
    return (
      <div className="flex gap-2">
        <div className="h-6 w-16 bg-gray-700 rounded-full animate-pulse"></div>
        <div className="h-6 w-20 bg-gray-700 rounded-full animate-pulse"></div>
      </div>
    );
  }

  if (compact) {
    return (
      <div className="flex flex-wrap gap-1.5">
        {assignedTags.map(({ tag }) => (
          <span
            key={tag.id}
            className="px-2 py-0.5 rounded-full text-xs font-medium"
            style={{ backgroundColor: `${tag.color}20`, color: tag.color, border: `1px solid ${tag.color}40` }}
          >
            {tag.name}
          </span>
        ))}
        {assignedTags.length === 0 && (
          <span className="text-gray-500 text-xs">No tags</span>
        )}
      </div>
    );
  }

  return (
    <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <Tag className="w-5 h-5 text-[#f0b90b]" />
          <h3 className="text-lg font-bold text-white">User Tags</h3>
        </div>
        <button
          onClick={() => setShowTagSelector(!showTagSelector)}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-[#f0b90b] hover:bg-[#d4a50a] text-black rounded-lg font-medium transition-colors text-sm"
        >
          <Plus className="w-4 h-4" />
          Add Tag
        </button>
      </div>

      {showTagSelector && availableTags.length > 0 && (
        <div className="mb-4 p-3 bg-[#1a1d24] rounded-xl border border-gray-700">
          <p className="text-sm text-gray-400 mb-2">Select a tag to add:</p>
          <div className="flex flex-wrap gap-2">
            {availableTags.map((tag) => (
              <button
                key={tag.id}
                onClick={() => handleAddTag(tag.id)}
                disabled={saving === tag.id}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-all hover:scale-105 disabled:opacity-50"
                style={{ backgroundColor: `${tag.color}20`, color: tag.color, border: `1px solid ${tag.color}40` }}
              >
                {saving === tag.id ? (
                  <div className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin" />
                ) : (
                  <Plus className="w-3.5 h-3.5" />
                )}
                {tag.name}
              </button>
            ))}
          </div>
        </div>
      )}

      {showTagSelector && availableTags.length === 0 && (
        <div className="mb-4 p-3 bg-[#1a1d24] rounded-xl border border-gray-700 text-center">
          <Check className="w-6 h-6 text-green-400 mx-auto mb-2" />
          <p className="text-sm text-gray-400">All available tags have been assigned</p>
        </div>
      )}

      <div className="flex flex-wrap gap-2">
        {assignedTags.map(({ tag, assigned_at }) => (
          <div
            key={tag.id}
            className="group flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-all"
            style={{ backgroundColor: `${tag.color}15`, color: tag.color, border: `1px solid ${tag.color}30` }}
          >
            <Tag className="w-3.5 h-3.5" />
            <span>{tag.name}</span>
            <button
              onClick={() => handleRemoveTag(tag.id)}
              disabled={saving === tag.id}
              className="opacity-0 group-hover:opacity-100 p-0.5 hover:bg-black/20 rounded transition-all disabled:opacity-50"
              title="Remove tag"
            >
              {saving === tag.id ? (
                <div className="w-3.5 h-3.5 border-2 border-current border-t-transparent rounded-full animate-spin" />
              ) : (
                <X className="w-3.5 h-3.5" />
              )}
            </button>
          </div>
        ))}
        {assignedTags.length === 0 && (
          <div className="text-center py-4 w-full">
            <Tag className="w-8 h-8 text-gray-600 mx-auto mb-2" />
            <p className="text-gray-400 text-sm">No tags assigned</p>
          </div>
        )}
      </div>
    </div>
  );
}
