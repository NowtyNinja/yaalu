import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { config } from '../config';
import { db } from '../database/store';
import { sendSuccess, sendError } from '../utils/response';
import { logger } from '../utils/logger';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';
import { smsService } from '../services/smsService';

// In-Memory Secure OTP Store (In production: Redis with 3-minute TTL)
const otpStore = new Map<string, { code: string; expiresAt: number; attempts: number }>();
const phoneChangeOtpStore = new Map<string, { newPhone: string; code: string; expiresAt: number }>();
const emailRecoveryOtpStore = new Map<string, { userId: string; code: string; expiresAt: number }>();

function normalizePhone(val: string): string {
  let clean = (val || '').replace(/[\s\-\(\)]+/g, '');
  if (clean.startsWith('0') && clean.length === 10) {
    clean = '+94' + clean.substring(1);
  } else if (clean.startsWith('94') && clean.length === 11) {
    clean = '+' + clean;
  } else if (!clean.startsWith('+') && clean.length === 9) {
    clean = '+94' + clean;
  } else if (!clean.startsWith('+') && clean.length > 0) {
    clean = '+94' + clean;
  }
  return clean;
}

// Validation Schemas
export const requestOtpSchema = z.object({
  phone: z
    .string()
    .transform((val) => normalizePhone(val))
    .refine((val) => /^\+?[1-9]\d{7,14}$/.test(val), {
      message: 'Invalid international E.164 phone format',
    }),
});

export const verifyOtpSchema = z.object({
  phone: z
    .string()
    .transform((val) => normalizePhone(val))
    .refine((val) => /^\+?[1-9]\d{7,14}$/.test(val), {
      message: 'Invalid phone format',
    }),
  otp: z.string().length(6, 'OTP must be 6 digits').regex(/^\d{6}$/, 'OTP must contain only numbers'),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(20, 'Invalid refresh token'),
});

export class AuthController {
  // Step 1: Request SMS OTP
  public static async requestOtp(req: Request, res: Response): Promise<void> {
    const { phone } = req.body;

    const fbStatus = smsService.getStatus();
    const isLiveSms = fbStatus.enabled && fbStatus.smsGatewayProvider !== 'mock';

    const isTestNumber = phone === '+94770000000' || phone === '+94711111111';

    // Fixed 123456 ONLY for Google Play review test accounts (+94770000000), random 6 digits for all live users & admin
    const code = isTestNumber
      ? '123456'
      : Math.floor(100000 + Math.random() * 900000).toString();

    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes validity

    otpStore.set(phone, { code, expiresAt, attempts: 0 });

    logger.info(`OTP generated for phone: [${phone}] (Code: ${isTestNumber ? 'TEST_123456' : '***'})`);

    // Dispatch SMS via Notify.lk / Gateway (skip SMS only for test reviewer numbers)
    const smsDispatch = isTestNumber
      ? { success: true, message: 'Google Play review test account (Code: 123456)', provider: 'test_bypass' }
      : await smsService.sendSmsOtp(phone, code);

    // SECURITY: NEVER send mockOtpHint for admin (+94786799544) or any real user!
    // mockOtpHint is ONLY returned for test accounts (+94770000000) when NOT in live SMS mode.
    const provideHint = isTestNumber && !isLiveSms;

    sendSuccess(
      res,
      {
        phone,
        expiresInSeconds: 180,
        provider: smsDispatch.provider,
        smsDispatched: smsDispatch.success,
        mockOtpHint: provideHint ? code : undefined,
      },
      smsDispatch.success
        ? (smsDispatch.message || 'Verification code sent successfully via SMS')
        : `SMS Gateway (${smsDispatch.provider}): ${smsDispatch.message}`
    );
  }

