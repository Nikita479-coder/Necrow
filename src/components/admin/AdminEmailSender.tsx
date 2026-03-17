import { useState, useEffect } from 'react';
import { Mail, Send, Eye, Clock } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useToast } from '../../hooks/useToast';

interface Props {
  userId: string;
  userData: any;
  onRefresh: () => void;
}

interface EmailTemplate {
  id: string;
  name: string;
  subject: string;
  body: string;
  category: string;
}

interface EmailLog {
  id: string;
  template_name: string;
  subject: string;
  status: string;
  sent_at: string;
  sent_by_username: string;
}

export default function AdminEmailSender({ userId, userData, onRefresh }: Props) {
  const { showToast } = useToast();
  const [templates, setTemplates] = useState<EmailTemplate[]>([]);
  const [emailLogs, setEmailLogs] = useState<EmailLog[]>([]);
  const [selectedTemplate, setSelectedTemplate] = useState<string>('');
  const [customSubject, setCustomSubject] = useState('');
  const [customBody, setCustomBody] = useState('');
  const [customVariables, setCustomVariables] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPreview, setShowPreview] = useState(false);
  const [previewSubject, setPreviewSubject] = useState('');
  const [previewBody, setPreviewBody] = useState('');

  useEffect(() => {
    loadTemplates();
    loadEmailHistory();
  }, [userId]);

  useEffect(() => {
    if (selectedTemplate) {
      const template = templates.find(t => t.id === selectedTemplate);
      if (template) {
        setCustomSubject(template.subject);
        setCustomBody(template.body);
        updatePreview(template.subject, template.body);
      }
    }
  }, [selectedTemplate, templates]);

  const loadTemplates = async () => {
    try {
      const { data, error } = await supabase
        .from('email_templates')
        .select('*')
        .eq('is_active', true)
        .order('name');

      if (error) throw error;
      setTemplates(data || []);
    } catch (error: any) {
      showToast('Failed to load templates: ' + error.message, 'error');
    }
  };

  const loadEmailHistory = async () => {
    try {
      const { data, error } = await supabase.rpc('get_user_email_history', {
        p_user_id: userId,
        p_limit: 10,
        p_offset: 0
      });

      if (error) throw error;
      setEmailLogs(data || []);
    } catch (error: any) {
      console.error('Failed to load email history:', error);
    }
  };

  const updatePreview = (subject: string, body: string) => {
    const balance = userData?.wallets?.find((w: any) => w.currency === 'USDT')?.balance || '0';

    const variables: Record<string, string> = {
      '{{username}}': userData?.profile?.username || 'User',
      '{{email}}': userData?.authUser?.email || 'user@example.com',
      '{{full_name}}': userData?.profile?.full_name || 'Valued Customer',
      '{{kyc_level}}': userData?.profile?.kyc_level?.toString() || '0',
      '{{kyc_status}}': userData?.profile?.kyc_status || 'unverified',
      '{{balance}}': balance,
      '{{platform_name}}': 'Crypto Exchange',
      '{{support_email}}': 'support@cryptoexchange.com',
      '{{website_url}}': 'https://cryptoexchange.com',
    };

    // Parse custom variables if provided
    if (customVariables) {
      try {
        const parsed = JSON.parse(customVariables);
        Object.assign(variables, parsed);
      } catch (e) {
        console.error('Invalid custom variables JSON');
      }
    }

    let previewSub = subject;
    let previewBod = body;

    Object.entries(variables).forEach(([key, value]) => {
      previewSub = previewSub.replaceAll(key, value);
      previewBod = previewBod.replaceAll(key, value);
    });

    setPreviewSubject(previewSub);
    setPreviewBody(previewBod);
  };

  useEffect(() => {
    updatePreview(customSubject, customBody);
  }, [customSubject, customBody, customVariables, userData]);

  const handleSendEmail = async () => {
    if (!customSubject || !customBody) {
      showToast('Subject and body are required', 'error');
      return;
    }

    if (!confirm('Are you sure you want to send this email to the user?')) {
      return;
    }

    setLoading(true);
    try {
      const session = await supabase.auth.getSession();
      const token = session.data.session?.access_token;

      if (!token) {
        throw new Error('Not authenticated');
      }

      const apiUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-email`;

      const requestBody: any = {
        user_id: userId,
        subject: customSubject,
        body: customBody,
      };

      if (selectedTemplate) {
        requestBody.template_id = selectedTemplate;
      }

      if (customVariables) {
        try {
          requestBody.custom_variables = JSON.parse(customVariables);
        } catch (e) {
          showToast('Invalid custom variables JSON', 'error');
          setLoading(false);
          return;
        }
      }

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      });

      const result = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(result.error || 'Failed to send email');
      }

      showToast('Email sent successfully!', 'success');
      setSelectedTemplate('');
      setCustomSubject('');
      setCustomBody('');
      setCustomVariables('');
      await loadEmailHistory();
      onRefresh();
    } catch (error: any) {
      showToast('Failed to send email: ' + error.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'sent': return 'text-green-400';
      case 'failed': return 'text-red-400';
      case 'pending': return 'text-yellow-400';
      default: return 'text-gray-400';
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-white mb-4">Send Email</h2>
        <div className="bg-[#0b0e11] rounded-xl p-6 border border-gray-800 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Select Template (Optional)</label>
            <select
              value={selectedTemplate}
              onChange={(e) => setSelectedTemplate(e.target.value)}
              className="w-full bg-[#1a1d24] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
              disabled={loading}
            >
              <option value="">Custom Email (No Template)</option>
              {templates.map(template => (
                <option key={template.id} value={template.id}>
                  {template.name} ({template.category})
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Email Subject</label>
            <input
              type="text"
              value={customSubject}
              onChange={(e) => setCustomSubject(e.target.value)}
              className="w-full bg-[#1a1d24] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors"
              placeholder="Enter email subject..."
              disabled={loading}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Email Body</label>
            <textarea
              value={customBody}
              onChange={(e) => setCustomBody(e.target.value)}
              rows={8}
              className="w-full bg-[#1a1d24] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors font-mono text-sm"
              placeholder="Enter email body..."
              disabled={loading}
            />
            <p className="text-xs text-gray-500 mt-2">
              Available variables: {'{{username}}'}, {'{{email}}'}, {'{{full_name}}'}, {'{{balance}}'}, {'{{kyc_level}}'}, {'{{platform_name}}'}
            </p>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">Custom Variables (JSON, Optional)</label>
            <textarea
              value={customVariables}
              onChange={(e) => setCustomVariables(e.target.value)}
              rows={2}
              className="w-full bg-[#1a1d24] border border-gray-800 rounded-lg px-4 py-3 text-white outline-none focus:border-[#f0b90b] transition-colors font-mono text-sm"
              placeholder='{"{{custom_var}}": "value"}'
              disabled={loading}
            />
          </div>

          <div className="flex gap-3">
            <button
              onClick={() => setShowPreview(!showPreview)}
              disabled={loading}
              className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg border border-blue-500/30 transition-colors disabled:opacity-50"
            >
              <Eye className="w-5 h-5" />
              {showPreview ? 'Hide Preview' : 'Preview'}
            </button>
            <button
              onClick={handleSendEmail}
              disabled={loading || !customSubject || !customBody}
              className="flex-1 flex items-center justify-center gap-2 px-6 py-3 bg-[#f0b90b] hover:bg-[#f8d12f] text-black rounded-lg font-bold transition-colors disabled:opacity-50"
            >
              <Send className="w-5 h-5" />
              {loading ? 'Sending...' : 'Send Email'}
            </button>
          </div>

          {showPreview && (
            <div className="bg-[#1a1d24] rounded-lg p-4 border border-gray-700 space-y-3">
              <div>
                <p className="text-xs font-medium text-gray-400 mb-1">Preview Subject:</p>
                <p className="text-white">{previewSubject}</p>
              </div>
              <div>
                <p className="text-xs font-medium text-gray-400 mb-1">Preview Body:</p>
                <div className="text-gray-300 whitespace-pre-wrap">{previewBody}</div>
              </div>
            </div>
          )}
        </div>
      </div>

      <div>
        <h2 className="text-xl font-bold text-white mb-4">Email History</h2>
        <div className="bg-[#0b0e11] rounded-xl border border-gray-800 overflow-hidden">
          {emailLogs.length === 0 ? (
            <div className="p-8 text-center">
              <Mail className="w-12 h-12 text-gray-600 mx-auto mb-3" />
              <p className="text-gray-400">No emails sent to this user yet</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-[#1a1d24] border-b border-gray-800">
                  <tr>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Template</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Subject</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Status</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Sent By</th>
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-400">Date</th>
                  </tr>
                </thead>
                <tbody>
                  {emailLogs.map((log) => (
                    <tr key={log.id} className="border-b border-gray-800/50 hover:bg-[#1a1d24] transition-colors">
                      <td className="py-3 px-4 text-white text-sm">{log.template_name}</td>
                      <td className="py-3 px-4 text-gray-300 text-sm">{log.subject}</td>
                      <td className={`py-3 px-4 text-sm font-medium ${getStatusColor(log.status)}`}>
                        {log.status.toUpperCase()}
                      </td>
                      <td className="py-3 px-4 text-gray-300 text-sm">{log.sent_by_username}</td>
                      <td className="py-3 px-4 text-gray-400 text-sm">
                        <div className="flex items-center gap-2">
                          <Clock className="w-4 h-4" />
                          {new Date(log.sent_at).toLocaleString()}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
