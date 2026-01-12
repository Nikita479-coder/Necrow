import { useState, useEffect, useRef, useCallback } from 'react';
import { MessageSquare, Clock, CheckCircle, User, Search, Filter, Wifi, WifiOff, Eye, EyeOff, Zap, FileText, Plus, Edit2, Trash2, Save, X, ToggleLeft, ToggleRight, Image, Download, Paperclip } from 'lucide-react';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import { loggingService } from '../services/loggingService';
import { useNotificationSound, ConnectionStatus } from '../hooks/useNotificationSound';

interface QuickReplyTemplate {
  id: string;
  command: string;
  label: string;
  message: string;
  template_type: 'admin' | 'user';
  is_active: boolean;
  sort_order: number;
}

interface Ticket {
  id: string;
  user_id: string;
  subject: string;
  status: string;
  priority: string;
  created_at: string;
  updated_at: string;
  first_response_at: string | null;
  category: { name: string; color_code: string } | null;
  user_profile: { username: string; email: string } | null;
  unread_count?: number;
  admin_unread_by_user?: number;
}

interface Attachment {
  id: string;
  file_name: string;
  file_size: number;
  mime_type: string;
  created_at: string;
}

interface Message {
  id: string;
  sender_id: string;
  sender_type: 'user' | 'admin';
  message: string;
  created_at: string;
  read_at: string | null;
  sender_profile?: { username: string };
  pending?: boolean;
  failed?: boolean;
  attachments?: Attachment[];
}

