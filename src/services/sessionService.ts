import { supabase } from '../lib/supabase';
import type { RealtimeChannel } from '@supabase/supabase-js';

type OnlineStatusCallback = (userId: string, isOnline: boolean) => void;

function detectPlatform(): { platform: string; deviceInfo: Record<string, unknown> } {
  const ua = navigator.userAgent.toLowerCase();
  const isStandalone = (window.matchMedia('(display-mode: standalone)').matches) ||
                       ((window.navigator as any).standalone === true);
  const isIOS = /iphone|ipad|ipod/.test(ua);
  const isAndroid = /android/.test(ua);
  const isMobile = isIOS || isAndroid || /mobile/.test(ua);

  let platform = 'web';
  if (isStandalone || ua.includes('shark-app') || ua.includes('wv)')) {
    platform = 'app';
  } else if (isMobile) {
    platform = 'mobile_web';
  }

  const deviceInfo = {
    userAgent: navigator.userAgent,
    platform: navigator.platform,
    language: navigator.language,
    screenWidth: window.screen.width,
    screenHeight: window.screen.height,
    isStandalone,
    isMobile,
    isIOS,
    isAndroid,
  };

  return { platform, deviceInfo };
}

class SessionService {
  private updateInterval: NodeJS.Timeout | null = null;
  private userId: string | null = null;
  private channel: RealtimeChannel | null = null;
  private onlineStatusCallbacks: Set<OnlineStatusCallback> = new Set();
  private onlineUsers: Set<string> = new Set();
  private platformInfo: { platform: string; deviceInfo: Record<string, unknown> } | null = null;

  start(userId: string) {
    this.userId = userId;
    this.platformInfo = detectPlatform();
    this.updateSession(true);

    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }

    this.updateInterval = setInterval(() => {
      this.updateSession(true);
    }, 15000); // Update every 15 seconds for real-time accuracy

    this.setupRealtimeSubscription();

    window.addEventListener('beforeunload', () => {
      this.stop();
    });

    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        this.updateSession(false);
      } else {
        this.updateSession(true);
      }
    });

    window.addEventListener('online', () => {
      this.updateSession(true);
    });

    window.addEventListener('offline', () => {
      this.updateSession(false);
    });
  }

  private setupRealtimeSubscription() {
    if (this.channel) {
      supabase.removeChannel(this.channel);
    }

    this.channel = supabase
      .channel('user-sessions')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_sessions',
        },
        (payload) => {
          this.handleSessionChange(payload);
        }
      )
      .subscribe();
  }

  private handleSessionChange(payload: any) {
    if (payload.eventType === 'UPDATE' || payload.eventType === 'INSERT') {
      const session = payload.new;
      const userId = session.user_id;
      const isOnline = session.is_online;
      const heartbeat = new Date(session.heartbeat);
      const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);

      const actuallyOnline = isOnline && heartbeat > twoMinutesAgo;

      if (actuallyOnline) {
        if (!this.onlineUsers.has(userId)) {
          this.onlineUsers.add(userId);
          this.notifyStatusChange(userId, true);
        }
      } else {
        if (this.onlineUsers.has(userId)) {
          this.onlineUsers.delete(userId);
          this.notifyStatusChange(userId, false);
        }
      }
    } else if (payload.eventType === 'DELETE') {
      const userId = payload.old.user_id;
      if (this.onlineUsers.has(userId)) {
        this.onlineUsers.delete(userId);
        this.notifyStatusChange(userId, false);
      }
    }
  }

  private notifyStatusChange(userId: string, isOnline: boolean) {
    this.onlineStatusCallbacks.forEach(callback => {
      callback(userId, isOnline);
    });
  }

  subscribeToOnlineStatus(callback: OnlineStatusCallback) {
    this.onlineStatusCallbacks.add(callback);

    return () => {
      this.onlineStatusCallbacks.delete(callback);
    };
  }

  stop() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }

    if (this.channel) {
      supabase.removeChannel(this.channel);
      this.channel = null;
    }

    if (this.userId) {
      this.updateSession(false);
      this.userId = null;
    }

    this.onlineUsers.clear();
    this.onlineStatusCallbacks.clear();
  }

  private async updateSession(isOnline: boolean) {
    if (!this.userId) return;

    try {
      await supabase.rpc('update_user_session', {
        p_user_id: this.userId,
        p_is_online: isOnline,
        p_platform: this.platformInfo?.platform || 'web',
        p_device_info: this.platformInfo?.deviceInfo || {},
      });
    } catch (error) {
      console.error('Failed to update session:', error);
    }
  }

  async getOnlineUsers() {
    try {
      const { data, error } = await supabase.rpc('get_online_users');
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('Failed to get online users:', error);
      return [];
    }
  }

  async getUserSession(userId: string) {
    try {
      const { data, error } = await supabase
        .from('user_sessions')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();

      if (error) throw error;

      if (data) {
        const heartbeat = new Date(data.heartbeat);
        const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
        const isOnline = data.is_online && heartbeat > twoMinutesAgo;

        return {
          ...data,
          is_online: isOnline,
        };
      }

      return null;
    } catch (error) {
      console.error('Failed to get user session:', error);
      return null;
    }
  }

  isUserOnline(userId: string): boolean {
    return this.onlineUsers.has(userId);
  }

  async checkUserOnlineStatus(userId: string): Promise<boolean> {
    try {
      const { data, error } = await supabase.rpc('is_user_online', {
        p_user_id: userId
      });

      if (error) throw error;
      return data || false;
    } catch (error) {
      console.error('Failed to check user online status:', error);
      return false;
    }
  }

  async getUsersOnlineStatus(userIds: string[]): Promise<Map<string, boolean>> {
    try {
      const { data, error } = await supabase.rpc('get_users_online_status', {
        p_user_ids: userIds
      });

      if (error) throw error;

      const statusMap = new Map<string, boolean>();
      if (data) {
        data.forEach((item: any) => {
          statusMap.set(item.user_id, item.is_online);
        });
      }

      return statusMap;
    } catch (error) {
      console.error('Failed to get users online status:', error);
      return new Map();
    }
  }

  getOnlineUserIds(): string[] {
    return Array.from(this.onlineUsers);
  }
}

export const sessionService = new SessionService();
