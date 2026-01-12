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

export interface StaffActivityLog {
  action_type: string;
  action_description: string;
  target_user_id?: string;
  page_visited?: string;
  search_query?: string;
  metadata?: Record<string, any>;
}

export type StaffActionType =
  | 'page_view'
  | 'user_profile_view'
  | 'search_performed'
  | 'ticket_viewed'
  | 'ticket_response'
  | 'template_created'
  | 'email_sent'
  | 'bonus_awarded'
  | 'phone_reveal_request'
  | 'export_data'
  | 'filter_applied';

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

  async logStaffActivity(log: StaffActivityLog): Promise<void> {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      await supabase.from('staff_activity_logs').insert({
        staff_id: user.id,
        action_type: log.action_type,
        action_description: log.action_description,
        target_user_id: log.target_user_id,
        page_visited: log.page_visited,
        search_query: log.search_query,
        ip_address: await this.getClientIP(),
        user_agent: navigator.userAgent,
        metadata: log.metadata || {},
      });
    } catch (error) {
      console.error('Failed to log staff activity:', error);
    }
  }

  async logStaffPageView(pageName: string): Promise<void> {
    await this.logStaffActivity({
      action_type: 'page_view',
      action_description: `Viewed ${pageName} page`,
      page_visited: pageName,
    });
  }

  async logStaffUserView(targetUserId: string, userName?: string): Promise<void> {
    await this.logStaffActivity({
      action_type: 'user_profile_view',
      action_description: `Viewed user profile${userName ? `: ${userName}` : ''}`,
      target_user_id: targetUserId,
    });
  }

  async logStaffSearch(query: string, pageName: string): Promise<void> {
    await this.logStaffActivity({
      action_type: 'search_performed',
      action_description: `Searched for "${query}"`,
      page_visited: pageName,
      search_query: query,
    });
  }

  async logStaffTicketAction(ticketId: string, action: 'viewed' | 'responded', targetUserId?: string): Promise<void> {
    await this.logStaffActivity({
      action_type: action === 'viewed' ? 'ticket_viewed' : 'ticket_response',
      action_description: action === 'viewed' ? 'Viewed support ticket' : 'Responded to support ticket',
      target_user_id: targetUserId,
      metadata: { ticket_id: ticketId },
    });
  }

  async logStaffEmailSent(targetUserId: string, templateName?: string): Promise<void> {
    await this.logStaffActivity({
      action_type: 'email_sent',
      action_description: `Sent email${templateName ? ` (${templateName})` : ''}`,
      target_user_id: targetUserId,
      metadata: { template_name: templateName },
    });
  }

  async logStaffBonusAwarded(targetUserId: string, bonusType: string, amount: number): Promise<void> {
    await this.logStaffActivity({
      action_type: 'bonus_awarded',
      action_description: `Awarded ${bonusType} bonus of $${amount}`,
      target_user_id: targetUserId,
      metadata: { bonus_type: bonusType, amount },
    });
  }

  async logStaffPhoneRevealRequest(targetUserId: string, reason: string): Promise<void> {
    await this.logStaffActivity({
      action_type: 'phone_reveal_request',
      action_description: 'Requested access to view phone number',
      target_user_id: targetUserId,
      metadata: { reason },
    });
  }

  async logStaffExport(exportType: string, recordCount: number): Promise<void> {
    await this.logStaffActivity({
      action_type: 'export_data',
      action_description: `Exported ${exportType} data (${recordCount} records)`,
      metadata: { export_type: exportType, record_count: recordCount },
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