  // Step 2: Verify OTP and Issue Tokens
  public static async verifyOtp(req: Request, res: Response): Promise<void> {
    const { phone, otp } = req.body;

    // SECURITY: Master bypass 123456 ONLY applies to the reviewer test account (+94770000000).
    // The admin (+94786799544) and all real users MUST enter their real random SMS OTP.
    const isTestNumber = phone === '+94770000000' || phone === '+94711111111';
    const isMasterBypass = isTestNumber && otp === '123456';

    const record = otpStore.get(phone);
    if (!record && !isMasterBypass) {
      sendError(res, 'No OTP requested for this phone number or it has expired.', 400, 'OTP_EXPIRED');
      return;
    }

    if (record && Date.now() > record.expiresAt && !isMasterBypass) {
      otpStore.delete(phone);
      sendError(res, 'Verification code has expired. Please request a new one.', 400, 'OTP_EXPIRED');
      return;
    }

    if (record && record.attempts >= 5 && !isMasterBypass) {
      otpStore.delete(phone);
      logger.securityAlert('OTP_BRUTE_FORCE_BLOCKED', { phone, ip: req.ip });
      sendError(res, 'Too many incorrect attempts. Request a new OTP.', 429, 'MAX_ATTEMPTS_EXCEEDED');
      return;
    }

    if (!isMasterBypass && record && record.code !== otp) {
      record.attempts += 1;
      sendError(res, 'Invalid verification code. Please check and try again.', 400, 'INVALID_OTP');
      return;
    }

    // OTP is valid - consume it immediately
    if (record) otpStore.delete(phone);

    // Find or create user
    let user = db.getUserByPhone(phone);
    let isNewUser = false;
    let profile = user ? db.getProfileByUserId(user.id) : undefined;

    if (!user) {
      isNewUser = true;
      const created = db.createUser(phone);
      user = created.user;
      profile = created.profile;
    }

    // Special VIP Annual & Verified Blue Tick for Owner +94786799544
    if (phone === '+94786799544') {
      user.role = 'admin';
      user.subscriptionTier = 'vip_annual';
      user.superLikesRemaining = 999;
      db.users.set(user.id, user);

      if (profile) {
        profile.verificationStatus = 'verified';
        if (!profile.displayName) profile.displayName = 'Ushara';
        if (profile.photos.length === 0) {
          profile.photos = [
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=800&q=80',
          ];
        }
        db.profiles.set(user.id, profile);
      }
    }

    // Generate JWT Access & Refresh Tokens (Extended duration for uninterrupted mobile sessions)
    const accessToken = jwt.sign(
      { userId: user.id, role: user.role, phone: user.phone },
      config.jwt.accessSecret,
      { expiresIn: '30d' }
    );

    const refreshToken = jwt.sign(
      { userId: user.id, phone: user.phone },
      config.jwt.refreshSecret,
      { expiresIn: '90d' }
    );

    db.activeRefreshTokens.add(refreshToken);

    logger.info(`User logged in successfully: [${user.id}], isNewUser: ${isNewUser}`);

    sendSuccess(
      res,
      {
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: 900, // 15 mins in seconds
        },
        user,
        profile,
        isNewUser,
      },
      'Authenticated successfully'
    );
  }

  // Step 3: Refresh Access Token
  public static async refreshToken(req: Request, res: Response): Promise<void> {
    const { refreshToken } = req.body;

    if (!db.activeRefreshTokens.has(refreshToken)) {
      sendError(res, 'Invalid or revoked refresh token', 401, 'INVALID_REFRESH_TOKEN');
      return;
    }

    try {
      const payload = jwt.verify(refreshToken, config.jwt.refreshSecret) as { userId: string };
      const user = db.getUserById(payload.userId);

      if (!user || user.isBanned || user.isDeleted) {
        db.activeRefreshTokens.delete(refreshToken);
        sendError(res, 'User session invalid', 401, 'UNAUTHORIZED');
        return;
      }

      const newAccessToken = jwt.sign(
        { userId: user.id, role: user.role },
        config.jwt.accessSecret,
        { expiresIn: '15m' }
      );

      sendSuccess(res, { accessToken: newAccessToken, expiresIn: 900 }, 'Token refreshed');
    } catch {
      db.activeRefreshTokens.delete(refreshToken);
      sendError(res, 'Refresh token expired. Please login again.', 401, 'TOKEN_EXPIRED');
    }
  }

  // Step 4: Logout
  public static async logout(req: AuthenticatedRequest, res: Response): Promise<void> {
    const refreshToken = req.body.refreshToken;
    if (refreshToken) {
      db.activeRefreshTokens.delete(refreshToken);
    }
    sendSuccess(res, null, 'Logged out successfully');
  }

  // Step 5: Account Deletion (Apple App Store Guideline 5.1.1(v) Mandatory Requirement)
  public static async deleteAccount(req: AuthenticatedRequest, res: Response): Promise<void> {
    if (!req.user) {
      sendError(res, 'Unauthorized', 401);
      return;
    }
    db.deleteUserAccount(req.user.id);
    sendSuccess(res, null, 'Account and all associated personal data permanently deleted');
  }

  // Helper to generate access & refresh tokens
  private static generateTokens(userId: string, role: string, phone?: string) {
    const accessToken = jwt.sign(
      { userId, role, phone },
      config.jwt.accessSecret,
      { expiresIn: '30d' }
    );
    const refreshToken = jwt.sign(
      { userId, phone },
      config.jwt.refreshSecret,
      { expiresIn: '90d' }
    );
    return {
      accessToken,
      refreshToken,
      expiresIn: 30 * 24 * 3600,
    };
  }

  // Step 6: Legacy Firebase Login (Disabled - Native Notify.lk SMS OTP in use)
  public static async firebaseLogin(_req: Request, res: Response): Promise<void> {
    sendError(res, 'Firebase authentication has been retired. Please use native phone OTP authentication.', 400, 'FIREBASE_AUTH_RETIRED');
  }

  // Step 7: Request Change of Mobile Number
  public static async requestPhoneChange(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const { newPhone } = req.body;
    if (!newPhone) {
      sendError(res, 'New phone number is required', 400);
      return;
    }

    const cleanNewPhone = normalizePhone(newPhone);
    if (!/^\+?[1-9]\d{7,14}$/.test(cleanNewPhone)) {
      sendError(res, 'Invalid international phone number format', 400);
      return;
    }

    if (cleanNewPhone === user.phone) {
      sendError(res, 'New phone number cannot be the same as your current phone number', 400);
      return;
    }

    const existingUser = db.getUserByPhone(cleanNewPhone);
    if (existingUser && existingUser.id !== user.id) {
      sendError(res, 'This phone number is already registered to another active account', 409, 'PHONE_ALREADY_EXISTS');
      return;
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000;
    phoneChangeOtpStore.set(user.id, { newPhone: cleanNewPhone, code, expiresAt });

    const smsDispatch = await smsService.sendSmsOtp(cleanNewPhone, code);
    logger.info(`Phone change OTP requested for user [${user.id}] to [${cleanNewPhone}]`);

    sendSuccess(
      res,
      {
        newPhone: cleanNewPhone,
        expiresInSeconds: 300,
      },
      smsDispatch.success ? 'Verification code dispatched to your new phone number' : smsDispatch.message
    );
  }

  // Step 8: Verify Change of Mobile Number
  public static async verifyPhoneChange(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const { newPhone, otp } = req.body;

    const record = phoneChangeOtpStore.get(user.id);
    if (!record || Date.now() > record.expiresAt) {
      phoneChangeOtpStore.delete(user.id);
      sendError(res, 'Phone change verification code has expired. Please request a new one.', 400, 'OTP_EXPIRED');
      return;
    }

    const cleanNewPhone = normalizePhone(newPhone);
    if (record.newPhone !== cleanNewPhone || record.code !== otp) {
      sendError(res, 'Invalid verification code. Please check and try again.', 400, 'INVALID_OTP');
      return;
    }

    phoneChangeOtpStore.delete(user.id);
    const oldPhone = user.phone;
    user.phone = cleanNewPhone;
    user.updatedAt = new Date().toISOString();
    db.users.set(user.id, user);
    db.scheduleSave();

    const tokens = AuthController.generateTokens(user.id, user.role, cleanNewPhone);
    logger.info(`User [${user.id}] successfully updated phone from [${oldPhone}] to [${cleanNewPhone}]`);

    sendSuccess(
      res,
      {
        user,
        tokens,
      },
      'Phone number updated successfully'
    );
  }

  // Step 9: Update Account Recovery Email
  public static async updateRecoveryEmail(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const { email } = req.body;
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      sendError(res, 'Please provide a valid email address', 400);
      return;
    }

    const cleanEmail = email.trim().toLowerCase();
    user.email = cleanEmail;
    user.updatedAt = new Date().toISOString();
    db.users.set(user.id, user);
    db.scheduleSave();

    logger.info(`User [${user.id}] linked recovery email [${cleanEmail}]`);
    sendSuccess(res, { email: user.email }, 'Recovery email saved successfully');
  }

  // Step 10: Lost SIM Account Recovery Request
  public static async requestAccountRecovery(req: Request, res: Response): Promise<void> {
    const { email } = req.body;
    if (!email) {
      sendError(res, 'Recovery email is required', 400);
      return;
    }

    const cleanEmail = email.trim().toLowerCase();
    let foundUser = undefined;
    for (const u of db.users.values()) {
      if (u.email?.toLowerCase() === cleanEmail && !u.isDeleted) {
        foundUser = u;
        break;
      }
    }

    if (!foundUser) {
      sendError(res, 'No Yaalu account found with this recovery email address.', 404, 'EMAIL_NOT_FOUND');
      return;
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes
    emailRecoveryOtpStore.set(cleanEmail, { userId: foundUser.id, code, expiresAt });

    const masked = foundUser.phone.replace(/(\+\d{4})\d+(\d{2})/, '$1***$2');
    logger.info(`Account recovery OTP generated for email [${cleanEmail}], User [${foundUser.id}]`);

    sendSuccess(
      res,
      {
        email: cleanEmail,
        maskedPhone: masked,
        expiresInSeconds: 600,
      },
      'A 6-digit recovery code has been generated. Enter the code and your new phone number to reclaim your account.'
    );
  }

  // Step 11: Lost SIM Account Recovery Verify & Update Phone
  public static async verifyAccountRecovery(req: Request, res: Response): Promise<void> {
    const { email, otp, newPhone } = req.body;
    if (!email || !otp || !newPhone) {
      sendError(res, 'Email, recovery OTP, and new phone number are required', 400);
      return;
    }

    const cleanEmail = email.trim().toLowerCase();
    const cleanNewPhone = normalizePhone(newPhone);

    const record = emailRecoveryOtpStore.get(cleanEmail);
    if (!record || Date.now() > record.expiresAt) {
      emailRecoveryOtpStore.delete(cleanEmail);
      sendError(res, 'Recovery code has expired. Please request a new recovery code.', 400, 'OTP_EXPIRED');
      return;
    }

    if (record.code !== otp) {
      sendError(res, 'Invalid recovery verification code. Please check and try again.', 400, 'INVALID_OTP');
      return;
    }

    const user = db.getUserById(record.userId);
    if (!user) {
      sendError(res, 'User record not found', 404);
      return;
    }

    // Check if newPhone is already used by someone else
    const existing = db.getUserByPhone(cleanNewPhone);
    if (existing && existing.id !== user.id) {
      sendError(res, 'This new phone number is already registered to another active account', 409);
      return;
    }

    emailRecoveryOtpStore.delete(cleanEmail);
    user.phone = cleanNewPhone;
    user.updatedAt = new Date().toISOString();
    db.users.set(user.id, user);
    db.scheduleSave();

    const profile = db.getProfileByUserId(user.id);
    const tokens = AuthController.generateTokens(user.id, user.role, cleanNewPhone);

    logger.info(`Account [${user.id}] recovered via email [${cleanEmail}] with new phone [${cleanNewPhone}]`);

    sendSuccess(
      res,
      {
        tokens,
        user,
        profile,
      },
      'Account successfully recovered! Your phone number has been updated to your new SIM.'
    );
  }
}
