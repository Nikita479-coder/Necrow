import { useState, useEffect } from 'react';
import { MessageSquare, Clock, CheckCircle, User, Search, Filter } from 'lucide-react';
import Navbar from '../components/Navbar';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { loggingService } from '../services/loggingService';

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

  useEffect(() => {
    if (user && profile?.is_admin) {
      loadTickets();
      subscribeToTickets();
    }
  }, [user, profile, filter]);

  useEffect(() => {
    if (selectedTicket) {
      loadMessages();
      subscribeToMessages();
    }
  }, [selectedTicket]);

  const loadTickets = async () => {
    try {
      const { data, error } = await supabase.rpc('admin_get_support_tickets_with_users');

      if (error) {
        console.error('RPC Error:', error);
        throw error;
      }

      console.log('Tickets data:', data);

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

      console.log('Processed tickets:', ticketsWithProfiles);
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
    const subscription = supabase
      .channel('admin_tickets')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'support_tickets',
        },
        () => {
          loadTickets();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  };

  const subscribeToMessages = () => {
    if (!selectedTicket) return;

    const subscription = supabase
      .channel(`admin_ticket_${selectedTicket}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
          filter: `ticket_id=eq.${selectedTicket}`,
        },
        () => {
          loadMessages();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user || !selectedTicket || !newMessage.trim()) return;

    setSending(true);
    try {
      const { error } = await supabase
        .from('support_messages')
        .insert({
          ticket_id: selectedTicket,
          sender_id: user.id,
          sender_type: 'admin',
          message: newMessage.trim(),
        });

      if (error) throw error;

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

      setNewMessage('');
      loadTickets();
    } catch (error) {
      console.error('Error sending message:', error);
    } finally {
      setSending(false);
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
        return 'bg-purple-500/10 text-purple-500';
      case 'resolved':
        return 'bg-green-500/10 text-green-500';
      case 'closed':
        return 'bg-gray-500/10 text-gray-500';
      default:
        return 'bg-gray-500/10 text-gray-500';
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
            <h1 className="text-3xl font-bold mb-2">Support Management</h1>
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
                  className={`bg-gray-800/50 border rounded-lg p-4 cursor-pointer transition-colors ${
                    selectedTicket === ticket.id
                      ? 'border-blue-500'
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
                      <span className="px-2 py-0.5 rounded text-xs font-medium bg-blue-500/20 text-blue-400">
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
                      className={`flex gap-3 ${msg.sender_type === 'admin' ? 'flex-row-reverse' : ''}`}
                    >
                      <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                        msg.sender_type === 'admin' ? 'bg-blue-600' : 'bg-gray-700'
                      }`}>
                        <User className="w-4 h-4 text-white" />
                      </div>
                      <div className={`flex-1 max-w-[70%]`}>
                        <div className={`rounded-lg p-4 ${
                          msg.sender_type === 'admin'
                            ? 'bg-blue-600 text-white'
                            : 'bg-gray-700 text-gray-100'
                        }`}>
                          <p className="text-sm font-medium mb-1">{msg.sender_profile?.username}</p>
                          <p className="text-sm whitespace-pre-wrap">{msg.message}</p>
                        </div>
                        <div className={`text-xs text-gray-500 mt-1 ${msg.sender_type === 'admin' ? 'text-right' : ''}`}>
                          {new Date(msg.created_at).toLocaleString()}
                        </div>
                      </div>
                    </div>
                  ))}
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
