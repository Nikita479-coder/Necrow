import { useEffect, useState, useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase';
import type { RealtimeChannel } from '@supabase/supabase-js';

interface PresenceUser {
  id: string;
  email?: string;
  username?: string;
  platform?: string;
  online_at: string;
}

interface PresenceState {
  onlineUsers: PresenceUser[];
  onlineCount: number;
  isUserOnline: (userId: string) => boolean;
}

const CHANNEL_NAME = 'online-users';

let globalChannel: RealtimeChannel | null = null;
let globalOnlineUsers: PresenceUser[] = [];
let globalListeners: Set<(users: PresenceUser[]) => void> = new Set();
let currentTrackingUser: { id: string; email?: string; username?: string } | null = null;
let isInitialized = false;
let externalNotifyCallback: (() => void) | null = null;

export function setExternalNotifyCallback(callback: () => void) {
  externalNotifyCallback = callback;
}

function detectPlatform(): string {
  const userAgent = navigator.userAgent.toLowerCase();
  if (/mobile|android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent)) {
    return /iphone|ipad|ipod/i.test(userAgent) ? 'ios' : 'android';
  }
  return 'desktop';
}

function notifyListeners() {
  globalListeners.forEach(listener => listener([...globalOnlineUsers]));
  if (externalNotifyCallback) {
    externalNotifyCallback();
  }
}

function parsePresenceState(channel: RealtimeChannel): PresenceUser[] {
  const state = channel.presenceState();
  const users: PresenceUser[] = [];

  Object.entries(state).forEach(([key, presences]) => {
    if (Array.isArray(presences) && presences.length > 0) {
      const latestPresence = presences[presences.length - 1] as any;
      if (!latestPresence.is_admin_observer && !key.startsWith('admin-observer-')) {
        users.push({
          id: latestPresence.user_id || key,
          email: latestPresence.email,
          username: latestPresence.username,
          platform: latestPresence.platform,
          online_at: latestPresence.online_at,
        });
      }
    }
  });

  return users;
}

export function initializePresence(user: { id: string; email?: string; username?: string }) {
  if (currentTrackingUser?.id === user.id && globalChannel && isInitialized) {
    return;
  }

  cleanupPresence();

  currentTrackingUser = user;

  globalChannel = supabase.channel(CHANNEL_NAME, {
    config: {
      presence: {
        key: user.id,
      },
    },
  });

  globalChannel
    .on('presence', { event: 'sync' }, () => {
      if (globalChannel) {
        globalOnlineUsers = parsePresenceState(globalChannel);
        notifyListeners();
      }
    })
    .on('presence', { event: 'join' }, ({ key, newPresences }) => {
      if (globalChannel) {
        globalOnlineUsers = parsePresenceState(globalChannel);
        notifyListeners();
      }
    })
    .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
      if (globalChannel) {
        globalOnlineUsers = parsePresenceState(globalChannel);
        notifyListeners();
      }
    })
    .subscribe(async (status) => {
      if (status === 'SUBSCRIBED' && currentTrackingUser) {
        isInitialized = true;
        await globalChannel?.track({
          user_id: currentTrackingUser.id,
          email: currentTrackingUser.email,
          username: currentTrackingUser.username,
          platform: detectPlatform(),
          online_at: new Date().toISOString(),
        });
      }
    });

  const handleVisibilityChange = async () => {
    if (!globalChannel || !currentTrackingUser) return;

    if (document.hidden) {
      await globalChannel.untrack();
    } else {
      await globalChannel.track({
        user_id: currentTrackingUser.id,
        email: currentTrackingUser.email,
        username: currentTrackingUser.username,
        platform: detectPlatform(),
        online_at: new Date().toISOString(),
      });
    }
  };

  document.addEventListener('visibilitychange', handleVisibilityChange);
  (globalChannel as any)._visibilityHandler = handleVisibilityChange;
}

export function cleanupPresence() {
  if (globalChannel) {
    const handler = (globalChannel as any)._visibilityHandler;
    if (handler) {
      document.removeEventListener('visibilitychange', handler);
    }
    globalChannel.untrack();
    supabase.removeChannel(globalChannel);
    globalChannel = null;
  }
  currentTrackingUser = null;
  globalOnlineUsers = [];
  isInitialized = false;
  notifyListeners();
}

export function usePresence(currentUser: { id: string; email?: string; username?: string } | null): PresenceState {
  const [onlineUsers, setOnlineUsers] = useState<PresenceUser[]>(globalOnlineUsers);

  useEffect(() => {
    if (currentUser?.id) {
      initializePresence(currentUser);
    }
  }, [currentUser?.id, currentUser?.email, currentUser?.username]);

  useEffect(() => {
    const listener = (users: PresenceUser[]) => {
      setOnlineUsers(users);
    };

    globalListeners.add(listener);
    setOnlineUsers([...globalOnlineUsers]);

    return () => {
      globalListeners.delete(listener);
    };
  }, []);

  const isUserOnline = useCallback((userId: string) => {
    return onlineUsers.some(u => u.id === userId);
  }, [onlineUsers]);

  return {
    onlineUsers,
    onlineCount: onlineUsers.length,
    isUserOnline,
  };
}

export function useAdminPresence(): PresenceState {
  const [onlineUsers, setOnlineUsers] = useState<PresenceUser[]>(globalOnlineUsers);

  useEffect(() => {
    const listener = (users: PresenceUser[]) => {
      setOnlineUsers(users);
    };

    globalListeners.add(listener);
    setOnlineUsers([...globalOnlineUsers]);

    return () => {
      globalListeners.delete(listener);
    };
  }, []);

  const isUserOnline = useCallback((userId: string) => {
    return onlineUsers.some(u => u.id === userId);
  }, [onlineUsers]);

  return {
    onlineUsers,
    onlineCount: onlineUsers.length,
    isUserOnline,
  };
}

export function getOnlineUserIds(): string[] {
  return globalOnlineUsers.map(u => u.id);
}

export function isUserCurrentlyOnline(userId: string): boolean {
  return globalOnlineUsers.some(u => u.id === userId);
}

export function getGlobalOnlineUsers(): PresenceUser[] {
  return [...globalOnlineUsers];
}
