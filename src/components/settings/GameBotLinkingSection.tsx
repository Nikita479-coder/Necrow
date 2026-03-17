import { useState, useEffect, useCallback } from 'react';
import { Gamepad2, Link2, Unlink, RefreshCw, CheckCircle, Clock, Copy, ExternalLink, X } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../context/AuthContext';
import { QRCodeSVG } from 'qrcode.react';

interface LinkingCode {
  code: string;
  expires_at: string;
  deep_link: string;
  bot_username: string;
}

interface GameBotStatus {
  linked: boolean;
  game_bot_username?: string;
  linked_at?: string;
}

export default function GameBotLinkingSection() {
  const { user, refreshProfile } = useAuth();
  const [status, setStatus] = useState<GameBotStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [linkingCode, setLinkingCode] = useState<LinkingCode | null>(null);
  const [showLinkingModal, setShowLinkingModal] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [copied, setCopied] = useState(false);
  const [unlinking, setUnlinking] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadGameBotStatus = useCallback(async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('game_bot_chat_id, game_bot_username, game_bot_linked_at')
        .eq('id', user.id)
        .single();

      if (error) throw error;

      setStatus({
        linked: !!data?.game_bot_chat_id,
        game_bot_username: data?.game_bot_username,
        linked_at: data?.game_bot_linked_at,
      });
    } catch (err) {
      console.error('Error loading Game Bot status:', err);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    loadGameBotStatus();
  }, [loadGameBotStatus]);

  useEffect(() => {
    if (!linkingCode) return;

    const expiresAt = new Date(linkingCode.expires_at).getTime();

    const updateCountdown = () => {
      const now = Date.now();
      const remaining = Math.max(0, Math.floor((expiresAt - now) / 1000));
      setCountdown(remaining);

      if (remaining === 0) {
        setLinkingCode(null);
        setShowLinkingModal(false);
      }
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);

    return () => clearInterval(interval);
  }, [linkingCode]);

  useEffect(() => {
    if (!showLinkingModal || !linkingCode) return;

    const checkLinked = async () => {
      const { data } = await supabase
        .from('user_profiles')
        .select('game_bot_chat_id')
        .eq('id', user?.id)
        .single();

      if (data?.game_bot_chat_id) {
        setShowLinkingModal(false);
        setLinkingCode(null);
        await loadGameBotStatus();
        await refreshProfile();
      }
    };

    const interval = setInterval(checkLinked, 3000);
    return () => clearInterval(interval);
  }, [showLinkingModal, linkingCode, user?.id, loadGameBotStatus, refreshProfile]);

  const generateLinkingCode = async () => {
    setError(null);
    setLoading(true);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        throw new Error('Please log in to connect the Game Bot');
      }

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/game-bot-generate-link-code`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      if (!response.ok) {
        let errorMessage = 'Failed to generate linking code';
        try {
          const data = await response.json();
          errorMessage = data.error || data.details || errorMessage;
        } catch {
          // use default
        }
        throw new Error(errorMessage);
      }

      const data = await response.json();

      if (data.already_linked) {
        await loadGameBotStatus();
        return;
      }

      setLinkingCode(data);
      setShowLinkingModal(true);
    } catch (err) {
      console.error('Game Bot linking error:', err);
      setError(err instanceof Error ? err.message : 'Failed to connect. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const unlinkGameBot = async () => {
    if (!confirm('Are you sure you want to unlink the Game Bot? Your game progress will be preserved but you won\'t be able to play until you reconnect.')) {
      return;
    }

    setUnlinking(true);

    try {
      const { error } = await supabase
        .from('user_profiles')
        .update({
          game_bot_chat_id: null,
          game_bot_username: null,
          game_bot_linked_at: null,
        })
        .eq('id', user?.id);

      if (error) throw error;

      await loadGameBotStatus();
      await refreshProfile();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to unlink');
    } finally {
      setUnlinking(false);
    }
  };

  const copyCode = () => {
    if (linkingCode) {
      navigator.clipboard.writeText(`/start ${linkingCode.code}`);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  if (loading && !linkingCode) {
    return (
      <div className="bg-[#1e2329] rounded-xl p-6">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-700 rounded w-1/3" />
          <div className="h-4 bg-gray-700 rounded w-2/3" />
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="bg-[#1e2329] rounded-xl p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-full bg-emerald-500/20 flex items-center justify-center">
            <Gamepad2 className="w-5 h-5 text-emerald-400" />
          </div>
          <div>
            <h3 className="text-lg font-semibold">Shark Game Bot</h3>
            <p className="text-sm text-gray-400">Play games and earn USDT on Telegram</p>
          </div>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 text-sm">
            {error}
          </div>
        )}

        {status?.linked ? (
          <div className="space-y-4">
            <div className="flex items-center gap-3 p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-lg">
              <CheckCircle className="w-5 h-5 text-emerald-500" />
              <div className="flex-1">
                <p className="text-emerald-400 font-medium">Game Bot Connected</p>
                {status.game_bot_username && (
                  <p className="text-sm text-gray-400">@{status.game_bot_username}</p>
                )}
              </div>
            </div>

            <div className="bg-[#2b3139] rounded-lg p-4">
              <h4 className="font-medium mb-2">What you can do:</h4>
              <ul className="text-sm text-gray-400 space-y-1">
                <li>Play Coin Flip, Dice, Mines, Crash, and Limbo</li>
                <li>Deposit and withdraw USDT directly through the bot</li>
                <li>Track your game history and stats</li>
              </ul>
            </div>

            <button
              onClick={unlinkGameBot}
              disabled={unlinking}
              className="flex items-center gap-2 px-4 py-2 text-red-400 hover:text-red-300 hover:bg-red-500/10 rounded-lg transition-colors disabled:opacity-50"
            >
              {unlinking ? (
                <RefreshCw className="w-4 h-4 animate-spin" />
              ) : (
                <Unlink className="w-4 h-4" />
              )}
              Unlink Game Bot
            </button>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="bg-[#2b3139] rounded-lg p-4">
              <h4 className="font-medium mb-2">Why connect the Game Bot?</h4>
              <ul className="text-sm text-gray-400 space-y-1">
                <li>Play provably fair games directly in Telegram</li>
                <li>Use your Shark account balance to play</li>
                <li>Instant deposits and withdrawals</li>
              </ul>
            </div>

            <button
              onClick={generateLinkingCode}
              disabled={loading}
              className="flex items-center gap-2 px-6 py-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-medium transition-colors disabled:opacity-50"
            >
              {loading ? (
                <RefreshCw className="w-5 h-5 animate-spin" />
              ) : (
                <Link2 className="w-5 h-5" />
              )}
              Connect Game Bot
            </button>
          </div>
        )}
      </div>

      {showLinkingModal && linkingCode && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4">
          <div className="bg-[#1e2329] rounded-xl max-w-md w-full p-6 relative">
            <button
              onClick={() => {
                setShowLinkingModal(false);
                setLinkingCode(null);
              }}
              className="absolute top-4 right-4 text-gray-400 hover:text-white"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="text-center mb-6">
              <div className="w-16 h-16 rounded-full bg-emerald-500/20 flex items-center justify-center mx-auto mb-4">
                <Gamepad2 className="w-8 h-8 text-emerald-400" />
              </div>
              <h3 className="text-xl font-bold mb-2">Link Your Game Bot</h3>
              <p className="text-gray-400 text-sm">
                Scan the QR code or click the button to open Telegram
              </p>
            </div>

            <div className="bg-white p-4 rounded-xl mb-4 flex justify-center">
              <QRCodeSVG
                value={linkingCode.deep_link}
                size={180}
                level="M"
                includeMargin={false}
              />
            </div>

            <div className="mb-4">
              <p className="text-sm text-gray-400 text-center mb-2">Or copy and send this command in the bot:</p>
              <div className="flex items-center gap-2">
                <div className="flex-1 bg-[#2b3139] rounded-lg px-4 py-3 font-mono text-lg text-center">
                  /start {linkingCode.code}
                </div>
                <button
                  onClick={copyCode}
                  className="p-3 bg-[#2b3139] hover:bg-[#363d47] rounded-lg transition-colors"
                  title="Copy command"
                >
                  {copied ? (
                    <CheckCircle className="w-5 h-5 text-emerald-500" />
                  ) : (
                    <Copy className="w-5 h-5" />
                  )}
                </button>
              </div>
            </div>

            <div className="flex items-center justify-center gap-2 text-amber-400 mb-4">
              <Clock className="w-4 h-4" />
              <span className="text-sm">Code expires in {formatTime(countdown)}</span>
            </div>

            <a
              href={linkingCode.deep_link}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2 w-full px-6 py-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-medium transition-colors"
            >
              <ExternalLink className="w-5 h-5" />
              Open in Telegram
            </a>

            <p className="text-xs text-gray-500 text-center mt-4">
              Send <span className="font-mono text-gray-400">/start {linkingCode.code}</span> to @{linkingCode.bot_username}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
