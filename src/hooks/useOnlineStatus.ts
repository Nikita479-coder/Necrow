import { useState, useEffect, useCallback } from 'react';
import { getGlobalOnlineUsers, setExternalNotifyCallback } from './usePresence';

let onlineStatusListeners: Set<() => void> = new Set();

function notifyOnlineStatusListeners() {
  onlineStatusListeners.forEach(listener => listener());
}

setExternalNotifyCallback(notifyOnlineStatusListeners);

export function useOnlineStatus(userId: string | null | undefined) {
  const [isOnline, setIsOnline] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    if (!userId) {
      setIsOnline(false);
      setLoading(false);
      return;
    }

    const checkStatus = () => {
      const users = getGlobalOnlineUsers();
      const online = users.some(u => u.id === userId);
      setIsOnline(online);
      setLoading(false);
    };

    checkStatus();

    const listener = () => {
      checkStatus();
    };

    onlineStatusListeners.add(listener);

    const interval = setInterval(checkStatus, 2000);

    return () => {
      onlineStatusListeners.delete(listener);
      clearInterval(interval);
    };
  }, [userId]);

  return { isOnline, loading };
}

export function useRealtimeOnlineStatus(userId: string | null | undefined) {
  const [isOnline, setIsOnline] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    if (!userId) {
      setIsOnline(false);
      setLoading(false);
      return;
    }

    const checkStatus = () => {
      const users = getGlobalOnlineUsers();
      const online = users.some(u => u.id === userId);
      setIsOnline(online);
      setLoading(false);
    };

    checkStatus();

    const listener = () => {
      checkStatus();
    };

    onlineStatusListeners.add(listener);

    const interval = setInterval(checkStatus, 1000);

    return () => {
      onlineStatusListeners.delete(listener);
      clearInterval(interval);
    };
  }, [userId]);

  return { isOnline, loading };
}

export function useMultipleOnlineStatus(userIds: string[]) {
  const [onlineStatus, setOnlineStatus] = useState<Map<string, boolean>>(new Map());
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    if (userIds.length === 0) {
      setOnlineStatus(new Map());
      setLoading(false);
      return;
    }

    const checkStatus = () => {
      const users = getGlobalOnlineUsers();
      const onlineIds = new Set(users.map(u => u.id));
      const statusMap = new Map<string, boolean>();
      userIds.forEach(id => {
        statusMap.set(id, onlineIds.has(id));
      });
      setOnlineStatus(statusMap);
      setLoading(false);
    };

    checkStatus();

    const listener = () => {
      checkStatus();
    };

    onlineStatusListeners.add(listener);

    const interval = setInterval(checkStatus, 2000);

    return () => {
      onlineStatusListeners.delete(listener);
      clearInterval(interval);
    };
  }, [userIds.join(',')]);

  return { onlineStatus, loading };
}

export function useRealtimeMultipleOnlineStatus(userIds: string[]) {
  const [onlineStatus, setOnlineStatus] = useState<Map<string, boolean>>(new Map());
  const [loading, setLoading] = useState<boolean>(true);
  const [onlineUsers, setOnlineUsers] = useState<any[]>([]);

  useEffect(() => {
    if (userIds.length === 0) {
      setOnlineStatus(new Map());
      setOnlineUsers([]);
      setLoading(false);
      return;
    }

    const checkStatus = () => {
      const users = getGlobalOnlineUsers();
      setOnlineUsers(users);
      const onlineIds = new Set(users.map(u => u.id));
      const statusMap = new Map<string, boolean>();
      userIds.forEach(id => {
        statusMap.set(id, onlineIds.has(id));
      });
      setOnlineStatus(statusMap);
      setLoading(false);
    };

    checkStatus();

    const listener = () => {
      checkStatus();
    };

    onlineStatusListeners.add(listener);

    const interval = setInterval(checkStatus, 1000);

    return () => {
      onlineStatusListeners.delete(listener);
      clearInterval(interval);
    };
  }, [userIds.join(',')]);

  return { onlineStatus, loading, onlineUsers };
}

export function useOnlineUsers() {
  const [onlineUsers, setOnlineUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    const checkStatus = () => {
      const users = getGlobalOnlineUsers();
      setOnlineUsers(users);
      setLoading(false);
    };

    checkStatus();

    const listener = () => {
      checkStatus();
    };

    onlineStatusListeners.add(listener);

    const interval = setInterval(checkStatus, 2000);

    return () => {
      onlineStatusListeners.delete(listener);
      clearInterval(interval);
    };
  }, []);

  return { onlineUsers, loading };
}

export function useRealtimeOnlineUsers() {
  const [onlineUsers, setOnlineUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  useEffect(() => {
    const checkStatus = () => {
      const users = getGlobalOnlineUsers();
      setOnlineUsers(users);
      setLoading(false);
    };

    checkStatus();

    const listener = () => {
      checkStatus();
    };

    onlineStatusListeners.add(listener);

    const interval = setInterval(checkStatus, 1000);

    return () => {
      onlineStatusListeners.delete(listener);
      clearInterval(interval);
    };
  }, []);

  const isUserOnline = useCallback((userId: string) => {
    return onlineUsers.some(u => u.id === userId);
  }, [onlineUsers]);

  return { onlineUsers, onlineCount: onlineUsers.length, isUserOnline, loading };
}
