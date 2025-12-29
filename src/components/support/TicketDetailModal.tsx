import { useState, useEffect, useRef } from 'react';
import { X, Send, User, Shield, Upload, Image as ImageIcon, Download, Clock, CheckCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';
import { useNotificationSound } from '../../hooks/useNotificationSound';

interface Message {
  id: string;
  sender_id: string;
  sender_type: 'user' | 'admin';
  message: string;
  created_at: string;
  read_at: string | null;
  pending?: boolean;
  failed?: boolean;
}

interface Attachment {
  id: string;
  message_id: string;
  file_name: string;
  file_size: number;
  mime_type: string;
  created_at: string;
}

interface Ticket {
  id: string;
  subject: string;
  status: string;
  priority: string;
  created_at: string;
  category: { name: string; color_code: string } | null;
}

interface TicketDetailModalProps {
  ticketId: string;
  onClose: () => void;
  onUpdate: () => void;
}

interface AttachmentFile {
  file: File;
  preview: string;
}

export default function TicketDetailModal({ ticketId, onClose, onUpdate }: TicketDetailModalProps) {
  const { user } = useAuth();
  const [ticket, setTicket] = useState<Ticket | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [attachments, setAttachments] = useState<Record<string, Attachment[]>>({});
  const [newMessage, setNewMessage] = useState('');
  const [newAttachments, setNewAttachments] = useState<AttachmentFile[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [viewingImage, setViewingImage] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const subscriptionRef = useRef<any>(null);
  const { playSound } = useNotificationSound({ enabled: true, volume: 0.5 });

  useEffect(() => {
    loadTicket();
    loadMessages();
    loadAttachments();
    const cleanup = subscribeToMessages();

    return () => {
      cleanup?.();
    };
  }, [ticketId]);

  useEffect(() => {
    scrollToBottom();
    markMessagesAsRead();
  }, [messages]);

  const loadTicket = async () => {
    try {
      const { data, error } = await supabase
        .from('support_tickets')
        .select(`
          *,
          category:support_categories(name, color_code)
        `)
        .eq('id', ticketId)
        .single();

      if (error) throw error;
      setTicket(data);
    } catch (error) {
      console.error('Error loading ticket:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async () => {
    try {
      const { data, error } = await supabase
        .from('support_messages')
        .select('*')
        .eq('ticket_id', ticketId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      setMessages(data || []);
    } catch (error) {
      console.error('Error loading messages:', error);
    }
  };

  const loadAttachments = async () => {
    try {
      const { data, error } = await supabase
        .from('support_attachments')
        .select('id, message_id, file_name, file_size, mime_type, created_at')
        .eq('ticket_id', ticketId)
        .order('created_at', { ascending: true });

      if (error) throw error;

      const grouped = (data || []).reduce((acc, att) => {
        if (!acc[att.message_id]) acc[att.message_id] = [];
        acc[att.message_id].push(att);
        return acc;
      }, {} as Record<string, Attachment[]>);

      setAttachments(grouped);
    } catch (error) {
      console.error('Error loading attachments:', error);
    }
  };

  const subscribeToMessages = () => {
    if (subscriptionRef.current) {
      subscriptionRef.current.unsubscribe();
    }

    const channel = supabase
      .channel(`user_ticket_messages_${ticketId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
          filter: `ticket_id=eq.${ticketId}`,
        },
        (payload) => {
          const newMsg = payload.new as Message;

          setMessages((prev) => {
            const exists = prev.some(m => m.id === newMsg.id);
            const isPendingMatch = prev.some(m =>
              m.pending &&
              m.message === newMsg.message &&
              m.sender_id === newMsg.sender_id
            );

            if (exists) return prev;

            if (isPendingMatch) {
              return prev.map(m =>
                m.pending && m.message === newMsg.message && m.sender_id === newMsg.sender_id
                  ? { ...newMsg, pending: false }
                  : m
              );
            }

            if (newMsg.sender_type === 'admin') {
              playSound();
            }

            return [...prev, newMsg];
          });

          loadAttachments();
        }
      );

    channel.subscribe();
    subscriptionRef.current = channel;

    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.unsubscribe();
        subscriptionRef.current = null;
      }
    };
  };

  const markMessagesAsRead = async () => {
    if (!user) return;

    const hasUnread = messages.some(m => m.sender_type === 'admin' && !m.read_at);

    if (hasUnread) {
      await supabase.rpc('mark_admin_messages_read', { p_ticket_id: ticketId });
    }
  };

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;

    const attachmentFiles: AttachmentFile[] = [];
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (file.type.startsWith('image/')) {
        attachmentFiles.push({
          file,
          preview: URL.createObjectURL(file),
        });
      }
    }
    setNewAttachments([...newAttachments, ...attachmentFiles]);
  };

  const removeAttachment = (index: number) => {
    URL.revokeObjectURL(newAttachments[index].preview);
    setNewAttachments(newAttachments.filter((_, i) => i !== index));
  };

  const uploadAttachment = async (messageId: string, file: File) => {
    return new Promise<void>((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = async () => {
        try {
          const base64 = (reader.result as string).split(',')[1];
          const { error } = await supabase.rpc('insert_support_attachment', {
            p_ticket_id: ticketId,
            p_message_id: messageId,
            p_file_name: file.name,
            p_file_size: file.size,
            p_mime_type: file.type,
            p_file_data_base64: base64,
          });
          if (error) throw error;
          resolve();
        } catch (error) {
          reject(error);
        }
      };
      reader.onerror = () => reject(new Error('Failed to read file'));
      reader.readAsDataURL(file);
    });
  };

  const viewAttachment = async (attachmentId: string) => {
    try {
      const { data, error } = await supabase
        .rpc('get_support_attachment_base64', { attachment_id: attachmentId })
        .single();

      if (error) throw error;

      if (data && data.file_data_base64) {
        const binaryString = atob(data.file_data_base64);
        const bytes = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }
        const blob = new Blob([bytes], { type: data.mime_type });
        const url = URL.createObjectURL(blob);
        setViewingImage(url);
      }
    } catch (error) {
      console.error('Error viewing attachment:', error);
    }
  };

  const downloadAttachment = async (attachmentId: string, fileName: string) => {
    try {
      const { data, error } = await supabase
        .rpc('get_support_attachment_base64', { attachment_id: attachmentId })
        .single();

      if (error) throw error;

      if (data && data.file_data_base64) {
        const binaryString = atob(data.file_data_base64);
        const bytes = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }
        const blob = new Blob([bytes], { type: data.mime_type });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    } catch (error) {
      console.error('Error downloading attachment:', error);
    }
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || (!newMessage.trim() && newAttachments.length === 0)) return;

    const messageText = newMessage.trim() || '(Attachment)';
    const tempId = `temp_${Date.now()}`;
    const pendingAttachments = [...newAttachments];

    const optimisticMessage: Message = {
      id: tempId,
      sender_id: user.id,
      sender_type: 'user',
      message: messageText,
      created_at: new Date().toISOString(),
      read_at: null,
      pending: true,
    };

    setMessages((prev) => [...prev, optimisticMessage]);
    setNewMessage('');
    setNewAttachments([]);
    setSending(true);

    try {
      const { data: messageData, error } = await supabase
        .from('support_messages')
        .insert({
          ticket_id: ticketId,
          sender_id: user.id,
          sender_type: 'user',
          message: messageText,
        })
        .select()
        .single();

      if (error) throw error;

      setMessages((prev) =>
        prev.map((m) =>
          m.id === tempId
            ? { ...m, id: messageData.id, pending: false }
            : m
        )
      );

      for (const attachment of pendingAttachments) {
        await uploadAttachment(messageData.id, attachment.file);
      }

      await supabase
        .from('support_tickets')
        .update({
          status: 'waiting_admin',
          updated_at: new Date().toISOString(),
        })
        .eq('id', ticketId);

      pendingAttachments.forEach(att => URL.revokeObjectURL(att.preview));
      loadAttachments();
      onUpdate();
    } catch (error) {
      console.error('Error sending message:', error);
      setMessages((prev) =>
        prev.map((m) =>
          m.id === tempId
            ? { ...m, pending: false, failed: true }
            : m
        )
      );
    } finally {
      setSending(false);
    }
  };

  const handleRetryMessage = async (failedMessage: Message) => {
    if (!user) return;

    setMessages((prev) =>
      prev.map((m) =>
        m.id === failedMessage.id
          ? { ...m, pending: true, failed: false }
          : m
      )
    );

    try {
      const { data: messageData, error } = await supabase
        .from('support_messages')
        .insert({
          ticket_id: ticketId,
          sender_id: user.id,
          sender_type: 'user',
          message: failedMessage.message,
        })
        .select()
        .single();

      if (error) throw error;

      setMessages((prev) =>
        prev.map((m) =>
          m.id === failedMessage.id
            ? { ...m, id: messageData.id, pending: false, failed: false }
            : m
        )
      );

      await supabase
        .from('support_tickets')
        .update({
          status: 'waiting_admin',
          updated_at: new Date().toISOString(),
        })
        .eq('id', ticketId);

      onUpdate();
    } catch (error) {
      console.error('Error retrying message:', error);
      setMessages((prev) =>
        prev.map((m) =>
          m.id === failedMessage.id
            ? { ...m, pending: false, failed: true }
            : m
        )
      );
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open':
        return 'bg-blue-500/10 text-blue-500';
      case 'in_progress':
        return 'bg-yellow-500/10 text-yellow-500';
      case 'waiting_user':
        return 'bg-orange-500/10 text-orange-500';
      case 'waiting_admin':
        return 'bg-cyan-500/10 text-cyan-500';
      case 'resolved':
        return 'bg-green-500/10 text-green-500';
      case 'closed':
        return 'bg-gray-500/10 text-gray-500';
      default:
        return 'bg-gray-500/10 text-gray-500';
    }
  };

  if (loading) {
    return (
      <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (!ticket) return null;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-gray-900 rounded-xl border border-gray-800 w-full max-w-4xl h-[90vh] flex flex-col">
        <div className="border-b border-gray-800 px-6 py-4">
          <div className="flex items-start justify-between mb-3">
            <div className="flex-1">
              <h2 className="text-xl font-semibold text-white mb-2">{ticket.subject}</h2>
              <div className="flex items-center gap-2">
                {ticket.category && (
                  <span
                    className="px-2 py-1 rounded text-xs font-medium"
                    style={{
                      backgroundColor: `${ticket.category.color_code}20`,
                      color: ticket.category.color_code,
                    }}
                  >
                    {ticket.category.name}
                  </span>
                )}
                <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(ticket.status)}`}>
                  {ticket.status.replace('_', ' ')}
                </span>
                <span className="text-sm text-gray-400">
                  {new Date(ticket.created_at).toLocaleDateString()}
                </span>
              </div>
            </div>
            <button
              onClick={onClose}
              className="p-2 hover:bg-gray-800 rounded-lg transition-colors"
            >
              <X className="w-5 h-5 text-gray-400" />
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          {messages.map((msg) => (
            <div
              key={msg.id}
              className={`flex gap-3 ${msg.sender_type === 'user' ? 'flex-row-reverse' : ''} ${
                msg.pending ? 'opacity-70' : ''
              }`}
            >
              <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                msg.sender_type === 'user' ? 'bg-blue-600' : 'bg-gray-700'
              }`}>
                {msg.sender_type === 'user' ? (
                  <User className="w-4 h-4 text-white" />
                ) : (
                  <Shield className="w-4 h-4 text-white" />
                )}
              </div>
              <div className={`flex-1 max-w-[70%] ${msg.sender_type === 'user' ? 'items-end' : ''}`}>
                <div className={`rounded-lg p-4 ${
                  msg.sender_type === 'user'
                    ? msg.failed
                      ? 'bg-red-600/50 text-white'
                      : 'bg-blue-600 text-white'
                    : 'bg-gray-800 text-gray-100'
                }`}>
                  <p className="text-sm whitespace-pre-wrap">{msg.message}</p>

                  {msg.pending && (
                    <div className="flex items-center gap-1 mt-2 text-xs opacity-70">
                      <Clock className="w-3 h-3" />
                      Sending...
                    </div>
                  )}

                  {msg.failed && (
                    <button
                      onClick={() => handleRetryMessage(msg)}
                      className="flex items-center gap-1 mt-2 text-xs text-white/80 hover:text-white underline"
                    >
                      Failed to send - Click to retry
                    </button>
                  )}

                  {attachments[msg.id] && attachments[msg.id].length > 0 && (
                    <div className="mt-3 space-y-2">
                      {attachments[msg.id].map((att) => (
                        <div
                          key={att.id}
                          className="flex items-center gap-2 p-2 bg-black/20 rounded-lg"
                        >
                          <ImageIcon className="w-4 h-4" />
                          <span className="flex-1 text-sm truncate">{att.file_name}</span>
                          <button
                            onClick={() => viewAttachment(att.id)}
                            className="p-1 hover:bg-white/10 rounded"
                          >
                            <ImageIcon className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => downloadAttachment(att.id, att.file_name)}
                            className="p-1 hover:bg-white/10 rounded"
                          >
                            <Download className="w-4 h-4" />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
                <div className={`text-xs text-gray-500 mt-1 flex items-center gap-1 ${msg.sender_type === 'user' ? 'justify-end' : ''}`}>
                  {msg.pending ? (
                    <span>Sending...</span>
                  ) : msg.failed ? (
                    <span className="text-red-400">Failed</span>
                  ) : (
                    <>
                      {new Date(msg.created_at).toLocaleTimeString()}
                      {msg.sender_type === 'user' && <CheckCircle className="w-3 h-3 text-green-500" />}
                    </>
                  )}
                </div>
              </div>
            </div>
          ))}
          <div ref={messagesEndRef} />
        </div>

        {ticket.status !== 'closed' && ticket.status !== 'resolved' && (
          <div className="border-t border-gray-800 p-6">
            <form onSubmit={handleSendMessage} className="space-y-3">
              {newAttachments.length > 0 && (
                <div className="flex gap-2 flex-wrap">
                  {newAttachments.map((att, index) => (
                    <div key={index} className="relative group">
                      <img
                        src={att.preview}
                        alt={`Attachment ${index + 1}`}
                        className="w-20 h-20 object-cover rounded-lg border border-gray-700"
                      />
                      <button
                        type="button"
                        onClick={() => removeAttachment(index)}
                        className="absolute -top-2 -right-2 p-1 bg-red-600 hover:bg-red-700 rounded-full"
                      >
                        <X className="w-3 h-3 text-white" />
                      </button>
                    </div>
                  ))}
                </div>
              )}

              <div className="flex gap-3">
                <label className="p-2 bg-gray-800/50 border border-gray-700 rounded-lg cursor-pointer hover:border-blue-500 transition-colors">
                  <Upload className="w-5 h-5 text-gray-400" />
                  <input
                    type="file"
                    accept="image/*"
                    multiple
                    onChange={handleFileChange}
                    className="hidden"
                    disabled={sending}
                  />
                </label>
                <input
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="Type your message..."
                  className="flex-1 px-4 py-2 bg-gray-800/50 border border-gray-700 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
                  disabled={sending}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && !e.shiftKey) {
                      e.preventDefault();
                      handleSendMessage(e);
                    }
                  }}
                />
                <button
                  type="submit"
                  disabled={sending || (!newMessage.trim() && newAttachments.length === 0)}
                  className="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  <Send className="w-4 h-4" />
                  Send
                </button>
              </div>
            </form>
          </div>
        )}
      </div>

      {viewingImage && (
        <div className="fixed inset-0 bg-black/90 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setViewingImage(null)}>
          <div className="max-w-4xl w-full" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-end mb-4">
              <button
                onClick={() => setViewingImage(null)}
                className="p-2 bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
              >
                <X className="w-6 h-6 text-white" />
              </button>
            </div>
            <img src={viewingImage} alt="Attachment" className="w-full h-auto rounded-lg" />
          </div>
        </div>
      )}
    </div>
  );
}
