import { supabase } from '../lib/supabase';

const STORAGE_KEY = 'acquisition_data';
const SESSION_KEY = 'visitor_session_id';

export interface AcquisitionData {
  utm_source?: string;
  utm_medium?: string;
  utm_campaign?: string;
  utm_content?: string;
  utm_term?: string;
  referrer_url?: string;
  landing_page?: string;
  device_type?: string;
  browser?: string;
  os?: string;
  timestamp?: number;
  session_id?: string;
}

function generateSessionId(): string {
  return 'vs_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 15);
}

function getOrCreateSessionId(): string {
  let sessionId = localStorage.getItem(SESSION_KEY);
  if (!sessionId) {
    sessionId = generateSessionId();
    localStorage.setItem(SESSION_KEY, sessionId);
  }
  return sessionId;
}

export function getSessionId(): string {
  return getOrCreateSessionId();
}

function getDeviceType(): string {
  const ua = navigator.userAgent;
  if (/(tablet|ipad|playbook|silk)|(android(?!.*mobi))/i.test(ua)) {
    return 'tablet';
  }
  if (/Mobile|Android|iP(hone|od)|IEMobile|BlackBerry|Kindle|Silk-Accelerated|(hpw|web)OS|Opera M(obi|ini)/.test(ua)) {
    return 'mobile';
  }
  return 'desktop';
}

function getBrowser(): string {
  const ua = navigator.userAgent;
  if (ua.includes('Firefox')) return 'Firefox';
  if (ua.includes('SamsungBrowser')) return 'Samsung Browser';
  if (ua.includes('Opera') || ua.includes('OPR')) return 'Opera';
  if (ua.includes('Trident')) return 'IE';
  if (ua.includes('Edge')) return 'Edge';
  if (ua.includes('Edg')) return 'Edge Chromium';
  if (ua.includes('Chrome')) return 'Chrome';
  if (ua.includes('Safari')) return 'Safari';
  return 'Unknown';
}

function getOS(): string {
  const ua = navigator.userAgent;
  if (ua.includes('Win')) return 'Windows';
  if (ua.includes('Mac')) return 'macOS';
  if (ua.includes('Linux')) return 'Linux';
  if (ua.includes('Android')) return 'Android';
  if (ua.includes('iOS') || ua.includes('iPhone') || ua.includes('iPad')) return 'iOS';
  return 'Unknown';
}

export function captureAcquisitionData(): AcquisitionData {
  const urlParams = new URLSearchParams(window.location.search);
  const sessionId = getOrCreateSessionId();

  const data: AcquisitionData = {
    session_id: sessionId,
    utm_source: urlParams.get('utm_source') || urlParams.get('source') || undefined,
    utm_medium: urlParams.get('utm_medium') || urlParams.get('medium') || undefined,
    utm_campaign: urlParams.get('utm_campaign') || urlParams.get('campaign') || undefined,
    utm_content: urlParams.get('utm_content') || undefined,
    utm_term: urlParams.get('utm_term') || undefined,
    referrer_url: document.referrer || undefined,
    landing_page: window.location.pathname + window.location.search,
    device_type: getDeviceType(),
    browser: getBrowser(),
    os: getOS(),
    timestamp: Date.now()
  };

  if (!data.utm_source && document.referrer) {
    try {
      const referrerDomain = new URL(document.referrer).hostname.toLowerCase();
      if (referrerDomain.includes('facebook') || referrerDomain.includes('fb.')) {
        data.utm_source = 'facebook';
        data.utm_medium = 'social';
      } else if (referrerDomain.includes('instagram')) {
        data.utm_source = 'instagram';
        data.utm_medium = 'social';
      } else if (referrerDomain.includes('tiktok')) {
        data.utm_source = 'tiktok';
        data.utm_medium = 'social';
      } else if (referrerDomain.includes('twitter') || referrerDomain.includes('x.com')) {
        data.utm_source = 'twitter';
        data.utm_medium = 'social';
      } else if (referrerDomain.includes('youtube')) {
        data.utm_source = 'youtube';
        data.utm_medium = 'social';
      } else if (referrerDomain.includes('linkedin')) {
        data.utm_source = 'linkedin';
        data.utm_medium = 'social';
      } else if (referrerDomain.includes('google')) {
        data.utm_source = 'google';
        data.utm_medium = 'organic';
      } else if (referrerDomain.includes('bing')) {
        data.utm_source = 'bing';
        data.utm_medium = 'organic';
      } else if (referrerDomain.includes('reddit')) {
        data.utm_source = 'reddit';
        data.utm_medium = 'social';
      } else if (referrerDomain.includes('telegram')) {
        data.utm_source = 'telegram';
        data.utm_medium = 'social';
      }
    } catch {
    }
  }

  return data;
}

export function storeAcquisitionData(data: AcquisitionData): void {
  const existing = getStoredAcquisitionData();

  if (!existing || (data.utm_source && !existing.utm_source)) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  }
}

export function getStoredAcquisitionData(): AcquisitionData | null {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      return JSON.parse(stored);
    }
  } catch {
  }
  return null;
}

export function clearAcquisitionData(): void {
  localStorage.removeItem(STORAGE_KEY);
}

async function trackVisitorInDatabase(data: AcquisitionData): Promise<void> {
  if (!data.session_id) return;

  try {
    await supabase.rpc('track_visitor_session', {
      p_session_id: data.session_id,
      p_utm_source: data.utm_source || null,
      p_utm_medium: data.utm_medium || null,
      p_utm_campaign: data.utm_campaign || null,
      p_utm_content: data.utm_content || null,
      p_utm_term: data.utm_term || null,
      p_referrer_url: data.referrer_url || null,
      p_landing_page: data.landing_page || null,
      p_device_type: data.device_type || null,
      p_browser: data.browser || null,
      p_os: data.os || null
    });
  } catch (error) {
    console.error('Failed to track visitor:', error);
  }
}

export async function saveAcquisitionToDatabase(userId: string): Promise<void> {
  const sessionId = getSessionId();
  const data = getStoredAcquisitionData();

  try {
    await supabase.rpc('link_visitor_to_user', {
      p_session_id: sessionId,
      p_user_id: userId
    });

    if (data) {
      await supabase.rpc('save_user_acquisition_data', {
        p_user_id: userId,
        p_utm_source: data.utm_source || null,
        p_utm_medium: data.utm_medium || null,
        p_utm_campaign: data.utm_campaign || null,
        p_utm_content: data.utm_content || null,
        p_utm_term: data.utm_term || null,
        p_referrer_url: data.referrer_url || null,
        p_landing_page: data.landing_page || null,
        p_device_type: data.device_type || null,
        p_browser: data.browser || null,
        p_os: data.os || null
      });
    }

    clearAcquisitionData();
  } catch (error) {
    console.error('Failed to save acquisition data:', error);
  }
}

export async function recordEvent(
  userId: string,
  eventType: string,
  eventData: Record<string, unknown> = {}
): Promise<void> {
  try {
    await supabase.rpc('record_acquisition_event', {
      p_user_id: userId,
      p_event_type: eventType,
      p_event_data: eventData
    });
  } catch (error) {
    console.error('Failed to record acquisition event:', error);
  }
}

export async function initAcquisitionTracking(): Promise<void> {
  const data = captureAcquisitionData();

  storeAcquisitionData(data);

  await trackVisitorInDatabase(data);
}
