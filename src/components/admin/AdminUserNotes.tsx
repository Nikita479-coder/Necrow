import { useState, useEffect } from 'react';
import { MessageSquare, Plus, Pin, Trash2, AlertTriangle, Info, Clock, Shield } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface Note {
  id: string;
  admin_id: string;
  admin_username?: string;
  note_type: 'general' | 'warning' | 'important' | 'follow_up' | 'support' | 'compliance';
  content: string;
  is_pinned: boolean;
  created_at: string;
  updated_at: string;
}

interface Props {
  userId: string;
}

const NOTE_TYPES = [
  { value: 'general', label: 'General', icon: MessageSquare, color: 'text-gray-400', bg: 'bg-gray-500/10 border-gray-500/30' },
  { value: 'warning', label: 'Warning', icon: AlertTriangle, color: 'text-yellow-400', bg: 'bg-yellow-500/10 border-yellow-500/30' },
  { value: 'important', label: 'Important', icon: Info, color: 'text-red-400', bg: 'bg-red-500/10 border-red-500/30' },
  { value: 'follow_up', label: 'Follow Up', icon: Clock, color: 'text-blue-400', bg: 'bg-blue-500/10 border-blue-500/30' },
  { value: 'support', label: 'Support', icon: MessageSquare, color: 'text-green-400', bg: 'bg-green-500/10 border-green-500/30' },
  { value: 'compliance', label: 'Compliance', icon: Shield, color: 'text-orange-400', bg: 'bg-orange-500/10 border-orange-500/30' },
];

