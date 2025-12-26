import { supabase } from '../lib/supabase';

export interface AdminActivityLog {
  action_type: string;
  action_description: string;
  target_user_id?: string;
  ip_address?: string;
  metadata?: Record<string, any>;
}

export interface SecurityLog {
  user_id?: string;
  event_type: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  ip_address?: string;
  device_fingerprint?: string;
  success: boolean;
  failure_reason?: string;
  metadata?: Record<string, any>;
}

export interface FinancialLog {
  user_id: string;
  transaction_type: string;
  currency: string;
  amount: number;
  before_balance: number;
  after_balance: number;
  reference_id?: string;
  executed_by_admin_id?: string;
  reason?: string;
  metadata?: Record<string, any>;
}

export interface SystemAuditLog {
  event_type: string;
  severity: 'info' | 'warning' | 'error' | 'critical';
  description: string;
  affected_users_count?: number;
  triggered_by?: string;
  metadata?: Record<string, any>;
}

export interface KYCActionLog {
  user_id: string;
  admin_id?: string;
  action_type: string;
  old_status?: string;
  new_status?: string;
  document_id?: string;
  reason?: string;
  notes?: string;
}

class LoggingService {
  async logAdminActivity(log: AdminActivityLog): Promise<void> {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      await supabase.from('admin_activity_logs').insert({
        admin_id: user.id,
        ...log,
        ip_address: log.ip_address || await this.getClientIP(),
      });
    } catch (error) {
      console.error('Failed to log admin activity:', error);
    }
  }

  async logSecurityEvent(log: SecurityLog): Promise<void> {
    try {
      await supabase.from('security_logs').insert({
        ...log,
        ip_address: log.ip_address || await this.getClientIP(),
        device_fingerprint: log.device_fingerprint || await this.getDeviceFingerprint(),
      });
    } catch (error) {
      console.error('Failed to log security event:', error);
    }
  }

  async logFinancialTransaction(log: FinancialLog): Promise<void> {
    try {
      await supabase.from('financial_transaction_logs').insert(log);
    } catch (error) {
      console.error('Failed to log financial transaction:', error);
    }
  }

  async logSystemAudit(log: SystemAuditLog): Promise<void> {
    try {
      await supabase.from('system_audit_logs').insert(log);
    } catch (error) {
      console.error('Failed to log system audit:', error);
    }
  }

  async logKYCAction(log: KYCActionLog): Promise<void> {
    try {
      await supabase.from('kyc_action_logs').insert(log);
    } catch (error) {
      console.error('Failed to log KYC action:', error);
    }
  }

  async trackDeviceFingerprint(userId: string): Promise<void> {
    try {
      const deviceId = await this.getDeviceFingerprint();
      const ipAddress = await this.getClientIP();
      const userAgent = navigator.userAgent;

      const { data: existing } = await supabase
        .from('user_device_fingerprints')
        .select('*')
        .eq('user_id', userId)
        .eq('device_id', deviceId)
        .single();

      if (existing) {
        await supabase
          .from('user_device_fingerprints')
          .update({
            last_seen_at: new Date().toISOString(),
            login_count: existing.login_count + 1,
            ip_address: ipAddress,
          })
          .eq('id', existing.id);
      } else {
        await supabase.from('user_device_fingerprints').insert({
          user_id: userId,
          device_id: deviceId,
          ip_address: ipAddress,
          user_agent: userAgent,
          location: 'Unknown',
        });
      }
    } catch (error) {
      console.error('Failed to track device fingerprint:', error);
    }
  }

  async logUserLogin(userId: string, success: boolean, failureReason?: string): Promise<void> {
    await this.logSecurityEvent({
      user_id: userId,
      event_type: success ? 'login' : 'login_failed',
      severity: success ? 'low' : 'medium',
      success,
      failure_reason: failureReason,
    });

    if (success) {
      await this.trackDeviceFingerprint(userId);
    }
  }

  async logUserLogout(userId: string): Promise<void> {
    await this.logSecurityEvent({
      user_id: userId,
      event_type: 'logout',
      severity: 'low',
      success: true,
    });
  }

  private async getClientIP(): Promise<string> {
    try {
      const response = await fetch('https://api.ipify.org?format=json');
      const data = await response.json();
      return data.ip || 'unknown';
    } catch {
      return 'unknown';
    }
  }

  private async getDeviceFingerprint(): Promise<string> {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    if (!ctx) return 'unknown';

    ctx.textBaseline = 'top';
    ctx.font = '14px Arial';
    ctx.fillText('fingerprint', 2, 2);
    const canvasData = canvas.toDataURL();

    const components = [
      navigator.userAgent,
      navigator.language,
      screen.colorDepth,
      screen.width + 'x' + screen.height,
      new Date().getTimezoneOffset(),
      canvasData.substring(0, 100),
    ];

    const fingerprint = await this.simpleHash(components.join('###'));
    return fingerprint;
  }

  private async simpleHash(str: string): Promise<string> {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }
}

export const loggingService = new LoggingService();
