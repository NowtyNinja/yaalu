import path from 'path';
import fs from 'fs';
import { logger } from '../utils/logger';

function normalizeSenderId(raw?: string): string {
  const trimmed = (raw || '').trim();
  const lower = trimmed.toLowerCase();
  if (lower === 'sell4n.lk') return 'Sell4n.lk';
  if (lower === 'adumkade.lk') return 'AdumKade.lk';
  if (lower === 'notifydemo') return 'NotifyDEMO';
  return trimmed || 'Sell4n.lk';
}

export interface SmsConfigData {
  enabled: boolean;
  smsGatewayProvider: 'notify_lk' | 'mock' | 'twilio' | 'generic';
  senderId: string;
  genericSmsUrl?: string;
  notifyLkUserId?: string;
  notifyLkApiKey?: string;
  twilioAccountSid?: string;
  twilioAuthToken?: string;
  twilioFromNumber?: string;
}

export interface SmsLogEntry {
  id: string;
  phone: string;
  code: string;
  provider: string;
  status: 'sent' | 'failed' | 'mock';
  message: string;
  timestamp: string;
}

class SmsService {
  private configData: SmsConfigData = {
    enabled: true,
    smsGatewayProvider: 'notify_lk',
    senderId: 'NotifyDEMO',
  };
  private configFilePath: string;
  private smsLogs: SmsLogEntry[] = [];

  constructor() {
    this.configFilePath = path.join(__dirname, '../../config/sms.json');
    this.loadConfiguration();
  }

  public loadConfiguration(): void {
    try {
      const configDir = path.dirname(this.configFilePath);
      if (!fs.existsSync(configDir)) {
        fs.mkdirSync(configDir, { recursive: true });
      }

      let savedConfig: Partial<SmsConfigData> = {};
      if (fs.existsSync(this.configFilePath)) {
        try {
          const raw = fs.readFileSync(this.configFilePath, 'utf-8');
          savedConfig = JSON.parse(raw);
        } catch (_) {}
      } else {
        const legacyPath = path.join(configDir, 'firebase.json');
        if (fs.existsSync(legacyPath)) {
          try {
            const raw = fs.readFileSync(legacyPath, 'utf-8');
            savedConfig = JSON.parse(raw);
          } catch (_) {}
        }
      }

      const enabled = savedConfig.enabled ?? (process.env.SMS_ENABLED !== 'false');
      const rawProvider = savedConfig.smsGatewayProvider || process.env.SMS_GATEWAY_PROVIDER;
      const smsGatewayProvider =
        (rawProvider === 'firebase' ? 'notify_lk' : (rawProvider as any)) || 'notify_lk';

      this.configData = {
        enabled,
        smsGatewayProvider,
        senderId: normalizeSenderId(savedConfig.senderId || process.env.SMS_SENDER_ID || 'Sell4n.lk'),
        genericSmsUrl: savedConfig.genericSmsUrl || process.env.GENERIC_SMS_URL || '',
        notifyLkUserId: savedConfig.notifyLkUserId || process.env.NOTIFY_LK_USER_ID || '',
        notifyLkApiKey: savedConfig.notifyLkApiKey || process.env.NOTIFY_LK_API_KEY || '',
        twilioAccountSid: savedConfig.twilioAccountSid || process.env.TWILIO_ACCOUNT_SID || '',
        twilioAuthToken: savedConfig.twilioAuthToken || process.env.TWILIO_AUTH_TOKEN || '',
        twilioFromNumber: savedConfig.twilioFromNumber || process.env.TWILIO_FROM_NUMBER || '',
      };

      logger.info(`💬 SMS Gateway Service loaded: Provider [${this.configData.smsGatewayProvider}], Sender [${this.configData.senderId}]`);
    } catch (err: any) {
      logger.error('Error in loadConfiguration for SmsService:', err.message);
    }
  }

  public updateConfig(newConfig: Partial<SmsConfigData>): { success: boolean; message: string } {
    try {
      this.configData = {
        ...this.configData,
        ...newConfig,
      };

      const configDir = path.dirname(this.configFilePath);
      if (!fs.existsSync(configDir)) {
        fs.mkdirSync(configDir, { recursive: true });
      }

      fs.writeFileSync(this.configFilePath, JSON.stringify(this.configData, null, 2), 'utf-8');
      this.loadConfiguration();

      return {
        success: true,
        message: 'SMS Gateway configuration saved successfully',
      };
    } catch (err: any) {
      return {
        success: false,
        message: 'Failed to save SMS configuration: ' + err.message,
      };
    }
  }