export default function AdminUserNotes({ userId }: Props) {
  const { user } = useAuth();
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddNote, setShowAddNote] = useState(false);
  const [newNote, setNewNote] = useState({ content: '', note_type: 'general' as Note['note_type'] });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadNotes();
  }, [userId]);

  const loadNotes = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('user_notes')
        .select('*')
        .eq('user_id', userId)
        .order('is_pinned', { ascending: false })
        .order('created_at', { ascending: false });

      if (error) throw error;

      const notesWithAdmins = await Promise.all(
        (data || []).map(async (note) => {
          const { data: profile } = await supabase
            .from('user_profiles')
            .select('username')
            .eq('id', note.admin_id)
            .single();
          return { ...note, admin_username: profile?.username || 'Unknown Admin' };
        })
      );

      setNotes(notesWithAdmins);
    } catch (error) {
      console.error('Error loading notes:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddNote = async () => {
    if (!newNote.content.trim() || !user) return;

    setSaving(true);
    try {
      const { error } = await supabase
        .from('user_notes')
        .insert({
          user_id: userId,
          admin_id: user.id,
          note_type: newNote.note_type,
          content: newNote.content.trim(),
        });

      if (error) throw error;

      setNewNote({ content: '', note_type: 'general' });
      setShowAddNote(false);
      loadNotes();
    } catch (error) {
      console.error('Error adding note:', error);
    } finally {
      setSaving(false);
    }
  };

  const handleTogglePin = async (noteId: string, currentlyPinned: boolean) => {
    try {
      const { error } = await supabase
        .from('user_notes')
        .update({ is_pinned: !currentlyPinned })
        .eq('id', noteId);

      if (error) throw error;
      loadNotes();
    } catch (error) {
      console.error('Error toggling pin:', error);
    }
  };

  const handleDeleteNote = async (noteId: string) => {
    if (!confirm('Are you sure you want to delete this note?')) return;

    try {
      const { error } = await supabase
        .from('user_notes')
        .delete()
        .eq('id', noteId);

      if (error) throw error;
      loadNotes();
    } catch (error) {
      console.error('Error deleting note:', error);
    }
  };

  const getNoteTypeConfig = (type: Note['note_type']) => {
    return NOTE_TYPES.find(t => t.value === type) || NOTE_TYPES[0];
  };

  if (loading) {
    return (
      <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-700 rounded w-1/3"></div>
          <div className="h-20 bg-gray-700 rounded"></div>
          <div className="h-20 bg-gray-700 rounded"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <MessageSquare className="w-5 h-5 text-[#f0b90b]" />
          <h3 className="text-lg font-bold text-white">Internal Notes</h3>
          <span className="px-2 py-0.5 bg-gray-700 rounded-full text-xs text-gray-300">
            {notes.length}
          </span>
        </div>
        <button
          onClick={() => setShowAddNote(!showAddNote)}
          className="flex items-center gap-2 px-3 py-2 bg-[#f0b90b] hover:bg-[#d4a50a] text-black rounded-lg font-medium transition-colors text-sm"
        >
          <Plus className="w-4 h-4" />
          Add Note
        </button>
      </div>

      {showAddNote && (
        <div className="mb-6 p-4 bg-[#1a1d24] rounded-xl border border-gray-700">
          <div className="flex flex-wrap gap-2 mb-3">
            {NOTE_TYPES.map((type) => (
              <button
                key={type.value}
                onClick={() => setNewNote({ ...newNote, note_type: type.value as Note['note_type'] })}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
                  newNote.note_type === type.value
                    ? `${type.bg} ${type.color}`
                    : 'bg-gray-800 text-gray-400 border-gray-700 hover:border-gray-600'
                }`}
              >
                <type.icon className="w-3.5 h-3.5" />
                {type.label}
              </button>
            ))}
          </div>
          <textarea
            value={newNote.content}
            onChange={(e) => setNewNote({ ...newNote, content: e.target.value })}
            placeholder="Enter your note..."
            rows={3}
            className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 outline-none focus:border-[#f0b90b] transition-colors resize-none"
          />
          <div className="flex justify-end gap-2 mt-3">
            <button
              onClick={() => {
                setShowAddNote(false);
                setNewNote({ content: '', note_type: 'general' });
              }}
              className="px-4 py-2 text-gray-400 hover:text-white transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleAddNote}
              disabled={!newNote.content.trim() || saving}
              className="px-4 py-2 bg-[#f0b90b] hover:bg-[#d4a50a] text-black rounded-lg font-medium transition-colors disabled:opacity-50"
            >
              {saving ? 'Saving...' : 'Save Note'}
            </button>
          </div>
        </div>
      )}

      {notes.length === 0 ? (
        <div className="text-center py-8">
          <MessageSquare className="w-12 h-12 text-gray-600 mx-auto mb-3" />
          <p className="text-gray-400">No notes yet</p>
          <p className="text-gray-500 text-sm">Add internal notes about this user for your team</p>
        </div>
      ) : (
        <div className="space-y-3">
          {notes.map((note) => {
            const typeConfig = getNoteTypeConfig(note.note_type);
            return (
              <div
                key={note.id}
                className={`p-4 rounded-xl border ${typeConfig.bg} relative group`}
              >
                {note.is_pinned && (
                  <div className="absolute -top-2 -right-2 bg-[#f0b90b] rounded-full p-1">
                    <Pin className="w-3 h-3 text-black" />
                  </div>
                )}
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-2">
                      <typeConfig.icon className={`w-4 h-4 ${typeConfig.color}`} />
                      <span className={`text-xs font-medium ${typeConfig.color}`}>
                        {typeConfig.label}
                      </span>
                      <span className="text-gray-500 text-xs">
                        by {note.admin_username}
                      </span>
                      <span className="text-gray-600 text-xs">
                        {new Date(note.created_at).toLocaleString()}
                      </span>
                    </div>
                    <p className="text-gray-200 whitespace-pre-wrap">{note.content}</p>
                  </div>
                  <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      onClick={() => handleTogglePin(note.id, note.is_pinned)}
                      className={`p-1.5 rounded-lg transition-colors ${
                        note.is_pinned
                          ? 'bg-[#f0b90b]/20 text-[#f0b90b]'
                          : 'hover:bg-gray-700 text-gray-400'
                      }`}
                      title={note.is_pinned ? 'Unpin' : 'Pin'}
                    >
                      <Pin className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDeleteNote(note.id)}
                      className="p-1.5 hover:bg-red-500/20 text-gray-400 hover:text-red-400 rounded-lg transition-colors"
                      title="Delete"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
