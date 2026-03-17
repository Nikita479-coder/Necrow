import { useState, useEffect } from 'react';
import { Clock, CheckCircle, XCircle, AlertCircle, RefreshCw, Trash2, Eye, X, Play, Pause } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface ScheduledMessage {
  id: string;
  template_id: string | null;
  final_content: string;
  channel_username: string;
  scheduled_for: string;
  status: string;
  priority: number;
  attempts: number;
  max_attempts: number;
  sent_at: string | null;
  error_message: string | null;
  telegram_message_id: string | null;
  created_at: string;
  template?: {
    name: string;
  };
}

interface Props {
  userId: string;
}

export default function TelegramMessageQueue({ userId }: Props) {
  const [messages, setMessages] = useState<ScheduledMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'pending' | 'sent' | 'failed'>('all');
  const [selectedMessage, setSelectedMessage] = useState<ScheduledMessage | null>(null);

  useEffect(() => {
    fetchMessages();
    const interval = setInterval(fetchMessages, 30000);
    return () => clearInterval(interval);
  }, [userId]);

  const fetchMessages = async () => {
    try {
      const { data, error } = await supabase
        .from('telegram_scheduled_messages')
        .select(`
          *,
          template:telegram_templates(name)
        `)
        .order('scheduled_for', { ascending: false })
        .limit(100);

      if (error) throw error;
      setMessages(data || []);
    } catch (err) {
      console.error('Error fetching messages:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleCancel = async (id: string) => {
    if (!confirm('Cancel this scheduled message?')) return;

    try {
      const { error } = await supabase
        .from('telegram_scheduled_messages')
        .update({ status: 'cancelled' })
        .eq('id', id)
        .eq('status', 'pending');

      if (error) throw error;
      fetchMessages();
    } catch (err) {
      console.error('Error cancelling message:', err);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this message from history?')) return;

    try {
      const { error } = await supabase
        .from('telegram_scheduled_messages')
        .delete()
        .eq('id', id);

      if (error) throw error;
      fetchMessages();
    } catch (err) {
      console.error('Error deleting message:', err);
    }
  };

  const handleRetry = async (id: string) => {
    try {
      const { error } = await supabase
        .from('telegram_scheduled_messages')
        .update({
          status: 'pending',
          attempts: 0,
          error_message: null,
          scheduled_for: new Date().toISOString(),
        })
        .eq('id', id);

      if (error) throw error;
      fetchMessages();
    } catch (err) {
      console.error('Error retrying message:', err);
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'pending':
        return <Clock className="w-4 h-4 text-yellow-400" />;
      case 'processing':
        return <RefreshCw className="w-4 h-4 text-blue-400 animate-spin" />;
      case 'sent':
        return <CheckCircle className="w-4 h-4 text-green-400" />;
      case 'failed':
        return <XCircle className="w-4 h-4 text-red-400" />;
      case 'cancelled':
        return <Pause className="w-4 h-4 text-gray-400" />;
      default:
        return <AlertCircle className="w-4 h-4 text-gray-400" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending':
        return 'bg-yellow-500/20 text-yellow-400';
      case 'processing':
        return 'bg-blue-500/20 text-blue-400';
      case 'sent':
        return 'bg-green-500/20 text-green-400';
      case 'failed':
        return 'bg-red-500/20 text-red-400';
      case 'cancelled':
        return 'bg-gray-500/20 text-gray-400';
      default:
        return 'bg-gray-500/20 text-gray-400';
    }
  };

  const filteredMessages = messages.filter(m =>
    filter === 'all' || m.status === filter
  );

  const stats = {
    pending: messages.filter(m => m.status === 'pending').length,
    processing: messages.filter(m => m.status === 'processing').length,
    sent: messages.filter(m => m.status === 'sent').length,
    failed: messages.filter(m => m.status === 'failed').length,
  };

  if (loading) {
    return (
      <div className="bg-[#1a1d21] rounded-lg p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-700 rounded w-1/3"></div>
          <div className="space-y-3">
            {[1, 2, 3].map(i => (
              <div key={i} className="h-20 bg-gray-700 rounded"></div>
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
          <Clock className="w-6 h-6 text-[#00bcd4]" />
          <h3 className="text-lg font-semibold text-white">Message Queue</h3>
        </div>
        <button
          onClick={fetchMessages}
          className="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors"
          title="Refresh"
        >
          <RefreshCw className="w-5 h-5" />
        </button>
      </div>

      <div className="grid grid-cols-4 gap-3 mb-6">
        <div className="bg-[#0b0e11] rounded-lg p-3 text-center">
          <p className="text-2xl font-bold text-yellow-400">{stats.pending}</p>
          <p className="text-xs text-gray-500">Pending</p>
        </div>
        <div className="bg-[#0b0e11] rounded-lg p-3 text-center">
          <p className="text-2xl font-bold text-blue-400">{stats.processing}</p>
          <p className="text-xs text-gray-500">Processing</p>
        </div>
        <div className="bg-[#0b0e11] rounded-lg p-3 text-center">
          <p className="text-2xl font-bold text-green-400">{stats.sent}</p>
          <p className="text-xs text-gray-500">Sent</p>
        </div>
        <div className="bg-[#0b0e11] rounded-lg p-3 text-center">
          <p className="text-2xl font-bold text-red-400">{stats.failed}</p>
          <p className="text-xs text-gray-500">Failed</p>
        </div>
      </div>

      <div className="flex gap-2 mb-4">
        {(['all', 'pending', 'sent', 'failed'] as const).map(f => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-3 py-1.5 rounded-lg text-sm capitalize transition-colors ${
              filter === f ? 'bg-[#00bcd4] text-black' : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      {filteredMessages.length === 0 ? (
        <div className="text-center py-12 text-gray-400">
          <Clock className="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No messages found</p>
        </div>
      ) : (
        <div className="space-y-3 max-h-[500px] overflow-y-auto">
          {filteredMessages.map(msg => (
            <div
              key={msg.id}
              className="bg-[#0b0e11] rounded-lg p-4 border border-gray-700 hover:border-gray-600 transition-colors"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-2">
                    {getStatusIcon(msg.status)}
                    <span className={`text-xs px-2 py-0.5 rounded capitalize ${getStatusColor(msg.status)}`}>
                      {msg.status}
                    </span>
                    {msg.template?.name && (
                      <span className="text-xs text-gray-500">
                        Template: {msg.template.name}
                      </span>
                    )}
                    <span className="text-xs text-gray-500">
                      {msg.channel_username}
                    </span>
                  </div>

                  <p className="text-sm text-gray-300 line-clamp-2 mb-2">
                    {msg.final_content}
                  </p>

                  <div className="flex items-center gap-4 text-xs text-gray-500">
                    <span>
                      Scheduled: {new Date(msg.scheduled_for).toLocaleString()}
                    </span>
                    {msg.sent_at && (
                      <span>
                        Sent: {new Date(msg.sent_at).toLocaleString()}
                      </span>
                    )}
                    {msg.attempts > 0 && (
                      <span>
                        Attempts: {msg.attempts}/{msg.max_attempts || 3}
                      </span>
                    )}
                  </div>

                  {msg.error_message && (
                    <p className="text-xs text-red-400 mt-2">
                      Error: {msg.error_message}
                    </p>
                  )}
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => setSelectedMessage(msg)}
                    className="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                    title="View Details"
                  >
                    <Eye className="w-4 h-4" />
                  </button>
                  {msg.status === 'pending' && (
                    <button
                      onClick={() => handleCancel(msg.id)}
                      className="p-1.5 text-gray-400 hover:text-yellow-400 hover:bg-gray-700 rounded transition-colors"
                      title="Cancel"
                    >
                      <Pause className="w-4 h-4" />
                    </button>
                  )}
                  {msg.status === 'failed' && (
                    <button
                      onClick={() => handleRetry(msg.id)}
                      className="p-1.5 text-gray-400 hover:text-green-400 hover:bg-gray-700 rounded transition-colors"
                      title="Retry"
                    >
                      <Play className="w-4 h-4" />
                    </button>
                  )}
                  {['sent', 'failed', 'cancelled'].includes(msg.status) && (
                    <button
                      onClick={() => handleDelete(msg.id)}
                      className="p-1.5 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded transition-colors"
                      title="Delete"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedMessage && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1a1d21] rounded-xl w-full max-w-lg">
            <div className="flex items-center justify-between p-6 border-b border-gray-700">
              <h3 className="text-lg font-semibold text-white">Message Details</h3>
              <button
                onClick={() => setSelectedMessage(null)}
                className="text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6 space-y-4">
              <div className="flex items-center gap-2">
                {getStatusIcon(selectedMessage.status)}
                <span className={`text-sm px-2 py-0.5 rounded capitalize ${getStatusColor(selectedMessage.status)}`}>
                  {selectedMessage.status}
                </span>
              </div>

              <div>
                <p className="text-xs text-gray-500 mb-1">Channel</p>
                <p className="text-white">{selectedMessage.channel_username}</p>
              </div>

              <div>
                <p className="text-xs text-gray-500 mb-1">Message Content</p>
                <div className="bg-[#0b0e11] rounded-lg p-4 text-gray-300 whitespace-pre-wrap text-sm max-h-48 overflow-y-auto">
                  {selectedMessage.final_content}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-xs text-gray-500 mb-1">Scheduled For</p>
                  <p className="text-white text-sm">
                    {new Date(selectedMessage.scheduled_for).toLocaleString()}
                  </p>
                </div>
                {selectedMessage.sent_at && (
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Sent At</p>
                    <p className="text-white text-sm">
                      {new Date(selectedMessage.sent_at).toLocaleString()}
                    </p>
                  </div>
                )}
              </div>

              {selectedMessage.error_message && (
                <div>
                  <p className="text-xs text-gray-500 mb-1">Error</p>
                  <p className="text-red-400 text-sm">{selectedMessage.error_message}</p>
                </div>
              )}

              {selectedMessage.telegram_message_id && (
                <div>
                  <p className="text-xs text-gray-500 mb-1">Telegram Message ID</p>
                  <p className="text-white text-sm font-mono">{selectedMessage.telegram_message_id}</p>
                </div>
              )}

              <div>
                <p className="text-xs text-gray-500 mb-1">Attempts</p>
                <p className="text-white text-sm">{selectedMessage.attempts} / {selectedMessage.max_attempts || 3}</p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
