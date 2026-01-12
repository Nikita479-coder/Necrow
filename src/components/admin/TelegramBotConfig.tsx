import { useState, useEffect } from 'react';
import { Bot, CheckCircle, AlertCircle, Eye, EyeOff, RefreshCw } from 'lucide-react';
import { supabase } from '../../lib/supabase';

interface BotConfig {
  id: string;
  bot_token: string;
  bot_username: string | null;
  channel_username: string;
  channel_chat_id: number | null;
  is_active: boolean;
  last_verified_at: string | null;
}

interface Props {
  userId: string;
  onConfigured: () => void;
}

export default function TelegramBotConfig({ userId, onConfigured }: Props) {
  const [config, setConfig] = useState<BotConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [showToken, setShowToken] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [botToken, setBotToken] = useState('');
  const [channelUsername, setChannelUsername] = useState('@oldregular');

  useEffect(() => {
    fetchConfig();
  }, [userId]);

  const fetchConfig = async () => {
    try {
      const { data, error } = await supabase
        .from('telegram_bot_config')
        .select('*')
        .eq('created_by', userId)
        .maybeSingle();

      if (error) throw error;

      if (data) {
        setConfig(data);
        setBotToken(data.bot_token);
        setChannelUsername(data.channel_username);
      }
    } catch (err) {
      console.error('Error fetching config:', err);
    } finally {
      setLoading(false);
    }
  };

  const verifyBot = async (token: string): Promise<{ ok: boolean; username?: string; error?: string }> => {
    try {
      const response = await fetch(`https://api.telegram.org/bot${token}/getMe`);
      const data = await response.json();

      if (data.ok) {
        return { ok: true, username: data.result.username };
      }
      return { ok: false, error: data.description };
    } catch (err) {
      return { ok: false, error: String(err) };
    }
  };

  const handleSave = async () => {
    if (!botToken.trim()) {
      setError('Bot token is required');
      return;
    }

    setSaving(true);
    setError('');
    setSuccess('');

    try {
      setVerifying(true);
      const verification = await verifyBot(botToken);
      setVerifying(false);

      if (!verification.ok) {
        setError(`Invalid bot token: ${verification.error}`);
        setSaving(false);
        return;
      }

      const configData = {
        created_by: userId,
        bot_token: botToken,
        bot_username: verification.username,
        channel_username: channelUsername,
        is_active: true,
        last_verified_at: new Date().toISOString(),
      };

      if (config) {
        const { error } = await supabase
          .from('telegram_bot_config')
          .update(configData)
          .eq('id', config.id);

        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('telegram_bot_config')
          .insert(configData);

        if (error) throw error;
      }

      setSuccess('Bot configured successfully!');
      fetchConfig();
      onConfigured();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save configuration');
    } finally {
      setSaving(false);
    }
  };

  const handleTestMessage = async () => {
    if (!config) return;

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
            message: '🔔 <b>Test Message</b>\n\nThis is a test message from your CRM system.\n\n<i>If you see this, your bot is configured correctly!</i>',
            channel: channelUsername,
          }),
        }
      );

      const result = await response.json();

      if (result.success) {
        setSuccess('Test message sent successfully!');
      } else {
        setError(result.error || 'Failed to send test message');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send test message');
    }
  };

  if (loading) {
    return (
      <div className="bg-[#1a1d21] rounded-lg p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-700 rounded w-1/3"></div>
          <div className="h-10 bg-gray-700 rounded"></div>
          <div className="h-10 bg-gray-700 rounded"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-[#1a1d21] rounded-lg p-6">
      <div className="flex items-center gap-3 mb-6">
        <Bot className="w-6 h-6 text-[#00bcd4]" />
        <h3 className="text-lg font-semibold text-white">Telegram Bot Configuration</h3>
        {config?.is_active && (
          <span className="flex items-center gap-1 text-xs bg-green-500/20 text-green-400 px-2 py-1 rounded">
            <CheckCircle className="w-3 h-3" />
            Active
          </span>
        )}
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
          <label className="block text-sm text-gray-400 mb-2">
            Bot Token <span className="text-red-400">*</span>
          </label>
          <div className="relative">
            <input
              type={showToken ? 'text' : 'password'}
              value={botToken}
              onChange={(e) => setBotToken(e.target.value)}
              placeholder="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
              className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none pr-12"
            />
            <button
              onClick={() => setShowToken(!showToken)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
            >
              {showToken ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
            </button>
          </div>
          <p className="text-xs text-gray-500 mt-1">
            Get this from @BotFather on Telegram
          </p>
        </div>

        <div>
          <label className="block text-sm text-gray-400 mb-2">
            Channel Username
          </label>
          <input
            type="text"
            value={channelUsername}
            onChange={(e) => setChannelUsername(e.target.value)}
            placeholder="@oldregular"
            className="w-full bg-[#0b0e11] border border-gray-700 rounded-lg px-4 py-3 text-white focus:border-[#00bcd4] focus:outline-none"
          />
          <p className="text-xs text-gray-500 mt-1">
            Your bot must be an admin in this channel
          </p>
        </div>

        {config?.bot_username && (
          <div className="p-4 bg-[#0b0e11] rounded-lg">
            <p className="text-sm text-gray-400">Connected Bot</p>
            <p className="text-white font-medium">@{config.bot_username}</p>
            {config.last_verified_at && (
              <p className="text-xs text-gray-500 mt-1">
                Last verified: {new Date(config.last_verified_at).toLocaleString()}
              </p>
            )}
          </div>
        )}

        <div className="flex gap-3 pt-4">
          <button
            onClick={handleSave}
            disabled={saving || !botToken}
            className="flex-1 bg-[#00bcd4] text-black font-semibold py-3 rounded-lg hover:bg-[#00bcd4]/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            {saving ? (
              <>
                <RefreshCw className="w-4 h-4 animate-spin" />
                {verifying ? 'Verifying...' : 'Saving...'}
              </>
            ) : (
              'Save Configuration'
            )}
          </button>

          {config?.is_active && (
            <button
              onClick={handleTestMessage}
              className="px-6 py-3 border border-[#00bcd4] text-[#00bcd4] font-semibold rounded-lg hover:bg-[#00bcd4]/10 transition-colors"
            >
              Test
            </button>
          )}
        </div>
      </div>

      <div className="mt-6 p-4 bg-[#0b0e11] rounded-lg">
        <h4 className="text-sm font-medium text-white mb-2">Setup Instructions</h4>
        <ol className="text-xs text-gray-400 space-y-2 list-decimal list-inside">
          <li>Open Telegram and search for @BotFather</li>
          <li>Send /newbot and follow the prompts to create your bot</li>
          <li>Copy the bot token and paste it above</li>
          <li>Add your bot as an administrator to your channel ({channelUsername})</li>
          <li>Click "Save Configuration" and then "Test" to verify</li>
        </ol>
      </div>
    </div>
  );
}