  public getStatus() {
    return {
      enabled: this.configData.enabled,
      smsGatewayProvider: this.configData.smsGatewayProvider,
      senderId: this.configData.senderId,
      genericSmsUrl: this.configData.genericSmsUrl ? `${this.configData.genericSmsUrl.substring(0, 30)}...` : '',
      notifyLkUserId: this.configData.notifyLkUserId || '',
      hasNotifyLk: !!(this.configData.notifyLkUserId && this.configData.notifyLkApiKey),
      hasTwilio: !!(this.configData.twilioAccountSid && this.configData.twilioAuthToken),
    };
  }

  public getSmsLogs(): SmsLogEntry[] {
    return [...this.smsLogs];
  }

  private logSms(entry: Omit<SmsLogEntry, 'id' | 'timestamp'>) {
    const fullEntry: SmsLogEntry = {
      id: `sms_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      timestamp: new Date().toISOString(),
      ...entry,
    };
    this.smsLogs.unshift(fullEntry);
    if (this.smsLogs.length > 100) {
      this.smsLogs.pop();
    }
  }

  public async sendSmsOtp(
    phone: string,
    code: string
  ): Promise<{ success: boolean; message: string; provider: string; details?: any }> {
    let formattedPhone = phone.replace(/[\s\-\(\)]+/g, '');
    if (formattedPhone.startsWith('0') && formattedPhone.length === 10) {
      formattedPhone = '+94' + formattedPhone.substring(1);
    } else if (formattedPhone.startsWith('94') && formattedPhone.length === 11) {
      formattedPhone = '+' + formattedPhone;
    } else if (!formattedPhone.startsWith('+')) {
      formattedPhone = '+94' + formattedPhone;
    }

    const provider = this.configData.smsGatewayProvider;
    const senderId = (this.configData.senderId && this.configData.senderId.trim().length > 0)
      ? this.configData.senderId.trim()
      : 'NotifyDEMO';
    const message = `Your Yaalu verification code is: ${code}. Valid for 3 minutes. Do not share this with anyone.`;

    // 1. Mock / Development Mode
    if (!this.configData.enabled || provider === 'mock') {
      logger.info(`[SMS MOCK] Verification code for [${formattedPhone}]: ${code}`);
      this.logSms({
        phone: formattedPhone,
        code,
        provider: 'mock',
        status: 'mock',
        message: 'Mock SMS logged (Dev Mode)',
      });
      return {
        success: true,
        message: 'Mock SMS dispatched (Development Mode)',
        provider: 'mock',
      };
    }

    // 2. Notify.lk (Sri Lanka SMS Gateway - Primary)
    if (provider === 'notify_lk' && this.configData.notifyLkUserId && this.configData.notifyLkApiKey) {
      try {
        const cleanTo = formattedPhone.replace('+', '').replace(/^0/, '94');
        const primarySender = normalizeSenderId(this.configData.senderId || 'Sell4n.lk');

        const dispatchWithSender = async (sid: string) => {
          const url = `https://app.notify.lk/api/v1/send?user_id=${encodeURIComponent(
            this.configData.notifyLkUserId!
          )}&api_key=${encodeURIComponent(
            this.configData.notifyLkApiKey!
          )}&message=${encodeURIComponent(message)}&to=${cleanTo}&sender_id=${encodeURIComponent(sid)}`;
          const resp = await fetch(url, { method: 'GET' });
          const data: any = await resp.json().catch(() => ({}));
          const isOk = resp.ok && (data.status === 'success' || data.code === 200 || data.data === 'Sent');
          return { isOk, data, sid };
        };

        // Attempt 1: primary sender
        let { isOk, data, sid } = await dispatchWithSender(primarySender);

        // Auto-Fallback: If rejected, retry with alternate verified sender ID
        if (!isOk) {
          const fallbackSender = primarySender.toLowerCase() === 'sell4n.lk' ? 'AdumKade.lk' : 'Sell4n.lk';
          logger.warn(`Notify.lk primary sender [${primarySender}] failed: ${JSON.stringify(data)}. Retrying with [${fallbackSender}]...`);
          const fallbackRes = await dispatchWithSender(fallbackSender);
          if (fallbackRes.isOk) {
            isOk = true;
            data = fallbackRes.data;
            sid = fallbackSender;
          }
        }

        this.logSms({
          phone: formattedPhone,
          code,
          provider: 'notify_lk',
          status: isOk ? 'sent' : 'failed',
          message: JSON.stringify(data).substring(0, 100),
        });

        let errMsg = data.message;
        if (!errMsg && typeof data.errors === 'string') {
          errMsg = data.errors;
        } else if (!errMsg && Array.isArray(data.errors)) {
          errMsg = data.errors.join(', ');
        } else if (!errMsg) {
          errMsg = 'Notify.lk dispatch failed';
        }

        return {
          success: isOk,
          message: isOk ? `SMS sent via Notify.lk (${sid})` : errMsg,
          provider: 'notify_lk',
          details: data,
        };
      } catch (err: any) {
        logger.error('Notify.lk error:', err.message);
        this.logSms({
          phone: formattedPhone,
          code,
          provider: 'notify_lk',
          status: 'failed',
          message: err.message,
        });
        return {
          success: false,
          message: 'Notify.lk network error: ' + err.message,
          provider: 'notify_lk',
        };
      }
    }

    // 3. Generic HTTP SMS Gateway
    if (provider === 'generic' && this.configData.genericSmsUrl) {
      try {
        const rawUrl = this.configData.genericSmsUrl;
        const targetUrl = rawUrl
          .replace(/\{phone\}/g, encodeURIComponent(formattedPhone))
          .replace(/\{to\}/g, encodeURIComponent(formattedPhone.replace('+', '')))
          .replace(/\{code\}/g, encodeURIComponent(code))
          .replace(/\{otp\}/g, encodeURIComponent(code))
          .replace(/\{message\}/g, encodeURIComponent(message))
          .replace(/\{senderId\}/g, encodeURIComponent(senderId));

        const resp = await fetch(targetUrl, { method: 'GET' });
        const text = await resp.text();
        const isOk = resp.ok;

        this.logSms({
          phone: formattedPhone,
          code,
          provider: 'generic',
          status: isOk ? 'sent' : 'failed',
          message: `HTTP ${resp.status}: ${text.substring(0, 100)}`,
        });

        return {
          success: isOk,
          message: isOk ? 'SMS dispatched successfully via custom gateway' : `Gateway returned status ${resp.status}`,
          provider: 'generic',
          details: text,
        };
      } catch (err: any) {
        logger.error('Generic SMS Gateway error:', err.message);
        this.logSms({
          phone: formattedPhone,
          code,
          provider: 'generic',
          status: 'failed',
          message: err.message,
        });
        return {
          success: false,
          message: 'Failed to contact custom SMS gateway: ' + err.message,
          provider: 'generic',
        };
      }
    }

    // 4. Twilio SMS Gateway
    if (provider === 'twilio' && this.configData.twilioAccountSid && this.configData.twilioAuthToken) {
      try {
        const sid = this.configData.twilioAccountSid;
        const authHeader = 'Basic ' + Buffer.from(`${sid}:${this.configData.twilioAuthToken}`).toString('base64');
        const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`;

