import { useEffect, useRef } from 'react';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';

export function usePageTracking(pagePath: string, pageTitle?: string) {
  const { user } = useAuth();
  const startTimeRef = useRef<number>(Date.now());
  const hasTrackedRef = useRef(false);

  useEffect(() => {
    if (!user || hasTrackedRef.current) return;

    const trackPageVisit = async () => {
      try {
        await supabase.rpc('track_page_visit', {
          p_user_id: user.id,
          p_page_path: pagePath,
          p_page_title: pageTitle || pagePath,
          p_duration_seconds: null,
          p_ip_address: null
        });
        hasTrackedRef.current = true;
        startTimeRef.current = Date.now();
      } catch (error) {
        console.error('Failed to track page visit:', error);
      }
    };

    trackPageVisit();

    return () => {
      if (hasTrackedRef.current) {
        const durationSeconds = Math.floor((Date.now() - startTimeRef.current) / 1000);

        (async () => {
          try {
            await supabase.rpc('track_page_visit', {
              p_user_id: user.id,
              p_page_path: pagePath,
              p_page_title: pageTitle || pagePath,
              p_duration_seconds: durationSeconds,
              p_ip_address: null
            });
          } catch (err) {
            console.error('Failed to log page duration:', err);
          }
        })();
      }
    };
  }, [user, pagePath, pageTitle]);
}
