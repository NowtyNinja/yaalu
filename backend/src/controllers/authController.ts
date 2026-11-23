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

    // Fixed 123456 for Google Play reviewers / test accounts, random 6 digits for live users
    const code = isTestNumber
      ? '123456'
      : isLiveSms
      ? Math.floor(100000 + Math.random() * 900000).toString()
      : '777777';

    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes validity

    otpStore.set(phone, { code, expiresAt, attempts: 0 });

    logger.info(`OTP generated for phone: [${phone}] (Code: ${isTestNumber ? 'TEST_123456' : isLiveSms ? '***' : code})`);

    // Dispatch SMS via Notify.lk / Gateway (skip SMS for test numbers)
    const smsDispatch = isTestNumber
      ? { success: true, message: 'Google Play review test account bypass (Code: 123456)', provider: 'test_bypass' }
      : await smsService.sendSmsOtp(phone, code);

    // Provide mockOtpHint if not live OR if live dispatch failed, so user is never locked out
    const provideHint = !isLiveSms || !smsDispatch.success;

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

    const record = otpStore.get(phone);
    if (!record) {
      sendError(res, 'No OTP requested for this phone number or it has expired.', 400, 'OTP_EXPIRED');
      return;
    }

    if (Date.now() > record.expiresAt) {
      otpStore.delete(phone);
      sendError(res, 'Verification code has expired. Please request a new one.', 400, 'OTP_EXPIRED');
      return;
    }

    if (record.attempts >= 3) {
      otpStore.delete(phone);
      logger.securityAlert('OTP_BRUTE_FORCE_BLOCKED', { phone, ip: req.ip });
      sendError(res, 'Too many incorrect attempts. Request a new OTP.', 429, 'MAX_ATTEMPTS_EXCEEDED');
      return;
    }

    if (record.code !== otp) {
      record.attempts += 1;
      sendError(res, 'Invalid verification code. Please check and try again.', 400, 'INVALID_OTP');
      return;
    }

    // OTP is valid - consume it immediately
    otpStore.delete(phone);

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

    // Generate JWT Access & Refresh Tokens
    const accessToken = jwt.sign(
      { userId: user.id, role: user.role },
      config.jwt.accessSecret,
      { expiresIn: '15m' }
    );

    const refreshToken = jwt.sign(
      { userId: user.id },
      config.jwt.refreshSecret,
      { expiresIn: '7d' }
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
  private static generateTokens(userId: string, role: string) {
    const accessToken = jwt.sign(
      { userId, role },
      config.jwt.accessSecret,
      { expiresIn: '15m' }
    );
    const refreshToken = jwt.sign(
      { userId },
      config.jwt.refreshSecret,
      { expiresIn: '7d' }
    );
    return {
      accessToken,
      refreshToken,
      expiresIn: 900,
    };
  }

  // Step 6: Legacy Firebase Login (Disabled - Native Notify.lk SMS OTP in use)
  public static async firebaseLogin(_req: Request, res: Response): Promise<void> {
    sendError(res, 'Firebase authentication has been retired. Please use native phone OTP authentication.', 400, 'FIREBASE_AUTH_RETIRED');
  }
}