        const bodyParams = new URLSearchParams();
        bodyParams.append('To', formattedPhone);
        bodyParams.append('From', this.configData.twilioFromNumber || senderId);
        bodyParams.append('Body', message);

        const resp = await fetch(twilioUrl, {
          method: 'POST',
          headers: {
            Authorization: authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: bodyParams.toString(),
        });

        const data: any = await resp.json().catch(() => ({}));
        const isOk = resp.ok && !data.error_code;

        this.logSms({
          phone: formattedPhone,
          code,
          provider: 'twilio',
          status: isOk ? 'sent' : 'failed',
          message: data.sid ? `SID: ${data.sid}` : data.message || 'Twilio failed',
        });

        return {
          success: isOk,
          message: isOk ? 'SMS sent via Twilio' : data.message || 'Twilio rejected request',
          provider: 'twilio',
          details: data,
        };
      } catch (err: any) {
        logger.error('Twilio error:', err.message);
        this.logSms({
          phone: formattedPhone,
          code,
          provider: 'twilio',
          status: 'failed',
          message: err.message,
        });
        return {
          success: false,
          message: 'Twilio network error: ' + err.message,
          provider: 'twilio',
        };
      }
    }

    return {
      success: false,
      message: `SMS provider [${provider}] is not configured or unsupported.`,
      provider,
    };
  }
}

export const smsService = new SmsService();
export const firebaseService = smsService;
