import { useEffect, useState, useCallback, useRef, useMemo } from 'react';
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

export function usePresence(currentUser: { id: string; email?: string; username?: string } | null): PresenceState {
  const [onlineUsers, setOnlineUsers] = useState<PresenceUser[]>([]);
  const channelRef = useRef<RealtimeChannel | null>(null);

  const detectPlatform = useCallback(() => {
    const userAgent = navigator.userAgent.toLowerCase();
    if (/mobile|android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent)) {
      return /iphone|ipad|ipod/i.test(userAgent) ? 'ios' : 'android';
    }
    return 'desktop';
  }, []);

  useEffect(() => {
    if (!currentUser?.id) return;

    const channel = supabase.channel(CHANNEL_NAME, {
      config: {
        presence: {
          key: currentUser.id,
        },
      },
    });

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState();
        const users: PresenceUser[] = [];

        Object.entries(state).forEach(([key, presences]) => {
          if (Array.isArray(presences) && presences.length > 0) {
            const latestPresence = presences[presences.length - 1] as PresenceUser;
            users.push({
              id: key,
              email: latestPresence.email,
              username: latestPresence.username,
              platform: latestPresence.platform,
              online_at: latestPresence.online_at,
            });
          }
        });

        setOnlineUsers(users);
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track({
            id: currentUser.id,
            email: currentUser.email,
            username: currentUser.username,
            platform: detectPlatform(),
            online_at: new Date().toISOString(),
          });
        }
      });

    channelRef.current = channel;

    return () => {
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
        channelRef.current = null;
      }
    };
  }, [currentUser?.id, currentUser?.email, currentUser?.username, detectPlatform]);

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
  const [onlineUsers, setOnlineUsers] = useState<PresenceUser[]>([]);
  const channelRef = useRef<RealtimeChannel | null>(null);

  const updatePresenceState = useCallback((channel: RealtimeChannel) => {
    const state = channel.presenceState();
    const users: PresenceUser[] = [];

    Object.entries(state).forEach(([key, presences]) => {
      if (Array.isArray(presences) && presences.length > 0) {
        const latestPresence = presences[presences.length - 1] as PresenceUser;
        users.push({
          id: key,
          email: latestPresence.email,
          username: latestPresence.username,
          platform: latestPresence.platform,
          online_at: latestPresence.online_at,
        });
      }
    });

    setOnlineUsers(users);
  }, []);

  useEffect(() => {
    const adminId = `admin-observer-${Date.now()}`;

    const channel = supabase.channel(CHANNEL_NAME, {
      config: {
        presence: {
          key: adminId,
        },
      },
    });

    channel
      .on('presence', { event: 'sync' }, () => {
        updatePresenceState(channel);
      })
      .on('presence', { event: 'join' }, () => {
        updatePresenceState(channel);
      })
      .on('presence', { event: 'leave' }, () => {
        updatePresenceState(channel);
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track({
            id: adminId,
            is_admin_observer: true,
            online_at: new Date().toISOString(),
          });
          updatePresenceState(channel);
        }
      });

    channelRef.current = channel;

    return () => {
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
        channelRef.current = null;
      }
    };
  }, [updatePresenceState]);

  const filteredOnlineUsers = useMemo(() => {
    return onlineUsers.filter(u => !(u as any).is_admin_observer);
  }, [onlineUsers]);

  const isUserOnline = useCallback((userId: string) => {
    return filteredOnlineUsers.some(u => u.id === userId);
  }, [filteredOnlineUsers]);

  return {
    onlineUsers: filteredOnlineUsers,
    onlineCount: filteredOnlineUsers.length,
    isUserOnline,
  };
}
