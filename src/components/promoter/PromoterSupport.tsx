import { useState, useEffect, useRef } from 'react';
import { MessageSquare, Send, ArrowLeft, Clock, CheckCircle, AlertCircle } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';

interface Ticket {
  id: string;
  user_id: string;
  subject: string;
  status: string;
  priority: string;
  created_at: string;
  updated_at: string;
  first_response_at: string | null;
  user_email: string;
  user_username: string | null;
  unread_count: number;
  first_message: string | null;
}

interface Message {
  id: string;
  sender_id: string;
  sender_type: 'user' | 'admin';
  message: string;
  created_at: string;
  read_at: string | null;
}

export default function PromoterSupport() {
  const { user } = useAuth();
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedTicket, setSelectedTicket] = useState<Ticket | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [newMessage, setNewMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    loadTickets();
  }, []);

  useEffect(() => {
    if (selectedTicket) {
      loadMessages(selectedTicket.id);
      const channel = supabase
        .channel(`promoter_ticket_${selectedTicket.id}`)
        .on('postgres_changes', {
          event: 'INSERT',
          schema: 'public',
          table: 'support_messages',
          filter: `ticket_id=eq.${selectedTicket.id}`,
        }, () => {
          loadMessages(selectedTicket.id);
        })
        .subscribe();
      return () => { supabase.removeChannel(channel); };
    }
  }, [selectedTicket?.id]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const loadTickets = async () => {
    try {
      const { data, error } = await supabase.rpc('promoter_get_support_tickets');
      if (error) throw error;
      if (data?.success) {
        setTickets(data.tickets || []);
      }
    } catch (err) {
      console.error('Failed to load tickets:', err);
    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async (ticketId: string) => {
    setMessagesLoading(true);
    try {
      const { data, error } = await supabase.rpc('promoter_get_ticket_messages', {
        p_ticket_id: ticketId,
      });
      if (error) throw error;
      if (data?.success) {
        setMessages(data.messages || []);
      }
    } catch (err) {
      console.error('Failed to load messages:', err);
    } finally {
      setMessagesLoading(false);
    }
  };

  const handleSendMessage = async () => {
    if (!newMessage.trim() || !selectedTicket || sending) return;
    setSending(true);
    try {
      const { data, error } = await supabase.rpc('promoter_send_support_reply', {
        p_ticket_id: selectedTicket.id,
        p_message: newMessage.trim(),
      });
      if (error) throw error;
      if (data?.success) {
        setNewMessage('');
        await loadMessages(selectedTicket.id);
        await loadTickets();
      }
    } catch (err) {
      console.error('Failed to send message:', err);
    } finally {
      setSending(false);
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'open': return <AlertCircle className="w-3 h-3 text-yellow-400" />;
      case 'in_progress': return <Clock className="w-3 h-3 text-blue-400" />;
      case 'resolved':
      case 'closed': return <CheckCircle className="w-3 h-3 text-emerald-400" />;
      default: return <Clock className="w-3 h-3 text-gray-400" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open': return 'bg-yellow-500/20 text-yellow-400';
      case 'in_progress': return 'bg-blue-500/20 text-blue-400';
      case 'resolved':
      case 'closed': return 'bg-emerald-500/20 text-emerald-400';
      default: return 'bg-gray-500/20 text-gray-400';
    }
  };

  const filteredTickets = tickets.filter(t => filterStatus === 'all' || t.status === filterStatus);

  if (loading) {
    return (
      <div className="text-center py-12">
        <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#f0b90b]" />
      </div>
    );
  }

  if (selectedTicket) {
    return (
      <div className="space-y-4">
        <button
          onClick={() => { setSelectedTicket(null); setMessages([]); }}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to tickets
        </button>

        <div className="bg-[#1a1d24] rounded-xl border border-gray-800 p-4">
          <div className="flex items-start justify-between mb-2">
            <div>
              <h3 className="text-white font-medium">{selectedTicket.subject}</h3>
              <p className="text-xs text-gray-400">
                {selectedTicket.user_username || selectedTicket.user_email} -- {new Date(selectedTicket.created_at).toLocaleString()}
              </p>
            </div>
            <span className={`text-xs px-2 py-1 rounded-md font-medium ${getStatusColor(selectedTicket.status)}`}>
              {selectedTicket.status.replace('_', ' ')}
            </span>
          </div>
        </div>

        <div className="bg-[#1a1d24] rounded-xl border border-gray-800 flex flex-col" style={{ height: '500px' }}>
          <div className="flex-1 overflow-y-auto p-4 space-y-3">
            {messagesLoading ? (
              <div className="text-center py-8">
                <div className="inline-block animate-spin rounded-full h-6 w-6 border-b-2 border-[#f0b90b]" />
              </div>
            ) : messages.length === 0 ? (
              <p className="text-center text-gray-500 py-8">No messages yet</p>
            ) : (
              messages.map(msg => {
                const isAdmin = msg.sender_type === 'admin';
                return (
                  <div key={msg.id} className={`flex ${isAdmin ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-[75%] rounded-2xl px-4 py-3 ${
                      isAdmin
                        ? 'bg-[#f0b90b]/15 border border-[#f0b90b]/30'
                        : 'bg-[#0b0e11] border border-gray-700'
                    }`}>
                      <div className="flex items-center gap-2 mb-1">
                        <span className={`text-xs font-medium ${isAdmin ? 'text-[#f0b90b]' : 'text-gray-400'}`}>
                          {isAdmin ? 'Platform' : (selectedTicket.user_username || 'User')}
                        </span>
                        <span className="text-xs text-gray-600">
                          {new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </span>
                      </div>
                      <p className="text-sm text-white whitespace-pre-wrap break-words">{msg.message}</p>
                    </div>
                  </div>
                );
              })
            )}
            <div ref={messagesEndRef} />
          </div>

          <div className="border-t border-gray-800 p-4">
            <div className="flex gap-3">
              <input
                type="text"
                value={newMessage}
                onChange={e => setNewMessage(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); handleSendMessage(); } }}
                placeholder="Type your reply..."
                className="flex-1 bg-[#0b0e11] border border-gray-700 rounded-xl px-4 py-2.5 text-white placeholder-gray-500 focus:outline-none focus:border-[#f0b90b]/50 text-sm"
              />
              <button
                onClick={handleSendMessage}
                disabled={!newMessage.trim() || sending}
                className="bg-[#f0b90b] text-black px-4 py-2.5 rounded-xl font-medium hover:bg-[#f0b90b]/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center gap-2 text-sm"
              >
                <Send className="w-4 h-4" />
                Send
              </button>
            </div>
            <p className="text-xs text-gray-600 mt-2">Your replies appear as platform messages to the user.</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-white">Support Tickets</h2>
          <p className="text-sm text-gray-400">{tickets.length} tickets from your tree users</p>
        </div>
        <div className="flex gap-2">
          {['all', 'open', 'in_progress', 'resolved', 'closed'].map(status => (
            <button
              key={status}
              onClick={() => setFilterStatus(status)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                filterStatus === status
                  ? 'bg-[#f0b90b] text-black'
                  : 'bg-[#1a1d24] text-gray-400 hover:text-white border border-gray-800'
              }`}
            >
              {status === 'all' ? 'All' : status.replace('_', ' ')}
            </button>
          ))}
        </div>
      </div>

      {filteredTickets.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          <MessageSquare className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>No tickets found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredTickets.map(ticket => (
            <button
              key={ticket.id}
              onClick={() => setSelectedTicket(ticket)}
              className="w-full bg-[#1a1d24] rounded-xl border border-gray-800 p-4 hover:border-gray-700 transition-all text-left group"
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    {getStatusIcon(ticket.status)}
                    <h3 className="text-sm text-white font-medium truncate group-hover:text-[#f0b90b] transition-colors">
                      {ticket.subject}
                    </h3>
                    {ticket.unread_count > 0 && (
                      <span className="bg-[#f0b90b] text-black text-xs px-1.5 py-0.5 rounded-full font-bold min-w-[20px] text-center">
                        {ticket.unread_count}
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-gray-500 mb-2">
                    {ticket.user_username || ticket.user_email} -- {new Date(ticket.created_at).toLocaleDateString()}
                  </p>
                  {ticket.first_message && (
                    <p className="text-xs text-gray-400 line-clamp-2">{ticket.first_message}</p>
                  )}
                </div>
                <span className={`text-xs px-2 py-1 rounded-md font-medium whitespace-nowrap ${getStatusColor(ticket.status)}`}>
                  {ticket.status.replace('_', ' ')}
                </span>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
