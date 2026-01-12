import { useState, useEffect } from 'react';
import { ArrowLeft, Bot, MessageSquare, FileText, Clock, BarChart3, Settings, RefreshCw } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useNavigation } from '../App';
import TelegramBotConfig from '../components/admin/TelegramBotConfig';
import TelegramTemplateManager from '../components/admin/TelegramTemplateManager';
import TelegramMessageScheduler from '../components/admin/TelegramMessageScheduler';
import TelegramMessageQueue from '../components/admin/TelegramMessageQueue';

interface CRMStats {
  total_templates: number;
  active_templates: number;
  pending_messages: number;
  processing_messages: number;
  sent_today: number;
  sent_this_week: number;
  sent_this_month: number;
  failed_messages: number;
  bot_configured: boolean;
}

interface Template {
  id: string;
  name: string;
  content: string;
  variables: string[];
  parse_mode: string;
}

type TabType = 'dashboard' | 'send' | 'templates' | 'queue' | 'settings';

export default function AdminTelegramCRM() {
  const { user } = useAuth();
  const { navigateTo } = useNavigation();
  const [activeTab, setActiveTab] = useState<TabType>('dashboard');
  const [stats, setStats] = useState<CRMStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedTemplate, setSelectedTemplate] = useState<Template | null>(null);

  useEffect(() => {
    if (user?.id) {
      fetchStats();
    }
  }, [user?.id]);

  const fetchStats = async () => {
    try {
      const { data, error } = await supabase.rpc('get_telegram_crm_stats', {
        p_user_id: user?.id,
      });

      if (error) throw error;
      setStats(data);
    } catch (err) {
      console.error('Error fetching stats:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleTemplateSelect = (template: Template) => {
    setSelectedTemplate(template);
    setActiveTab('send');
  };

  const tabs = [
    { id: 'dashboard', label: 'Dashboard', icon: BarChart3 },
    { id: 'send', label: 'Send Message', icon: MessageSquare },
    { id: 'templates', label: 'Templates', icon: FileText },
    { id: 'queue', label: 'Queue', icon: Clock },
    { id: 'settings', label: 'Settings', icon: Settings },
  ];

  if (!user) {
    return (
      <div className="min-h-screen bg-[#0b0e11] flex items-center justify-center">
        <p className="text-gray-400">Please sign in to access this page</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0b0e11]">
      <div className="border-b border-gray-800">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <button
                onClick={() => navigateTo('admindashboard')}
                className="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
              >
                <ArrowLeft className="w-5 h-5" />
              </button>
              <div className="flex items-center gap-3">
                <Bot className="w-8 h-8 text-[#00bcd4]" />
                <div>
                  <h1 className="text-xl font-bold text-white">Telegram CRM</h1>
                  <p className="text-sm text-gray-400">Manage channel messages and templates</p>
                </div>
              </div>
            </div>
            <button
              onClick={fetchStats}
              className="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
              title="Refresh Stats"
            >
              <RefreshCw className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="flex gap-2 mb-6 overflow-x-auto pb-2">
          {tabs.map(tab => {
            const Icon = tab.icon;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as TabType)}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-lg whitespace-nowrap transition-colors ${
                  activeTab === tab.id
                    ? 'bg-[#00bcd4] text-black font-semibold'
                    : 'bg-[#1a1d21] text-gray-400 hover:text-white hover:bg-gray-700'
                }`}
              >
                <Icon className="w-4 h-4" />
                {tab.label}
              </button>
            );
          })}
        </div>

        {activeTab === 'dashboard' && (
          <div className="space-y-6">
            {!stats?.bot_configured && (
              <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 flex items-start gap-3">
                <Bot className="w-5 h-5 text-yellow-400 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-yellow-400 font-medium">Bot not configured</p>
                  <p className="text-sm text-yellow-400/70 mt-1">
                    Configure your Telegram bot to start sending messages to your channel.
                  </p>
                  <button
                    onClick={() => setActiveTab('settings')}
                    className="mt-3 px-4 py-2 bg-yellow-500 text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors text-sm"
                  >
                    Configure Bot
                  </button>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div className="bg-[#1a1d21] rounded-lg p-6">
                <div className="flex items-center gap-3 mb-2">
                  <FileText className="w-5 h-5 text-[#00bcd4]" />
                  <span className="text-gray-400 text-sm">Templates</span>
                </div>
                <p className="text-3xl font-bold text-white">{stats?.total_templates || 0}</p>
                <p className="text-xs text-gray-500 mt-1">{stats?.active_templates || 0} active</p>
              </div>

              <div className="bg-[#1a1d21] rounded-lg p-6">
                <div className="flex items-center gap-3 mb-2">
                  <Clock className="w-5 h-5 text-yellow-400" />
                  <span className="text-gray-400 text-sm">Pending</span>
                </div>
                <p className="text-3xl font-bold text-white">{stats?.pending_messages || 0}</p>
                <p className="text-xs text-gray-500 mt-1">{stats?.processing_messages || 0} processing</p>
              </div>

              <div className="bg-[#1a1d21] rounded-lg p-6">
                <div className="flex items-center gap-3 mb-2">
                  <MessageSquare className="w-5 h-5 text-green-400" />
                  <span className="text-gray-400 text-sm">Sent Today</span>
                </div>
                <p className="text-3xl font-bold text-white">{stats?.sent_today || 0}</p>
                <p className="text-xs text-gray-500 mt-1">{stats?.sent_this_week || 0} this week</p>
              </div>

              <div className="bg-[#1a1d21] rounded-lg p-6">
                <div className="flex items-center gap-3 mb-2">
                  <BarChart3 className="w-5 h-5 text-blue-400" />
                  <span className="text-gray-400 text-sm">Monthly Total</span>
                </div>
                <p className="text-3xl font-bold text-white">{stats?.sent_this_month || 0}</p>
                <p className="text-xs text-gray-500 mt-1">{stats?.failed_messages || 0} failed</p>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <TelegramMessageScheduler
                userId={user.id}
                selectedTemplate={selectedTemplate}
                onClearTemplate={() => setSelectedTemplate(null)}
              />
              <TelegramMessageQueue userId={user.id} />
            </div>
          </div>
        )}

        {activeTab === 'send' && (
          <div className="max-w-2xl">
            <TelegramMessageScheduler
              userId={user.id}
              selectedTemplate={selectedTemplate}
              onClearTemplate={() => setSelectedTemplate(null)}
            />
          </div>
        )}

        {activeTab === 'templates' && (
          <TelegramTemplateManager
            userId={user.id}
            onSelectTemplate={handleTemplateSelect}
          />
        )}

        {activeTab === 'queue' && (
          <TelegramMessageQueue userId={user.id} />
        )}

        {activeTab === 'settings' && (
          <div className="max-w-2xl">
            <TelegramBotConfig
              userId={user.id}
              onConfigured={fetchStats}
            />

            <div className="mt-6 bg-[#1a1d21] rounded-lg p-6">
              <h3 className="text-lg font-semibold text-white mb-4">Channel Information</h3>
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-gray-400 mb-1">Target Channel</p>
                  <a
                    href="https://t.me/oldregular"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-[#00bcd4] hover:underline"
                  >
                    https://t.me/oldregular
                  </a>
                </div>
                <div className="p-4 bg-[#0b0e11] rounded-lg">
                  <p className="text-sm text-gray-400 mb-2">Important Notes:</p>
                  <ul className="text-xs text-gray-500 space-y-1 list-disc list-inside">
                    <li>Your bot must be added as an administrator to the channel</li>
                    <li>The bot needs "Post Messages" permission at minimum</li>
                    <li>Messages are sent through the Telegram Bot API</li>
                    <li>Scheduled messages are processed automatically</li>
                  </ul>
                </div>
              </div>
            </div>

            <div className="mt-6 bg-[#1a1d21] rounded-lg p-6">
              <h3 className="text-lg font-semibold text-white mb-4">API Credentials</h3>
              <p className="text-sm text-gray-400 mb-4">
                Your Telegram API credentials (for advanced features):
              </p>
              <div className="space-y-3">
                <div className="p-3 bg-[#0b0e11] rounded-lg">
                  <p className="text-xs text-gray-500">API ID</p>
                  <p className="text-white font-mono">37497106</p>
                </div>
                <div className="p-3 bg-[#0b0e11] rounded-lg">
                  <p className="text-xs text-gray-500">API Hash</p>
                  <p className="text-white font-mono text-sm">4fcd8a0c236ce0a254073478e015c167</p>
                </div>
              </div>
              <p className="text-xs text-gray-500 mt-4">
                Note: These credentials are for the Client API (MTProto). For simple channel posting,
                the Bot API (configured above) is recommended.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
