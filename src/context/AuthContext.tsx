import { createContext, useContext, useState, useEffect, useRef, ReactNode } from 'react';
import { supabase } from '../lib/supabase';
import type { User, RealtimeChannel } from '@supabase/supabase-js';
import { sessionService } from '../services/sessionService';

interface UserProfile {
  id: string;
  username: string | null;
  full_name: string | null;
  email: string;
  phone: string | null;
  country: string | null;
  referral_code: string;
  kyc_status: string;
  kyc_level: number;
  is_admin: boolean;
  active_program: 'referral' | 'affiliate';
  created_at: string;
  updated_at: string;
}

interface StaffInfo {
  is_super_admin: boolean;
  is_staff: boolean;
  is_active?: boolean;
  role_name: string | null;
  role_id: string | null;
  permissions: string[];
}

interface MfaRequirement {
  required: boolean;
  factorId: string | null;
}

interface SignInResult {
  error: Error | null;
  mfaRequired?: boolean;
  factorId?: string;
  ipVerificationRequired?: boolean;
  pendingUserId?: string;
}

interface AuthContextType {
  isAuthenticated: boolean;
  user: User | null;
  profile: UserProfile | null;
  staffInfo: StaffInfo | null;
  loading: boolean;
  signUp: (email: string, password: string, fullName: string, phone: string, referralCode?: string, promoCode?: string) => Promise<{ error: Error | null }>;
  signIn: (email: string, password: string) => Promise<SignInResult>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
  hasPermission: (permission: string) => boolean;
  hasAnyPermission: (permissions: string[]) => boolean;
  canAccessAdmin: () => boolean;
  verifyMfa: (factorId: string, code: string) => Promise<{ error: Error | null }>;
  sendIpVerification: (userId: string, email: string) => Promise<{ error: Error | null }>;
  verifyIpCode: (code: string, userId?: string) => Promise<{ error: Error | null }>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

const detectPlatform = () => {
  const userAgent = navigator.userAgent.toLowerCase();
  if (/mobile|android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent)) {
    return /iphone|ipad|ipod/i.test(userAgent) ? 'ios' : 'android';
  }
  return 'desktop';
};

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [staffInfo, setStaffInfo] = useState<StaffInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [mfaPending, setMfaPending] = useState(false);
  const mfaPendingRef = useRef(false);
  const presenceChannelRef = useRef<RealtimeChannel | null>(null);

  const startPresenceTracking = async (userId: string, email?: string, username?: string | null) => {
    if (presenceChannelRef.current) {
      await supabase.removeChannel(presenceChannelRef.current);
    }

    const channel = supabase.channel('online-users', {
      config: {
        presence: {
          key: userId,
        },
      },
    });

    channel.subscribe(async (status) => {
      if (status === 'SUBSCRIBED') {
        await channel.track({
          id: userId,
          email: email || '',
          username: username || '',
          platform: detectPlatform(),
          online_at: new Date().toISOString(),
        });
      }
    });

    presenceChannelRef.current = channel;
  };

  const stopPresenceTracking = async () => {
    if (presenceChannelRef.current) {
      await supabase.removeChannel(presenceChannelRef.current);
      presenceChannelRef.current = null;
    }
  };

  const fetchStaffInfo = async () => {
    try {
      const { data, error } = await supabase.rpc('get_my_staff_info');

      if (error) {
        console.error('Error fetching staff info:', error);
        setStaffInfo(null);
        return;
      }

      if (data) {
        setStaffInfo({
          is_super_admin: data.is_super_admin || false,
          is_staff: data.is_staff || false,
          is_active: data.is_active,
          role_name: data.role_name || null,
          role_id: data.role_id || null,
          permissions: data.permissions || [],
        });
      }
    } catch (error) {
      console.error('Error fetching staff info:', error);
      setStaffInfo(null);
    }
  };

  const fetchProfile = async (userId: string, userSession?: any) => {
    try {
      const { data, error } = await supabase
        .from('user_profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      if (error) throw error;

      if (data) {
        const isAdminFromJWT = userSession?.user?.app_metadata?.is_admin || false;
        const userEmail = userSession?.user?.email || '';
        const profileData: UserProfile = {
          id: data.id,
          username: data.username,
          full_name: data.full_name,
          email: userEmail,
          phone: data.phone,
          country: data.country,
          referral_code: data.referral_code,
          kyc_status: data.kyc_status,
          kyc_level: data.kyc_level,
          is_admin: isAdminFromJWT || data.is_admin || false,
          active_program: data.active_program || 'referral',
          created_at: data.created_at,
          updated_at: data.updated_at,
        };
        setProfile(profileData);

        await fetchStaffInfo();
        startPresenceTracking(userId, userEmail, data.username);
      }
    } catch (error) {
      console.error('Error fetching profile:', error);
    }
  };

  const refreshProfile = async () => {
    if (user) {
      const { data: { session } } = await supabase.auth.getSession();
      await fetchProfile(user.id, session);
    }
  };

  useEffect(() => {
    const checkImpersonation = async () => {
      const urlParams = new URLSearchParams(window.location.search);
      const isImpersonated = urlParams.get('impersonated') === 'true';

      if (isImpersonated) {
        const tokensJson = localStorage.getItem('impersonation_tokens');
        if (tokensJson) {
          try {
            const tokens = JSON.parse(tokensJson);
            localStorage.removeItem('impersonation_tokens');

            const { error } = await supabase.auth.setSession({
              access_token: tokens.access_token,
              refresh_token: tokens.refresh_token,
            });

            if (error) {
              console.error('Failed to set impersonation session:', error);
            } else {
              window.history.replaceState({}, '', window.location.pathname);
            }
          } catch (error) {
            console.error('Failed to parse impersonation tokens:', error);
          }
        }
      }
    };

    checkImpersonation().then(async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        const { data: aalData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
        const needsMfa = aalData?.currentLevel === 'aal1' && aalData?.nextLevel === 'aal2';
        if (needsMfa) {
          mfaPendingRef.current = true;
          setMfaPending(true);
          setUser(null);
        } else {
          mfaPendingRef.current = false;
          setMfaPending(false);
          setUser(session.user);
          fetchProfile(session.user.id, session);
          sessionService.start(session.user.id);
        }
      } else {
        setUser(null);
      }
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (mfaPendingRef.current) {
        setLoading(false);
        return;
      }

      if (session?.user) {
        setUser(session.user);
        fetchProfile(session.user.id, session);
        sessionService.start(session.user.id);
      } else {
        setUser(null);
        setProfile(null);
        setStaffInfo(null);
        setMfaPending(false);
        mfaPendingRef.current = false;
        sessionService.stop();
        stopPresenceTracking();
      }
      setLoading(false);
    });

    return () => {
      subscription.unsubscribe();
      sessionService.stop();
      stopPresenceTracking();
    };
  }, []);

  const signUp = async (email: string, password: string, fullName: string, phone: string, referralCode?: string, promoCode?: string) => {
    try {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName,
            referral_code: referralCode ? referralCode.toUpperCase().trim() : undefined,
            promo_code: promoCode ? promoCode.toUpperCase().trim() : undefined,
          },
        },
      });

      if (error) throw error;

      if (data.user) {
        const updateProfile = async (retries = 3): Promise<boolean> => {
          for (let i = 0; i < retries; i++) {
            if (i > 0) {
              await new Promise(resolve => setTimeout(resolve, 500 * i));
            }

            const { data: updatedData, error: updateError } = await supabase
              .from('user_profiles')
              .update({ phone: phone })
              .eq('id', data.user!.id)
              .select()
              .maybeSingle();

            if (!updateError && updatedData) {
              return true;
            }
          }
          return false;
        };

        await updateProfile();

        if (promoCode) {
          await supabase.rpc('validate_and_redeem_promo_code', {
            p_user_id: data.user.id,
            p_promo_code: promoCode.toUpperCase().trim()
          });
        }
      }

      return { error: null, data };
    } catch (error) {
      return { error: error as Error, data: null };
    }
  };

  const getDeviceInfo = () => {
    return navigator.userAgent;
  };

  const getUserIpAndLocation = async () => {
    try {
      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/get-ip-location`);
      const data = await response.json();
      return data;
    } catch (error) {
      console.error('Error getting IP location:', error);
      return null;
    }
  };

  const signIn = async (email: string, password: string): Promise<SignInResult> => {
    try {
      mfaPendingRef.current = true;

      const { data: authData, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        mfaPendingRef.current = false;
        throw error;
      }

      if (!authData.user) {
        mfaPendingRef.current = false;
        throw new Error('No user data returned');
      }

      const { data: factorsData } = await supabase.auth.mfa.listFactors();
      const verifiedFactor = factorsData?.totp?.find((factor: any) => factor.status === 'verified');

      if (verifiedFactor) {
        setMfaPending(true);
        return { error: null, mfaRequired: true, factorId: verifiedFactor.id };
      }

      mfaPendingRef.current = false;

      const locationData = await getUserIpAndLocation();
      const ipAddress = locationData?.ip || 'unknown';
      const deviceInfo = getDeviceInfo();

      const { data: ipCheckData, error: ipCheckError } = await supabase
        .rpc('check_ip_trusted', {
          p_user_id: authData.user.id,
          p_ip_address: ipAddress
        });

      if (ipCheckError) {
        console.error('Error checking IP trust:', ipCheckError);
      }

      await supabase.rpc('log_login_attempt', {
        p_user_id: authData.user.id,
        p_ip_address: ipAddress,
        p_device_info: deviceInfo,
        p_location: locationData,
        p_success: true,
        p_requires_verification: !ipCheckData?.is_trusted
      });

      if (!ipCheckData?.is_trusted) {
        await supabase.auth.signOut();

        return {
          error: null,
          mfaRequired: false,
          ipVerificationRequired: true,
          pendingUserId: authData.user.id
        };
      }

      setUser(authData.user);
      const { data: { session } } = await supabase.auth.getSession();
      if (session) {
        await fetchProfile(authData.user.id, session);
      }

      return { error: null, mfaRequired: false };
    } catch (error) {
      return { error: error as Error };
    }
  };

  const verifyMfa = async (factorId: string, code: string) => {
    try {
      const { error } = await supabase.auth.mfa.challengeAndVerify({
        factorId,
        code,
      });

      if (error) throw error;

      mfaPendingRef.current = false;
      setMfaPending(false);

      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        setUser(session.user);
        fetchProfile(session.user.id, session);
        sessionService.start(session.user.id);
      }

      return { error: null };
    } catch (error) {
      return { error: error as Error };
    }
  };

  const sendIpVerification = async (userId: string, email: string) => {
    try {
      const locationData = await getUserIpAndLocation();
      const ipAddress = locationData?.ip || 'unknown';
      const deviceInfo = getDeviceInfo();

      const { data: { session } } = await supabase.auth.getSession();

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/send-ip-verification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`
        },
        body: JSON.stringify({
          email,
          userId,
          ipAddress,
          deviceInfo,
          location: locationData
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to send verification code');
      }

      return { error: null };
    } catch (error) {
      return { error: error as Error };
    }
  };

  const verifyIpCode = async (code: string, userId?: string) => {
    try {
      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/verify-ip-code`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY}`
        },
        body: JSON.stringify({
          code,
          userId,
          trustDurationDays: 30
        })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Invalid or expired code');
      }

      return { error: null };
    } catch (error) {
      return { error: error as Error };
    }
  };

  const signOut = async () => {
    try {
      await stopPresenceTracking();
      await supabase.auth.signOut();
      setUser(null);
      setProfile(null);
      setStaffInfo(null);
      localStorage.clear();
      sessionStorage.clear();
      window.location.href = '/';
    } catch (error) {
      console.error('Error signing out:', error);
      localStorage.clear();
      sessionStorage.clear();
      window.location.href = '/';
    }
  };

  const hasPermission = (permission: string): boolean => {
    if (!staffInfo) return false;
    if (staffInfo.is_super_admin) return true;
    if (!staffInfo.is_staff || !staffInfo.is_active) return false;
    return staffInfo.permissions.includes(permission);
  };

  const hasAnyPermission = (permissions: string[]): boolean => {
    if (!staffInfo) return false;
    if (staffInfo.is_super_admin) return true;
    if (!staffInfo.is_staff || !staffInfo.is_active) return false;
    return permissions.some(p => staffInfo.permissions.includes(p));
  };

  const canAccessAdmin = (): boolean => {
    if (profile?.is_admin) return true;
    if (staffInfo?.is_super_admin) return true;
    if (staffInfo?.is_staff && staffInfo?.is_active) return true;
    return false;
  };

  const isAuthenticated = !!user;

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        user,
        profile,
        staffInfo,
        loading,
        signUp,
        signIn,
        signOut,
        refreshProfile,
        hasPermission,
        hasAnyPermission,
        canAccessAdmin,
        verifyMfa,
        sendIpVerification,
        verifyIpCode,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
