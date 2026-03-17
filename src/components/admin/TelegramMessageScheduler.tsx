import { useState, useEffect } from 'react';
import { Send, Clock, Calendar, AlertCircle, CheckCircle, RefreshCw, X, FileText } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface Template {
  id: string;
  name: string;
  content: string;
  variables: string[];
  parse_mode: string;
}

interface Props {
  userId: string;
  selectedTemplate?: Template | null;
  onClearTemplate?: () => void;
}

export default function TelegramMessageScheduler({ userId, selectedTemplate, onClearTemplate }: Props) {
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [templateId, setTemplateId] = useState('');
  const [messageContent, setMessageContent] = useState('');
  const [variables, setVariables] = useState<Record<string, string>>({});
  const [channelUsername, setChannelUsername] = useState('@oldregular');
  const [scheduleType, setScheduleType] = useState<'now' | 'scheduled'>('now');
  const [scheduledDate, setScheduledDate] = useState('');
  const [scheduledTime, setScheduledTime] = useState('');
  const [parseMode, setParseMode] = useState('HTML');
  const [disableNotification, setDisableNotification] = useState(false);

  useEffect(() => {
    fetchTemplates();
  }, []);

  useEffect(() => {
    if (selectedTemplate) {
      setTemplateId(selectedTemplate.id);
      setMessageContent(selectedTemplate.content);
      setParseMode(selectedTemplate.parse_mode);

      const vars: Record<string, string> = {};
      (selectedTemplate.variables || []).forEach((v: string) => {
        vars[v] = '';
      });
      setVariables(vars);
    }
  }, [selectedTemplate]);

  const fetchTemplates = async () => {
    try {
      const { data, error } = await supabase
        .from('telegram_templates')
        .select('id, name, content, variables, parse_mode')
        .eq('is_active', true)
        .order('name');

      if (error) throw error;
      setTemplates(data || []);
    } catch (err) {
      console.error('Error fetching templates:', err);
    }
  };

  const handleTemplateSelect = (id: string) => {
    const template = templates.find(t => t.id === id);
    if (template) {
      setTemplateId(id);
      setMessageContent(template.content);
      setParseMode(template.parse_mode);

      const vars: Record<string, string> = {};
      (template.variables || []).forEach((v: string) => {
        vars[v] = '';
      });
      setVariables(vars);
    }
  };

  const renderContent = (): string => {
    let content = messageContent;
    Object.entries(variables).forEach(([key, value]) => {
      content = content.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), value || `{{${key}}}`);
    });
    return content;
  };

  const handleSendNow = async () => {
    const finalContent = renderContent();
    if (!finalContent.trim()) {
      setError('Message content is required');
      return;
    }

    setSending(true);
    setError('');
    setSuccess('');

    try {
      const { data: session } = await supabase.auth.getSession();
      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/telegram-send-to-channel`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${session.session?.access_token}`,
          },
          body: JSON.stringify({
            message: finalContent,
            channel: channelUsername,
            parse_mode: parseMode,
            disable_notification: disableNotification,
          }),
        }
      );

      const result = await response.json();

      if (result.success) {
        setSuccess('Message sent successfully!');
        if (templateId) {
          await supabase
            .from('telegram_templates')
            .update({ use_count: templates.find(t => t.id === templateId)?.use_count || 0 + 1 })
            .eq('id', templateId);
        }
        resetForm();
      } else {
        setError(result.error || 'Failed to send message');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send message');
    } finally {
      setSending(false);
    }
  };

  const handleSchedule = async () => {
    const finalContent = renderContent();
    if (!finalContent.trim()) {
      setError('Message content is required');
      return;
    }

    if (!scheduledDate || !scheduledTime) {
      setError('Please select a date and time');
      return;
    }

    const scheduledFor = new Date(`${scheduledDate}T${scheduledTime}`);
    if (scheduledFor <= new Date()) {
      setError('Scheduled time must be in the future');
      return;
    }

    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const { error } = await supabase
        .from('telegram_scheduled_messages')
        .insert({
          created_by: userId,
          template_id: templateId || null,
          final_content: finalContent,
          channel_username: channelUsername,
          scheduled_for: scheduledFor.toISOString(),
          parse_mode: parseMode,
          disable_notification: disableNotification,
          status: 'pending',
        });

      if (error) throw error;

      setSuccess(`Message scheduled for ${scheduledFor.toLocaleString()}`);
      resetForm();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to schedule message');
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setTemplateId('');
    setMessageContent('');
    setVariables({});
    setScheduledDate('');
    setScheduledTime('');
    onClearTemplate?.();
  };

  const detectVariables = (content: string): string[] => {
    const matches = content.match(/\{\{(\w+)\}\}/g) || [];
    return [...new Set(matches.map(m => m.replace(/[{}]/g, '')))];
  };

  return (
    <div className="bg-[#1a1d21] rounded-lg p-6">
      <div className="flex items-center gap-3 mb-6">
        <Send className="w-6 h-6 text-[#00bcd4]" />
        <h3 className="text-lg font-semibold text-white">Send Message</h3>
      </div>

      {error && (
        <div className="mb-4 p-3 bg-red-500/20 border border-red-500/30 rounded-lg flex items-center gap-2 text-red-400 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      {success && (
        <div className="mb-4 p-3 bg-green-500/20 border border-green-500/30 rounded-lg flex items-center gap-2 text-green-400 text-sm">
          <CheckCircle className="w-4 h-4 flex-shrink-0" />
          {success}
        </div>
      )}

      <div className="space-y-4">
        <div>
          <label className="block text-sm text-gray-400 mb-2">Use Template (Optional)</label>
          <div className="flex gap-2">
            <select
              value={templateId}
              onChange={(e) => handleTemplateSelect(e.target.value)}
              className="flex-1 bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
            >
              <option value="">-- Select a template --</option>
              {templates.map(t => (
                <option key={t.id} value={t.id}>{t.name}</option>
              ))}
            </select>
            {templateId && (
              <button
                onClick={resetForm}
                className="p-3 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            )}
          </div>
        </div>

        <div>
          <label className="block text-sm text-gray-400 mb-2">Channel</label>
          <input
            type="text"
            value={channelUsername}
            onChange={(e) => setChannelUsername(e.target.value)}
            placeholder="@oldregular"
            className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
          />
        </div>

        <div>
          <label className="block text-sm text-gray-400 mb-2">Message Content</label>
          <textarea
            value={messageContent}
            onChange={(e) => {
              setMessageContent(e.target.value);
              const vars = detectVariables(e.target.value);
              const newVars: Record<string, string> = {};
              vars.forEach(v => {
                newVars[v] = variables[v] || '';
              });
              setVariables(newVars);
            }}
            placeholder="Type your message here..."
            rows={6}
            className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none font-mono text-sm"
          />
        </div>

        {Object.keys(variables).length > 0 && (
          <div className="p-4 bg-[#0b0e11] rounded-lg space-y-3">
            <p className="text-sm text-gray-400 flex items-center gap-2">
              <FileText className="w-4 h-4" />
              Fill in Variables
            </p>
            <div className="grid grid-cols-2 gap-3">
              {Object.entries(variables).map(([key, value]) => (
                <div key={key}>
                  <label className="block text-xs text-gray-500 mb-1">{`{{${key}}}`}</label>
                  <input
                    type="text"
                    value={value}
                    onChange={(e) => setVariables({ ...variables, [key]: e.target.value })}
                    placeholder={`Enter ${key}...`}
                    className="w-full bg-[#1a1d21] border border-gray-700 rounded px-3 py-2 text-white text-sm focus:border-[#00bcd4] focus:outline-none"
                  />
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm text-gray-400 mb-2">Parse Mode</label>
            <select
              value={parseMode}
              onChange={(e) => setParseMode(e.target.value)}
              className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
            >
              <option value="HTML">HTML</option>
              <option value="Markdown">Markdown</option>
              <option value="MarkdownV2">MarkdownV2</option>
              <option value="None">Plain Text</option>
            </select>
          </div>
          <div className="flex items-end">
            <label className="flex items-center gap-3 cursor-pointer p-3 bg-[#0b0e11] rounded-lg w-full">
              <input
                type="checkbox"
                checked={disableNotification}
                onChange={(e) => setDisableNotification(e.target.checked)}
                className="sr-only"
              />
              <div className={`w-10 h-6 rounded-full transition-colors ${disableNotification ? 'bg-[#00bcd4]' : 'bg-gray-600'}`}>
                <div className={`w-4 h-4 rounded-full bg-white transform transition-transform mt-1 ${disableNotification ? 'translate-x-5' : 'translate-x-1'}`} />
              </div>
              <span className="text-sm text-gray-300">Silent</span>
            </label>
          </div>
        </div>

        <div className="flex gap-4 p-1 bg-[#0b0e11] rounded-lg">
          <button
            onClick={() => setScheduleType('now')}
            className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-lg transition-colors ${
              scheduleType === 'now' ? 'bg-[#00bcd4] text-black' : 'text-gray-400 hover:text-white'
            }`}
          >
            <Send className="w-4 h-4" />
            Send Now
          </button>
          <button
            onClick={() => setScheduleType('scheduled')}
            className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-lg transition-colors ${
              scheduleType === 'scheduled' ? 'bg-[#00bcd4] text-black' : 'text-gray-400 hover:text-white'
            }`}
          >
            <Clock className="w-4 h-4" />
            Schedule
          </button>
        </div>

        {scheduleType === 'scheduled' && (
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm text-gray-400 mb-2">Date</label>
              <input
                type="date"
                value={scheduledDate}
                onChange={(e) => setScheduledDate(e.target.value)}
                min={new Date().toISOString().split('T')[0]}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-2">Time</label>
              <input
                type="time"
                value={scheduledTime}
                onChange={(e) => setScheduledTime(e.target.value)}
                className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
              />
            </div>
          </div>
        )}

        {messageContent && (
          <div className="p-4 bg-[#0b0e11] rounded-lg">
            <p className="text-xs text-gray-500 mb-2">Preview:</p>
            <div className="text-sm text-gray-300 whitespace-pre-wrap">
              {renderContent()}
            </div>
          </div>
        )}

        <button
          onClick={scheduleType === 'now' ? handleSendNow : handleSchedule}
          disabled={loading || sending || !messageContent.trim()}
          className="w-full bg-[#00bcd4] text-black font-semibold py-3 rounded-lg hover:bg-[#00bcd4]/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {loading || sending ? (
            <>
              <RefreshCw className="w-4 h-4 animate-spin" />
              {scheduleType === 'now' ? 'Sending...' : 'Scheduling...'}
            </>
          ) : (
            <>
              {scheduleType === 'now' ? <Send className="w-4 h-4" /> : <Calendar className="w-4 h-4" />}
              {scheduleType === 'now' ? 'Send Message' : 'Schedule Message'}
            </>
          )}
        </button>
      </div>
    </div>
  );
}
