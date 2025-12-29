import { useState, useEffect, useRef, useCallback } from 'react';
import { MessageSquare, Clock, CheckCircle, User, Search, Filter, Wifi, WifiOff } from 'lucide-react';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { loggingService } from '../services/loggingService';
import { useNotificationSound, ConnectionStatus } from '../hooks/useNotificationSound';

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
}

interface Message {
  id: string;
  sender_id: string;
  sender_type: 'user' | 'admin';
  message: string;
  created_at: string;
  sender_profile?: { username: string };
  pending?: boolean;
  failed?: boolean;
}

export default function AdminSupport() {
  const { user, profile } = useAuth();
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [selectedTicket, setSelectedTicket] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [filter, setFilter] = useState<'all' | 'open' | 'pending'>('open');
  const [searchQuery, setSearchQuery] = useState('');
  const [connectionStatus, setConnectionStatus] = useState<ConnectionStatus>('connecting');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const ticketSubscriptionRef = useRef<any>(null);
  const messageSubscriptionRef = useRef<any>(null);
  const { playSound } = useNotificationSound({ enabled: true, volume: 0.5 });

  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, scrollToBottom]);

  useEffect(() => {
    if (user && profile?.is_admin) {
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
      const { data, error } = await supabase
        .from('support_messages')
        .select('*')
        .eq('ticket_id', selectedTicket)
        .order('created_at', { ascending: true });

      if (error) throw error;

      const messagesWithProfiles = await Promise.all(
        (data || []).map(async (msg) => {
          if (msg.sender_type === 'user') {
            const { data: profileData } = await supabase
              .from('user_profiles')
              .select('username')
              .eq('id', msg.sender_id)
              .single();

            return { ...msg, sender_profile: { username: profileData?.username || 'User' } };
          }
          return { ...msg, sender_profile: { username: 'Support' } };
        })
      );

      setMessages(messagesWithProfiles);

      await supabase
        .from('support_messages')
        .update({ read_at: new Date().toISOString() })
        .eq('ticket_id', selectedTicket)
        .eq('sender_type', 'user')
        .is('read_at', null);
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

  const selectedTicketData = tickets.find(t => t.id === selectedTicket);

  const filteredTickets = tickets.filter(t =>
    t.subject.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.user_profile?.username.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.user_profile?.email.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (!profile?.is_admin) {
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
              {(['all', 'open', 'pending'] as const).map((f) => (
                <button
                  key={f}
                  onClick={() => setFilter(f)}
                  className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                    filter === f
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-800/50 text-gray-400 hover:text-white'
                  }`}
                >
                  {f.charAt(0).toUpperCase() + f.slice(1)}
                </button>
              ))}
            </div>

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
                      <p className="text-xs text-gray-500">{ticket.user_profile?.email}</p>
                    </div>
                    {ticket.unread_count && ticket.unread_count > 0 && (
                      <span className="px-2 py-0.5 rounded text-xs font-medium bg-blue-500/20 text-blue-400 animate-pulse">
                        {ticket.unread_count}
                      </span>
                    )}
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
          </div>

          <div className="col-span-8">
            {selectedTicket && selectedTicketData ? (
              <div className="bg-gray-800/50 border border-gray-700 rounded-lg flex flex-col h-[calc(100vh-200px)]">
                <div className="border-b border-gray-700 p-6">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h2 className="text-xl font-semibold text-white mb-2">
                        {selectedTicketData.subject}
                      </h2>
                      <p className="text-sm text-gray-400">
                        {selectedTicketData.user_profile?.username} ({selectedTicketData.user_profile?.email})
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
                        <div className={`text-xs text-gray-500 mt-1 flex items-center gap-1 ${msg.sender_type === 'admin' ? 'justify-end' : ''}`}>
                          {msg.pending ? (
                            <span>Sending...</span>
                          ) : msg.failed ? (
                            <span className="text-red-400">Failed</span>
                          ) : (
                            <>
                              {new Date(msg.created_at).toLocaleString()}
                              {msg.sender_type === 'admin' && <CheckCircle className="w-3 h-3 text-green-500" />}
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
                    <form onSubmit={handleSendMessage} className="flex gap-3">
                      <textarea
                        value={newMessage}
                        onChange={(e) => setNewMessage(e.target.value)}
                        placeholder="Type your response..."
                        rows={3}
                        className="flex-1 px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500 resize-none"
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
                        disabled={sending || !newMessage.trim()}
                        className="px-6 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {sending ? 'Sending...' : 'Send'}
                      </button>
                    </form>
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
