import { useState } from 'react';
import { X, Send, Bell, Loader2, CheckCircle, AlertCircle, Link as LinkIcon } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface SendNotificationModalProps {
  isOpen: boolean;
  onClose: () => void;
  userId: string;
  userName: string;
  userEmail: string;
}

const notificationTypes = [
  { value: 'system', label: 'System Message', description: 'General system notification' },
  { value: 'account_update', label: 'Account Update', description: 'Account-related notification' },
  { value: 'promotion', label: 'Promotion', description: 'Promotional offer or announcement' },
  { value: 'reward', label: 'Reward', description: 'Reward or bonus notification' },
];

export default function SendNotificationModal({ isOpen, onClose, userId, userName, userEmail }: SendNotificationModalProps) {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [type, setType] = useState('system');
  const [redirectUrl, setRedirectUrl] = useState('');
  const [sending, setSending] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');

  const handleSend = async () => {
    if (!title.trim() || !message.trim()) {
      setError('Please fill in both title and message');
      return;
    }

    setSending(true);
    setError('');

    try {
      const { error: insertError } = await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          type,
          title: title.trim(),
          message: message.trim(),
          redirect_url: redirectUrl.trim() || null,
          read: false,
          data: {
            sent_by_admin: true,
            sent_at: new Date().toISOString()
          }
        });

      if (insertError) throw insertError;

      await supabase.from('admin_action_logs').insert({
        admin_id: (await supabase.auth.getUser()).data.user?.id,
        action_type: 'send_notification',
        target_user_id: userId,
        details: {
          notification_type: type,
          title: title.trim(),
          message_preview: message.substring(0, 100)
        }
      });

      setSuccess(true);
      setTimeout(() => {
        setTitle('');
        setMessage('');
        setType('system');
        setRedirectUrl('');
        setSuccess(false);
        onClose();
      }, 1500);
    } catch (err: any) {
      console.error('Error sending notification:', err);
      setError(err.message || 'Failed to send notification');
    } finally {
      setSending(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
      <div className="bg-[#1a1d24] rounded-xl border border-gray-800 w-full max-w-lg">
        <div className="flex items-center justify-between p-4 border-b border-gray-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-[#f0b90b]/20 rounded-lg flex items-center justify-center">
              <Bell className="w-5 h-5 text-[#f0b90b]" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white">Send Notification</h2>
              <p className="text-sm text-gray-400">To: {userName || userEmail}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
          >
            <X className="w-5 h-5 text-gray-400" />
          </button>
        </div>

        <div className="p-4 space-y-4">
          {success ? (
            <div className="py-8 text-center">
              <CheckCircle className="w-16 h-16 text-emerald-400 mx-auto mb-4" />
              <h3 className="text-xl font-bold text-white mb-2">Notification Sent!</h3>
              <p className="text-gray-400">The user will receive this notification immediately.</p>
            </div>
          ) : (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Notification Type
                </label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value)}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#f0b90b]"
                >
                  {notificationTypes.map((t) => (
                    <option key={t.value} value={t.value}>
                      {t.label} - {t.description}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Title *
                </label>
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Enter notification title..."
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b]"
                  maxLength={100}
                />
                <p className="text-xs text-gray-500 mt-1">{title.length}/100 characters</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  Message *
                </label>
                <textarea
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Enter notification message..."
                  rows={4}
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b] resize-none"
                  maxLength={500}
                />
                <p className="text-xs text-gray-500 mt-1">{message.length}/500 characters</p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">
                  <div className="flex items-center gap-2">
                    <LinkIcon className="w-4 h-4" />
                    Redirect URL (optional)
                  </div>
                </label>
                <input
                  type="text"
                  value={redirectUrl}
                  onChange={(e) => setRedirectUrl(e.target.value)}
                  placeholder="e.g., /wallet, /deposit, /support"
                  className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b]"
                />
                <p className="text-xs text-gray-500 mt-1">User will be redirected when clicking the notification</p>
              </div>

              {error && (
                <div className="flex items-center gap-2 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
                  <AlertCircle className="w-5 h-5 text-red-400" />
                  <span className="text-red-400 text-sm">{error}</span>
                </div>
              )}

              <div className="bg-[#0b0e11] rounded-lg p-4 border border-gray-800">
                <h4 className="text-sm font-medium text-gray-400 mb-2">Preview</h4>
                <div className="bg-[#1a1d24] rounded-lg p-3 border border-gray-700">
                  <div className="flex items-start gap-3">
                    <div className="w-8 h-8 bg-[#f0b90b]/20 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Bell className="w-4 h-4 text-[#f0b90b]" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-white font-medium text-sm truncate">
                        {title || 'Notification title...'}
                      </p>
                      <p className="text-gray-400 text-xs line-clamp-2 mt-1">
                        {message || 'Notification message...'}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </>
          )}
        </div>

        {!success && (
          <div className="flex gap-3 p-4 border-t border-gray-800">
            <button
              onClick={onClose}
              className="flex-1 py-3 bg-gray-800 hover:bg-gray-700 text-white font-medium rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSend}
              disabled={sending || !title.trim() || !message.trim()}
              className="flex-1 py-3 bg-[#f0b90b] hover:bg-[#d9a506] disabled:opacity-50 disabled:cursor-not-allowed text-black font-medium rounded-lg transition-colors flex items-center justify-center gap-2"
            >
              {sending ? (
                <>
                  <Loader2 className="w-5 h-5 animate-spin" />
                  Sending...
                </>
              ) : (
                <>
                  <Send className="w-5 h-5" />
                  Send Notification
                </>
              )}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