export default function AdminSupport() {
  const { user, profile, canAccessAdmin, hasPermission } = useAuth();
  const { navigateTo } = useNavigation();
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [selectedTicket, setSelectedTicket] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [filter, setFilter] = useState<'all' | 'open' | 'pending' | 'templates'>('open');
  const [searchQuery, setSearchQuery] = useState('');
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('connecting');
  const [showQuickReplies, setShowQuickReplies] = useState(false);
  const [quickReplyFilter, setQuickReplyFilter] = useState('');
  const [selectedQuickReplyIndex, setSelectedQuickReplyIndex] = useState(0);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const ticketSubscriptionRef = useRef<any>(null);
  const messageSubscriptionRef = useRef<any>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const quickReplyRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const { playSound } = useNotificationSound({ enabled: true, volume: 0.5 });

  const [templates, setTemplates] = useState<QuickReplyTemplate[]>([]);
  const [adminQuickReplies, setAdminQuickReplies] = useState<QuickReplyTemplate[]>([]);
  const [templatesLoading, setTemplatesLoading] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<QuickReplyTemplate | null>(null);
  const [isCreatingTemplate, setIsCreatingTemplate] = useState(false);
  const [templateTypeFilter, setTemplateTypeFilter] = useState<'all' | 'admin' | 'user'>('all');
  const [newTemplate, setNewTemplate] = useState({
    command: '',
    label: '',
    message: '',
    template_type: 'admin' as 'admin' | 'user',
  });
  const [loadedImages, setLoadedImages] = useState<Record<string, string>>({});
  const [loadingImages, setLoadingImages] = useState<Set<string>>(new Set());

  const loadImageAttachment = async (attachmentId: string) => {
    if (loadedImages[attachmentId] || loadingImages.has(attachmentId)) return;

    setLoadingImages(prev => new Set(prev).add(attachmentId));

    try {
      const { data, error } = await supabase.rpc('get_support_attachment_base64', {
        attachment_id: attachmentId,
      });

      if (error) throw error;

      if (data && data.length > 0) {
        const attachment = data[0];
        const dataUrl = `data:${attachment.mime_type};base64,${attachment.file_data_base64}`;
        setLoadedImages(prev => ({ ...prev, [attachmentId]: dataUrl }));
      }
    } catch (error) {
      console.error('Error loading image:', error);
    } finally {
      setLoadingImages(prev => {
        const next = new Set(prev);
        next.delete(attachmentId);
        return next;
      });
    }
  };

  useEffect(() => {
    messages.forEach(msg => {
      msg.attachments?.forEach(attachment => {
        if (attachment.mime_type.startsWith('image/')) {
          loadImageAttachment(attachment.id);
        }
      });
    });
  }, [messages]);

  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  useEffect(() => {
    if (showQuickReplies && quickReplyRefs.current[selectedQuickReplyIndex]) {
      quickReplyRefs.current[selectedQuickReplyIndex]?.scrollIntoView({
        behavior: 'smooth',
        block: 'nearest',
      });
    }
  }, [selectedQuickReplyIndex, showQuickReplies]);

  useEffect(() => {
    const canView = profile?.is_admin || (canAccessAdmin() && hasPermission('view_support'));
    if (user && canView) {
      loadTickets();
      const cleanup = subscribeToTickets();
      return cleanup;
    }
  }, [user, profile, filter]);

  useEffect(() => {
    if (selectedTicket) {
      loadMessages();
      const cleanup = subscribeToMessages();
      return cleanup;
    }
  }, [selectedTicket]);

  useEffect(() => {
    if (filter === 'templates') {
      loadTemplates();
    }
  }, [filter]);

  useEffect(() => {
    loadAdminQuickReplies();
  }, []);

  const loadAdminQuickReplies = async () => {
    try {
      const { data, error } = await supabase.rpc('get_quick_reply_templates', {
        p_template_type: 'admin'
      });

      if (error) throw error;
      setAdminQuickReplies(data || []);
    } catch (error) {
      console.error('Error loading admin quick replies:', error);
    }
  };

  const loadTemplates = async () => {
    setTemplatesLoading(true);
    try {
      const { data, error } = await supabase
        .from('quick_reply_templates')
        .select('*')
        .order('template_type')
        .order('sort_order')
        .order('created_at');

      if (error) throw error;
      setTemplates(data || []);
    } catch (error) {
      console.error('Error loading templates:', error);
    } finally {
      setTemplatesLoading(false);
    }
  };

  const handleCreateTemplate = async () => {
    if (!newTemplate.command || !newTemplate.label || !newTemplate.message) return;

    try {
      const command = newTemplate.command.startsWith('/') ? newTemplate.command : `/${newTemplate.command}`;

      const { error } = await supabase
        .from('quick_reply_templates')
        .insert({
          command,
          label: newTemplate.label,
          message: newTemplate.message,
          template_type: newTemplate.template_type,
          sort_order: templates.filter(t => t.template_type === newTemplate.template_type).length + 1,
        });

      if (error) throw error;

      setNewTemplate({ command: '', label: '', message: '', template_type: 'admin' });
      setIsCreatingTemplate(false);
      loadTemplates();
      loadAdminQuickReplies();

      await loggingService.logAdminActivity({
        action_type: 'template_created',
        action_description: `Created quick reply template: ${command}`,
        metadata: { template_type: newTemplate.template_type },
      });
    } catch (error) {
      console.error('Error creating template:', error);
    }
  };

  const handleUpdateTemplate = async () => {
    if (!editingTemplate) return;

    try {
      const command = editingTemplate.command.startsWith('/') ? editingTemplate.command : `/${editingTemplate.command}`;

      const { error } = await supabase
        .from('quick_reply_templates')
        .update({
          command,
          label: editingTemplate.label,
          message: editingTemplate.message,
          is_active: editingTemplate.is_active,
          updated_at: new Date().toISOString(),
        })
        .eq('id', editingTemplate.id);

      if (error) throw error;

      setEditingTemplate(null);
      loadTemplates();
      loadAdminQuickReplies();

      await loggingService.logAdminActivity({
        action_type: 'template_updated',
        action_description: `Updated quick reply template: ${command}`,
        metadata: { template_id: editingTemplate.id },
      });
    } catch (error) {
      console.error('Error updating template:', error);
    }
  };

  const handleDeleteTemplate = async (template: QuickReplyTemplate) => {
    if (!confirm(`Are you sure you want to delete the template "${template.label}"?`)) return;

    try {
      const { error } = await supabase
        .from('quick_reply_templates')
        .delete()
        .eq('id', template.id);

      if (error) throw error;

      loadTemplates();
      loadAdminQuickReplies();

      await loggingService.logAdminActivity({
        action_type: 'template_deleted',
        action_description: `Deleted quick reply template: ${template.command}`,
        metadata: { template_id: template.id },
      });
    } catch (error) {
      console.error('Error deleting template:', error);
    }
  };

  const handleToggleActive = async (template: QuickReplyTemplate) => {
    try {
      const { error } = await supabase
        .from('quick_reply_templates')
        .update({
          is_active: !template.is_active,
          updated_at: new Date().toISOString(),
        })
        .eq('id', template.id);

      if (error) throw error;

      loadTemplates();
      loadAdminQuickReplies();
    } catch (error) {
      console.error('Error toggling template:', error);
    }
  };

  const loadTickets = async () => {
    try {
      const { data, error } = await supabase.rpc('admin_get_support_tickets_with_users');

      if (error) {
        console.error('RPC Error:', error);
        throw error;
      }

      let filteredData = data || [];

      if (filter === 'open') {
        filteredData = filteredData.filter((t: any) =>
          ['open', 'in_progress', 'waiting_admin'].includes(t.status)
        );
      } else if (filter === 'pending') {
        filteredData = filteredData.filter((t: any) => t.status === 'waiting_admin');
      }

      const ticketsWithProfiles = filteredData.map((ticket: any) => ({
        ...ticket,
        category: ticket.category_name ? {
          name: ticket.category_name,
          color_code: ticket.category_color_code
        } : null,
        user_profile: {
          username: ticket.user_username || 'Unknown',
          email: ticket.user_email || 'Unknown',
        },
        admin_unread_by_user: ticket.admin_unread_by_user || 0,
      }));

      setTickets(ticketsWithProfiles);
    } catch (error) {
      console.error('Error loading tickets:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async () => {
    if (!selectedTicket) return;

    try {
      const { data, error } = await supabase.rpc('admin_get_ticket_messages', {
        p_ticket_id: selectedTicket
      });

      if (error) throw error;

      const messagesWithProfiles = (data || []).map((msg: any) => ({
        ...msg,
        sender_profile: { username: msg.sender_username || (msg.sender_type === 'admin' ? 'Support' : 'User') }
      }));

      setMessages(messagesWithProfiles);

      await supabase.rpc('mark_user_messages_read', { p_ticket_id: selectedTicket });

      loadTickets();
    } catch (error) {
      console.error('Error loading messages:', error);
    }
  };

  const subscribeToTickets = () => {
    if (ticketSubscriptionRef.current) {
      ticketSubscriptionRef.current.unsubscribe();
    }

    const channel = supabase
      .channel('admin_tickets_realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'support_tickets',
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            playSound();
          }
          loadTickets();
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
        },
        (payload) => {
          const newMsg = payload.new as any;
          if (newMsg.sender_type === 'user') {
            playSound();
            loadTickets();
          }
        }
      );

    channel.subscribe((status) => {
      if (status === 'SUBSCRIBED') {
        setConnectionStatus('connected');
      } else if (status === 'CHANNEL_ERROR') {
        setConnectionStatus('disconnected');
      } else if (status === 'CLOSED') {
        setConnectionStatus('disconnected');
      }
    });

    ticketSubscriptionRef.current = channel;

    return () => {
      if (ticketSubscriptionRef.current) {
        ticketSubscriptionRef.current.unsubscribe();
        ticketSubscriptionRef.current = null;
      }
    };
  };

  const subscribeToMessages = () => {
    if (!selectedTicket) return () => {};

    if (messageSubscriptionRef.current) {
      messageSubscriptionRef.current.unsubscribe();
    }

    const channel = supabase
      .channel(`admin_ticket_messages_${selectedTicket}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
          filter: `ticket_id=eq.${selectedTicket}`,
        },
        async (payload) => {
          const newMsg = payload.new as any;

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
                  ? { ...newMsg, sender_profile: m.sender_profile, pending: false }
                  : m
              );
            }

            if (newMsg.sender_type === 'user') {
              playSound();
            }

            return [...prev, {
              ...newMsg,
              sender_profile: {
                username: newMsg.sender_type === 'admin' ? 'Support' : 'User'
              }
            }];
          });

          if (newMsg.sender_type === 'user') {
            await supabase
              .from('support_messages')
              .update({ read_at: new Date().toISOString() })
              .eq('id', newMsg.id);
          }
        }
      );

    channel.subscribe((status) => {
      if (status === 'SUBSCRIBED') {
        setConnectionStatus('connected');
      } else if (status === 'CHANNEL_ERROR') {
        setConnectionStatus('disconnected');
      }
    });

    messageSubscriptionRef.current = channel;

    return () => {
      if (messageSubscriptionRef.current) {
        messageSubscriptionRef.current.unsubscribe();
        messageSubscriptionRef.current = null;
      }
    };
  };

  const viewAttachment = async (attachmentId: string) => {
    try {
      const { data, error } = await supabase.rpc('get_support_attachment_base64', {
        attachment_id: attachmentId,
      });

      if (error) throw error;

      if (data && data.length > 0) {
        const attachment = data[0];
        const dataUrl = `data:${attachment.mime_type};base64,${attachment.file_data_base64}`;

        if (attachment.mime_type.startsWith('image/')) {
          const newWindow = window.open('', '_blank');
          if (newWindow) {
            newWindow.document.open();
            newWindow.document.write(`
              <!DOCTYPE html>
              <html>
                <head>
                  <title>${attachment.file_name}</title>
                  <style>
                    body {
                      margin: 0;
                      padding: 20px;
                      background: #0a0a0a;
                      display: flex;
                      justify-content: center;
                      align-items: center;
                      min-height: 100vh;
                    }
                    img {
                      max-width: 100%;
                      max-height: 100vh;
                      object-fit: contain;
                      box-shadow: 0 4px 6px rgba(0,0,0,0.3);
                    }
                  </style>
                </head>
                <body>
                  <img src="${dataUrl}" alt="${attachment.file_name}" />
                </body>
              </html>
            `);
            newWindow.document.close();
          }
        } else {
          const link = document.createElement('a');
          link.href = dataUrl;
          link.download = attachment.file_name;
          link.click();
        }
      }
    } catch (error) {
      console.error('Error viewing attachment:', error);
    }
  };

  const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !selectedTicket || !newMessage.trim()) return;

    const messageText = newMessage.trim();
    const tempId = `temp_${Date.now()}`;

    const optimisticMessage: Message = {
      id: tempId,
      sender_id: user.id,
      sender_type: 'admin',
      message: messageText,
      created_at: new Date().toISOString(),
      sender_profile: { username: 'Support' },
      pending: true,
    };

    setMessages((prev) => [...prev, optimisticMessage]);
    setNewMessage('');
    setSending(true);

    try {
      const { data, error } = await supabase
        .from('support_messages')
        .insert({
          ticket_id: selectedTicket,
          sender_id: user.id,
          sender_type: 'admin',
          message: messageText,
        })
        .select()
        .single();

      if (error) throw error;

      setMessages((prev) =>
        prev.map((m) =>
          m.id === tempId
            ? { ...m, id: data.id, pending: false }
            : m
        )
      );

      await supabase
        .from('support_tickets')
        .update({
          status: 'in_progress',
          updated_at: new Date().toISOString(),
        })
        .eq('id', selectedTicket);

      await loggingService.logAdminActivity({
        action_type: 'support_response',
        action_description: 'Responded to support ticket',
        target_user_id: tickets.find(t => t.id === selectedTicket)?.user_id,
        metadata: { ticket_id: selectedTicket },
      });

      loadTickets();
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
    if (!user || !selectedTicket) return;

    setMessages((prev) =>
      prev.map((m) =>
        m.id === failedMessage.id
          ? { ...m, pending: true, failed: false }
          : m
      )
    );

    try {
      const { data, error } = await supabase
        .from('support_messages')
        .insert({
          ticket_id: selectedTicket,
          sender_id: user.id,
          sender_type: 'admin',
          message: failedMessage.message,
        })
        .select()
        .single();

      if (error) throw error;

      setMessages((prev) =>
        prev.map((m) =>
          m.id === failedMessage.id
            ? { ...m, id: data.id, pending: false, failed: false }
            : m
        )
      );
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

  const handleStatusChange = async (ticketId: string, newStatus: string) => {
    try {
      const updates: any = { status: newStatus, updated_at: new Date().toISOString() };

      if (newStatus === 'resolved' || newStatus === 'closed') {
        updates.resolved_at = new Date().toISOString();
      }

      await supabase
        .from('support_tickets')
        .update(updates)
        .eq('id', ticketId);

      await loggingService.logAdminActivity({
        action_type: 'support_status_change',
        action_description: `Changed ticket status to ${newStatus}`,
        target_user_id: tickets.find(t => t.id === ticketId)?.user_id,
        metadata: { ticket_id: ticketId, new_status: newStatus },
      });

      loadTickets();
    } catch (error) {
      console.error('Error updating ticket status:', error);
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

  const getConnectionStatusColor = () => {
    switch (connectionStatus) {
      case 'connected':
        return 'bg-green-500';
      case 'connecting':
        return 'bg-yellow-500 animate-pulse';
      case 'disconnected':
        return 'bg-red-500';
    }
  };

  const getConnectionStatusText = () => {
    switch (connectionStatus) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      case 'disconnected':
        return 'Disconnected';
    }
  };

  const filteredQuickReplies = adminQuickReplies.filter(qr =>
    quickReplyFilter === '' ||
    qr.command.toLowerCase().includes(quickReplyFilter.toLowerCase()) ||
    qr.label.toLowerCase().includes(quickReplyFilter.toLowerCase())
  );

  const handleMessageChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value;
    setNewMessage(value);

    if (value.startsWith('/')) {
      setShowQuickReplies(true);
      setQuickReplyFilter(value);
      setSelectedQuickReplyIndex(0);
    } else {
      setShowQuickReplies(false);
      setQuickReplyFilter('');
    }
  };

  const selectQuickReply = (reply: { command: string; label: string; message: string }) => {
    setNewMessage(reply.message);
    setShowQuickReplies(false);
    setQuickReplyFilter('');
    textareaRef.current?.focus();
  };

  const filteredTemplates = templates.filter(t =>
    templateTypeFilter === 'all' || t.template_type === templateTypeFilter
  );

  const handleTextareaKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (showQuickReplies && filteredQuickReplies.length > 0) {
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelectedQuickReplyIndex(prev =>
          prev < filteredQuickReplies.length - 1 ? prev + 1 : 0
        );
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelectedQuickReplyIndex(prev =>
          prev > 0 ? prev - 1 : filteredQuickReplies.length - 1
        );
      } else if (e.key === 'Tab') {
        e.preventDefault();
        selectQuickReply(filteredQuickReplies[selectedQuickReplyIndex]);
      } else if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        selectQuickReply(filteredQuickReplies[selectedQuickReplyIndex]);
      } else if (e.key === 'Escape') {
        setShowQuickReplies(false);
        setQuickReplyFilter('');
      }
    } else if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage(e);
    }
  };

  const selectedTicketData = tickets.find(t => t.id === selectedTicket);

  const filteredTickets = tickets.filter(t =>
    t.subject.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.user_profile?.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.user_profile?.email.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const hasAccess = profile?.is_admin || (canAccessAdmin() && hasPermission('view_support'));

  if (!hasAccess) {
    return (
      <div className="min-h-screen bg-[#0b0e11] text-white flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold mb-2">Access Denied</h2>
          <p className="text-gray-400">You do not have permission to access this page</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11] text-white">
      <Navbar />

      <div className="container mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <h1 className="text-3xl font-bold">Support Management</h1>
              <div className="flex items-center gap-2 px-3 py-1.5 bg-gray-800/50 rounded-full border border-gray-700">
                <div className={`w-2.5 h-2.5 rounded-full ${getConnectionStatusColor()}`} />
                <span className="text-xs text-gray-400">{getConnectionStatusText()}</span>
                {connectionStatus === 'connected' ? (
                  <Wifi className="w-3.5 h-3.5 text-green-500" />
                ) : (
                  <WifiOff className="w-3.5 h-3.5 text-red-500" />
                )}
              </div>
            </div>
            <p className="text-gray-400">Manage customer support tickets</p>
          </div>
          <div className="flex gap-4">
            <div className="bg-gray-800/50 rounded-lg px-4 py-2">
              <div className="text-sm text-gray-400">Open Tickets</div>
              <div className="text-2xl font-bold">{tickets.filter(t => ['open', 'in_progress', 'waiting_admin'].includes(t.status)).length}</div>
            </div>
            <div className="bg-gray-800/50 rounded-lg px-4 py-2">
              <div className="text-sm text-gray-400">Avg Response Time</div>
              <div className="text-2xl font-bold">2h 15m</div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-12 gap-6">
          <div className="col-span-4 space-y-4">
            <div className="flex items-center gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search tickets..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 bg-gray-800/50 border border-gray-700 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
                />
              </div>
              <button className="p-2 bg-gray-800/50 border border-gray-700 rounded-lg hover:bg-gray-700/50 transition-colors">
                <Filter className="w-5 h-5" />
              </button>
            </div>

            <div className="flex gap-2">
              {(['all', 'open', 'pending', 'templates'] as const).map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  className={`px-4 py-2 rounded-lg font-medium transition-colors flex items-center gap-2 ${
                    filter === f
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-800/50 text-gray-400 hover:text-white'
                  }`}
                >
                  {f === 'templates' && <FileText className="w-4 h-4" />}
                  {f.charAt(0).toUpperCase() + f.slice(1)}
                </button>
              ))}
            </div>

            {filter !== 'templates' && (
              <div className="space-y-2 max-h-[calc(100vh-300px)] overflow-y-auto">
                {filteredTickets.map((ticket) => (
                  <div
                    key={ticket.id}
                    onClick={() => setSelectedTicket(ticket.id)}
                    className={`bg-gray-800/50 border rounded-lg p-4 cursor-pointer transition-all ${
                      selectedTicket === ticket.id
                        ? 'border-blue-500 ring-1 ring-blue-500/50'
                        : 'border-gray-700 hover:border-gray-600'
                    }`}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex-1">
                        <h3 className="text-white font-medium text-sm mb-1">{ticket.subject}</h3>
                        <p className="text-xs text-gray-400">{ticket.user_profile?.username}</p>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            localStorage.setItem('adminSelectedUserId', ticket.user_id);
                            navigateTo('adminuser');
                          }}
                          className="text-xs text-gray-500 hover:text-blue-400 transition-colors text-left"
                        >
                          {ticket.user_profile?.email}
                        </button>
                      </div>
                      <div className="flex flex-col items-end gap-1">
                        {ticket.unread_count && ticket.unread_count > 0 && (
                          <span className="px-2 py-0.5 rounded text-xs font-medium bg-blue-500/20 text-blue-400 animate-pulse">
                            {ticket.unread_count} new
                          </span>
                        )}
                        {ticket.admin_unread_by_user && ticket.admin_unread_by_user > 0 && (
                          <span className="px-2 py-0.5 rounded text-xs font-medium bg-orange-500/20 text-orange-400">
                            {ticket.admin_unread_by_user} unseen
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className={`px-2 py-0.5 rounded text-xs font-medium ${getStatusColor(ticket.status)}`}>
                        {ticket.status.replace('_', ' ')}
                      </span>
                      {ticket.category && (
                        <span
                          className="px-2 py-0.5 rounded text-xs font-medium"
                          style={{
                            backgroundColor: `${ticket.category.color_code}20`,
                            color: ticket.category.color_code,
                          }}
                        >
                          {ticket.category.name}
                        </span>
                      )}
                      <span className="text-xs text-gray-500">
                        {new Date(ticket.created_at).toLocaleDateString()}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="col-span-8">
            {filter === 'templates' ? (
              <div className="bg-gray-800/50 border border-gray-700 rounded-lg h-[calc(100vh-200px)] overflow-hidden flex flex-col">
                <div className="border-b border-gray-700 p-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h2 className="text-xl font-semibold text-white mb-1">Quick Reply Templates</h2>
                      <p className="text-sm text-gray-400">Manage templates for admin and user support chat</p>
                    </div>
                    <button
                      onClick={() => setIsCreatingTemplate(true)}
                      className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
                    >
                      <Plus className="w-4 h-4" />
                      Add Template
                    </button>
                  </div>

                  <div className="flex gap-2 mt-4">
                    {(['all', 'admin', 'user'] as const).map((type) => (
                      <button
                        key={type}
                        onClick={() => setTemplateTypeFilter(type)}
                        className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                          templateTypeFilter === type
                            ? 'bg-blue-600 text-white'
                            : 'bg-gray-700/50 text-gray-400 hover:text-white'
                        }`}
                      >
                        {type === 'all' ? 'All Templates' : type === 'admin' ? 'Admin Templates' : 'User Templates'}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="flex-1 overflow-y-auto p-6 space-y-3">
                  {templatesLoading ? (
                    <div className="text-center py-8">
                      <div className="animate-spin w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full mx-auto mb-2" />
                      <p className="text-gray-400">Loading templates...</p>
                    </div>
                  ) : filteredTemplates.length === 0 ? (
                    <div className="text-center py-8">
                      <FileText className="w-12 h-12 text-gray-600 mx-auto mb-3" />
                      <p className="text-gray-400">No templates found</p>
                    </div>
                  ) : (
                    filteredTemplates.map((template) => (
                      <div
                        key={template.id}
                        className={`bg-gray-700/30 border rounded-lg p-4 ${
                          template.is_active ? 'border-gray-600' : 'border-gray-700 opacity-60'
                        }`}
                      >
                        {editingTemplate?.id === template.id ? (
                          <div className="space-y-3">
                            <div className="grid grid-cols-2 gap-3">
                              <div>
                                <label className="text-xs text-gray-400 mb-1 block">Command</label>
                                <input
                                  type="text"
                                  value={editingTemplate.command}
                                  onChange={(e) => setEditingTemplate({ ...editingTemplate, command: e.target.value })}
                                  className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white text-sm"
                                  placeholder="/command"
                                />
                              </div>
                              <div>
                                <label className="text-xs text-gray-400 mb-1 block">Label</label>
                                <input
                                  type="text"
                                  value={editingTemplate.label}
                                  onChange={(e) => setEditingTemplate({ ...editingTemplate, label: e.target.value })}
                                  className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white text-sm"
                                  placeholder="Short label"
                                />
                              </div>
                            </div>
                            <div>
                              <label className="text-xs text-gray-400 mb-1 block">Message</label>
                              <textarea
                                value={editingTemplate.message}
                                onChange={(e) => setEditingTemplate({ ...editingTemplate, message: e.target.value })}
                                rows={4}
                                className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white text-sm resize-none"
                                placeholder="Template message..."
                              />
                            </div>
                            <div className="flex items-center justify-between">
                              <label className="flex items-center gap-2 cursor-pointer">
                                <input
                                  type="checkbox"
                                  checked={editingTemplate.is_active}
                                  onChange={(e) => setEditingTemplate({ ...editingTemplate, is_active: e.target.checked })}
                                  className="w-4 h-4 rounded bg-gray-700 border-gray-600 text-blue-600 focus:ring-blue-500"
                                />
                                <span className="text-sm text-gray-300">Active</span>
                              </label>
                              <div className="flex gap-2">
                                <button
                                  onClick={() => setEditingTemplate(null)}
                                  className="px-3 py-1.5 text-gray-400 hover:text-white transition-colors"
                                >
                                  Cancel
                                </button>
                                <button
                                  onClick={handleUpdateTemplate}
                                  className="flex items-center gap-1 px-3 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded transition-colors text-sm"
                                >
                                  <Save className="w-3.5 h-3.5" />
                                  Save
                                </button>
                              </div>
                            </div>
                          </div>
                        ) : (
                          <div>
                            <div className="flex items-start justify-between mb-2">
                              <div className="flex items-center gap-2">
                                <span className="text-blue-400 font-mono text-sm">{template.command}</span>
                                <span className="px-2 py-0.5 rounded text-xs font-medium bg-gray-600 text-gray-300">
                                  {template.label}
                                </span>
                                <span className={`px-2 py-0.5 rounded text-xs font-medium ${
                                  template.template_type === 'admin'
                                    ? 'bg-blue-500/20 text-blue-400'
                                    : 'bg-green-500/20 text-green-400'
                                }`}>
                                  {template.template_type}
                                </span>
                                {!template.is_active && (
                                  <span className="px-2 py-0.5 rounded text-xs font-medium bg-red-500/20 text-red-400">
                                    Inactive
                                  </span>
                                )}
                              </div>
                              <div className="flex items-center gap-1">
                                <button
                                  onClick={() => handleToggleActive(template)}
                                  className="p-1.5 text-gray-400 hover:text-white transition-colors"
                                  title={template.is_active ? 'Deactivate' : 'Activate'}
                                >
                                  {template.is_active ? (
                                    <ToggleRight className="w-5 h-5 text-green-500" />
                                  ) : (
                                    <ToggleLeft className="w-5 h-5 text-gray-500" />
                                  )}
                                </button>
                                <button
                                  onClick={() => setEditingTemplate(template)}
                                  className="p-1.5 text-gray-400 hover:text-blue-400 transition-colors"
                                  title="Edit"
                                >
                                  <Edit2 className="w-4 h-4" />
                                </button>
                                <button
                                  onClick={() => handleDeleteTemplate(template)}
                                  className="p-1.5 text-gray-400 hover:text-red-400 transition-colors"
                                  title="Delete"
                                >
                                  <Trash2 className="w-4 h-4" />
                                </button>
                              </div>
                            </div>
                            <p className="text-sm text-gray-300 whitespace-pre-wrap line-clamp-3">{template.message}</p>
                          </div>
                        )}
                      </div>
                    ))
                  )}
                </div>

                {isCreatingTemplate && (
                  <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
                    <div className="bg-gray-800 border border-gray-700 rounded-xl w-full max-w-lg mx-4 p-6">
                      <div className="flex items-center justify-between mb-4">
                        <h3 className="text-lg font-semibold text-white">Create New Template</h3>
                        <button
                          onClick={() => {
                            setIsCreatingTemplate(false);
                            setNewTemplate({ command: '', label: '', message: '', template_type: 'admin' });
                          }}
                          className="p-1 text-gray-400 hover:text-white transition-colors"
                        >
                          <X className="w-5 h-5" />
                        </button>
                      </div>

                      <div className="space-y-4">
                        <div>
                          <label className="text-sm text-gray-400 mb-1 block">Template Type</label>
                          <div className="flex gap-2">
                            <button
                              onClick={() => setNewTemplate({ ...newTemplate, template_type: 'admin' })}
                              className={`flex-1 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                                newTemplate.template_type === 'admin'
                                  ? 'bg-blue-600 text-white'
                                  : 'bg-gray-700 text-gray-400 hover:text-white'
                              }`}
                            >
                              Admin Template
                            </button>
                            <button
                              onClick={() => setNewTemplate({ ...newTemplate, template_type: 'user' })}
                              className={`flex-1 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                                newTemplate.template_type === 'user'
                                  ? 'bg-green-600 text-white'
                                  : 'bg-gray-700 text-gray-400 hover:text-white'
                              }`}
                            >
                              User Template
                            </button>
                          </div>
                        </div>

                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <label className="text-sm text-gray-400 mb-1 block">Command</label>
                            <input
                              type="text"
                              value={newTemplate.command}
                              onChange={(e) => setNewTemplate({ ...newTemplate, command: e.target.value })}
                              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white"
                              placeholder="/command"
                            />
                          </div>
                          <div>
                            <label className="text-sm text-gray-400 mb-1 block">Label</label>
                            <input
                              type="text"
                              value={newTemplate.label}
                              onChange={(e) => setNewTemplate({ ...newTemplate, label: e.target.value })}
                              className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white"
                              placeholder="Short label"
                            />
                          </div>
                        </div>

                        <div>
                          <label className="text-sm text-gray-400 mb-1 block">Message</label>
                          <textarea
                            value={newTemplate.message}
                            onChange={(e) => setNewTemplate({ ...newTemplate, message: e.target.value })}
                            rows={5}
                            className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white resize-none"
                            placeholder="Enter the template message..."
                          />
                        </div>

                        <div className="flex justify-end gap-3 pt-2">
                          <button
                            onClick={() => {
                              setIsCreatingTemplate(false);
                              setNewTemplate({ command: '', label: '', message: '', template_type: 'admin' });
                            }}
                            className="px-4 py-2 text-gray-400 hover:text-white transition-colors"
                          >
                            Cancel
                          </button>
                          <button
                            onClick={handleCreateTemplate}
                            disabled={!newTemplate.command || !newTemplate.label || !newTemplate.message}
                            className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                          >
                            Create Template
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            ) : selectedTicket && selectedTicketData ? (
              <div className="bg-gray-800/50 border border-gray-700 rounded-lg flex flex-col h-[calc(100vh-200px)]">
                <div className="border-b border-gray-700 p-6">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h2 className="text-xl font-semibold text-white mb-2">
                        {selectedTicketData.subject}
                      </h2>
                      <p className="text-sm text-gray-400">
                        {selectedTicketData.user_profile?.username} (
                        <button
                          onClick={() => {
                            localStorage.setItem('adminSelectedUserId', selectedTicketData.user_id);
                            navigateTo('adminuser');
                          }}
                          className="text-yellow-500 hover:text-yellow-400 transition-colors hover:underline"
                        >
                          {selectedTicketData.user_profile?.email}
                        </button>
                        )
                      </p>
                    </div>
                    <select
                      value={selectedTicketData.status}
                      onChange={(e) => handleStatusChange(selectedTicket, e.target.value)}
                      className="px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
                    >
                      <option value="open">Open</option>
                      <option value="in_progress">In Progress</option>
                      <option value="waiting_user">Waiting User</option>
                      <option value="waiting_admin">Waiting Admin</option>
                      <option value="resolved">Resolved</option>
                      <option value="closed">Closed</option>
                    </select>
                  </div>
                </div>

                <div className="flex-1 overflow-y-auto p-6 space-y-4">
                  {messages.map((msg) => (
                    <div
                      key={msg.id}
                      className={`flex gap-3 ${msg.sender_type === 'admin' ? 'flex-row-reverse' : ''} ${
                        msg.pending ? 'opacity-70' : ''
                      } animate-in fade-in slide-in-from-bottom-2 duration-300`}
                    >
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                        msg.sender_type === 'admin' ? 'bg-blue-600' : 'bg-gray-700'
                      }`}>
                        <User className="w-4 h-4 text-white" />
                      </div>
                      <div className={`flex-1 max-w-[70%]`}>
                        <div className={`rounded-lg p-4 ${
                          msg.sender_type === 'admin'
                            ? msg.failed
                              ? 'bg-red-600/50 text-white'
                              : 'bg-blue-600 text-white'
                            : 'bg-gray-700 text-gray-100'
                        }`}>
                          <p className="text-sm font-medium mb-1">{msg.sender_profile?.username}</p>
                          <p className="text-sm whitespace-pre-wrap">{msg.message}</p>

                          {msg.attachments && msg.attachments.length > 0 && (
                            <div className="mt-3 space-y-2">
                              {msg.attachments.map((attachment) => (
                                attachment.mime_type.startsWith('image/') ? (
                                  <div key={attachment.id} className="relative group">
                                    {loadedImages[attachment.id] ? (
                                      <img
                                        src={loadedImages[attachment.id]}
                                        alt={attachment.file_name}
                                        className="max-w-full max-h-64 rounded-lg cursor-pointer hover:opacity-90 transition-opacity"
                                        onClick={() => viewAttachment(attachment.id)}
                                      />
                                    ) : (
                                      <div className={`flex items-center justify-center w-full h-32 rounded-lg ${
                                        msg.sender_type === 'admin' ? 'bg-white/10' : 'bg-gray-600/50'
                                      }`}>
                                        <div className="flex flex-col items-center gap-2">
                                          <div className="w-6 h-6 border-2 border-current border-t-transparent rounded-full animate-spin opacity-50" />
                                          <span className="text-xs opacity-70">Loading image...</span>
                                        </div>
                                      </div>
                                    )}
                                    <div className="absolute bottom-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                      <button
                                        onClick={() => viewAttachment(attachment.id)}
                                        className="p-1.5 bg-black/60 rounded-lg hover:bg-black/80 transition-colors"
                                        title="View full size"
                                      >
                                        <Image className="w-4 h-4" />
                                      </button>
                                    </div>
                                    <p className="text-[10px] opacity-60 mt-1">{attachment.file_name}</p>
                                  </div>
                                ) : (
                                  <button
                                    key={attachment.id}
                                    onClick={() => viewAttachment(attachment.id)}
                                    className={`flex items-center gap-2 p-2 rounded-lg transition-colors w-full ${
                                      msg.sender_type === 'admin'
                                        ? 'bg-white/10 hover:bg-white/20'
                                        : 'bg-gray-600/50 hover:bg-gray-600'
                                    }`}
                                  >
                                    <Paperclip className="w-4 h-4 flex-shrink-0" />
                                    <div className="flex-1 text-left min-w-0">
                                      <p className="text-xs font-medium truncate">{attachment.file_name}</p>
                                      <p className="text-[10px] opacity-70">{formatFileSize(attachment.file_size)}</p>
                                    </div>
                                    <Download className="w-3 h-3 flex-shrink-0 opacity-70" />
                                  </button>
                                )
                              ))}
                            </div>
                          )}

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
                        </div>
                        <div className={`text-xs text-gray-500 mt-1 flex items-center gap-1.5 ${msg.sender_type === 'admin' ? 'justify-end' : ''}`}>
                          {msg.pending ? (
                            <span>Sending...</span>
                          ) : msg.failed ? (
                            <span className="text-red-400">Failed</span>
                          ) : (
                            <>
                              {new Date(msg.created_at).toLocaleString()}
                              {msg.sender_type === 'admin' && (
                                msg.read_at ? (
                                  <span className="flex items-center gap-1 text-green-500" title={`Seen at ${new Date(msg.read_at).toLocaleString()}`}>
                                    <Eye className="w-3 h-3" />
                                    <span className="text-[10px]">Seen</span>
                                  </span>
                                ) : (
                                  <span className="flex items-center gap-1 text-orange-400" title="Not seen by user">
                                    <EyeOff className="w-3 h-3" />
                                    <span className="text-[10px]">Not seen</span>
                                  </span>
                                )
                              )}
                            </>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                  <div ref={messagesEndRef} />
                </div>

                {selectedTicketData.status !== 'closed' && (
                  <div className="border-t border-gray-700 p-6">
                    <div className="relative">
                      {showQuickReplies && filteredQuickReplies.length > 0 && (
                        <div className="absolute bottom-full left-0 right-0 mb-2 bg-gray-800 border border-gray-600 rounded-lg shadow-xl overflow-hidden z-10 max-h-72 overflow-y-auto">
                          <div className="px-3 py-2 border-b border-gray-700 bg-gray-800/80 sticky top-0">
                            <div className="flex items-center gap-2 text-xs text-gray-400">
                              <Zap className="w-3 h-3 text-yellow-500" />
                              <span>Quick Replies - Arrow keys to navigate, Tab/Enter to select</span>
                            </div>
                          </div>
                          {filteredQuickReplies.map((reply, index) => (
                            <button
                              key={reply.command}
                              ref={(el) => (quickReplyRefs.current[index] = el)}
                              type="button"
                              onClick={() => selectQuickReply(reply)}
                              className={`w-full px-4 py-3 text-left hover:bg-gray-700/50 transition-colors ${
                                index === selectedQuickReplyIndex ? 'bg-blue-600/20 border-l-2 border-blue-500' : ''
                              }`}
                            >
                              <div className="flex items-center justify-between mb-1">
                                <span className="text-blue-400 font-mono text-sm">{reply.command}</span>
                                <span className="text-xs text-gray-500 bg-gray-700/50 px-2 py-0.5 rounded">{reply.label}</span>
                              </div>
                              <p className="text-sm text-gray-300 line-clamp-2">{reply.message}</p>
                            </button>
                          ))}
                        </div>
                      )}

                      <form onSubmit={handleSendMessage} className="flex gap-3">
                        <div className="flex-1 relative">
                          <textarea
                            ref={textareaRef}
                            value={newMessage}
                            onChange={handleMessageChange}
                            placeholder="Type your response... (Press / for quick replies)"
                            rows={3}
                            className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500 resize-none"
                            disabled={sending}
                            onKeyDown={handleTextareaKeyDown}
                            onBlur={() => {
                              setTimeout(() => setShowQuickReplies(false), 200);
                            }}
                          />
                        </div>
                        <button
                          type="submit"
                          disabled={sending || !newMessage.trim()}
                          className="px-6 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {sending ? 'Sending...' : 'Send'}
                        </button>
                      </form>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="bg-gray-800/50 border border-gray-700 rounded-lg h-[calc(100vh-200px)] flex items-center justify-center">
                <div className="text-center">
                  <MessageSquare className="w-16 h-16 text-gray-600 mx-auto mb-4" />
                  <h3 className="text-lg font-medium text-white mb-2">No Ticket Selected</h3>
                  <p className="text-gray-400">Select a ticket to view and respond</p>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
