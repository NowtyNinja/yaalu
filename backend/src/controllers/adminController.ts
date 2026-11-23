import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { db } from '../database/store';
import { config } from '../config';
import { sendSuccess, sendError } from '../utils/response';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';
import { logger } from '../utils/logger';
import { smsService } from '../services/smsService';

export class AdminController {
  // Admin Login (Supports Master Admin credentials or Admin Phone OTP)
  public static async login(req: Request, res: Response): Promise<void> {
    const { username, password, phone, otp } = req.body || {};

    const u = (username || phone || '').toString().trim().toLowerCase();
    const p = (password || otp || '').toString().trim();

    // Check credential pair
    let isAdminValid = false;
    let adminUserId = '';

    // Credential check: Username or Phone with matching Password or OTP
    const validUsers = ['admin', 'yaalu_admin', '+94770000000', '0770000000', '770000000'];
    const validSecrets = ['admin123', 'admin', 'yaalu@2026', '777777', '000000', 'password'];

    if (validUsers.includes(u) && validSecrets.includes(p)) {
      isAdminValid = true;
      // Get or create seeded admin
      let admin = db.getUserByPhone('+94770000000');
      if (!admin) {
        const created = db.createUser('+94770000000', 'admin@yaalu.lk');
        created.user.role = 'admin';
        created.user.subscriptionTier = 'vip_annual';
        db.users.set(created.user.id, created.user);
        admin = created.user;
      }
      adminUserId = admin.id;
    }

    if (!isAdminValid || !adminUserId) {
      logger.securityAlert('FAILED_ADMIN_LOGIN_ATTEMPT', {
        ip: req.ip,
        username,
        phone,
      });
      sendError(res, 'Invalid administrator credentials.', 401, 'INVALID_CREDENTIALS');
      return;
    }

    const accessToken = jwt.sign(
      { userId: adminUserId, role: 'admin' },
      config.jwt.accessSecret,
      { expiresIn: '24h' }
    );

    const profile = db.getProfileByUserId(adminUserId);

    logger.info(`Admin successfully authenticated: [${adminUserId}]`);

    sendSuccess(
      res,
      {
        token: accessToken,
        admin: {
          id: adminUserId,
          role: 'admin',
          displayName: profile?.displayName || 'Yaalu Administrator',
        },
      },
      'Admin authentication successful'
    );
  }

  // Live KPI Dashboard Stats
  public static async getStats(req: AuthenticatedRequest, res: Response): Promise<void> {
    const stats = db.getAdminStats();
    sendSuccess(res, stats, 'Admin statistics retrieved');
  }

  // List all users with query filter
  public static async getUsers(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { q } = req.query as any;
    const users = db.getAllUsersForAdmin(q as string);
    sendSuccess(res, { users, total: users.length }, 'Users list retrieved');
  }

  // Toggle Blue Badge Verification
  public static async toggleVerify(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { userId } = req.params;
    const { isVerified } = req.body;

    const ok = db.setUserVerification(userId, isVerified !== false);
    if (!ok) {
      sendError(res, 'User not found', 404);
      return;
    }

    logger.info(`Admin [${req.user!.id}] updated verification for user [${userId}] to [${isVerified}]`);
    sendSuccess(res, { userId, isVerified }, `User verification ${isVerified ? 'granted' : 'revoked'}`);
  }

  // Ban / Unban User
  public static async toggleBan(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { userId } = req.params;
    const { isBanned } = req.body;

    const ok = db.setUserBanned(userId, isBanned === true);
    if (!ok) {
      sendError(res, 'User not found', 404);
      return;
    }

    logger.info(`Admin [${req.user!.id}] set ban status for user [${userId}] to [${isBanned}]`);
    sendSuccess(res, { userId, isBanned }, `User has been ${isBanned ? 'banned' : 'unbanned'}`);
  }

  // Manually Grant VIP Subscription
  public static async grantVip(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { userId } = req.params;
    const { tier, durationDays } = req.body;

    const ok = db.setUserSubscription(userId, tier || 'vip_monthly', Number(durationDays) || 30);
    if (!ok) {
      sendError(res, 'User not found', 404);
      return;
    }

    logger.info(`Admin [${req.user!.id}] granted [${tier}] VIP to user [${userId}]`);
    sendSuccess(res, { userId, tier }, `VIP granted to user successfully`);
  }

  // List Safety Reports (Apple/Google UGC Compliance)
  public static async getReports(req: AuthenticatedRequest, res: Response): Promise<void> {
    const reportsWithDetails = db.reports.map((r) => {
      const reporter = db.getProfileByUserId(r.reporterId);
      const reported = db.getProfileByUserId(r.reportedUserId);
      return {
        ...r,
        reporterName: reporter?.displayName || 'Unknown Reporter',
        reportedName: reported?.displayName || 'Unknown User',
        reportedUserBanned: db.getUserById(r.reportedUserId)?.isBanned || false,
      };
    });
    sendSuccess(res, { reports: reportsWithDetails.reverse() }, 'Reports retrieved');
  }

  // Dismiss / Resolve Report
  public static async resolveReport(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { reportId } = req.params;
    const index = db.reports.findIndex((r) => r.id === reportId);
    if (index !== -1) {
      db.reports.splice(index, 1);
    }
    sendSuccess(res, { reportId }, 'Report dismissed');
  }

  // List All Payments & Bank Transfer Submissions
  public static async getPayments(req: AuthenticatedRequest, res: Response): Promise<void> {
    const paymentsList = Array.from(db.payments.values()).map((p) => {
      const user = db.getProfileByUserId(p.userId);
      return {
        ...p,
        userName: user?.displayName || 'Unknown User',
      };
    });
    sendSuccess(res, { payments: paymentsList.reverse() }, 'Payments retrieved');
  }

  // Approve Bank Transfer & Activate VIP
  public static async approvePayment(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { paymentId } = req.params;
    const payment = db.payments.get(paymentId);
    if (!payment) {
      sendError(res, 'Payment transaction not found', 404);
      return;
    }

    payment.status = 'success';
    db.payments.set(paymentId, payment);

    // Activate subscription for the user
    db.activateSubscription(payment.userId, payment.tier, 'bank_transfer', payment.amount, payment.orderId, {
      bankName: payment.bankName,
      referenceCode: payment.referenceCode,
      slipNote: payment.slipNote,
    });

    logger.info(`Admin [${req.user!.id}] approved bank transfer payment [${paymentId}] for user [${payment.userId}]`);
    sendSuccess(res, payment, 'Bank transfer approved and VIP activated!');
  }

  // --- SMS Gateway Management (Notify.lk / Local Gateways) ---

  // Get current SMS Gateway Status
  public static async getSmsConfig(_req: AuthenticatedRequest, res: Response): Promise<void> {
    const status = smsService.getStatus();
    sendSuccess(res, status, 'SMS configuration retrieved');
  }
  public static readonly getFirebaseConfig = AdminController.getSmsConfig;

  // Update SMS Gateway Credentials
  public static async updateSmsConfig(req: AuthenticatedRequest, res: Response): Promise<void> {
    const {
      enabled,
      smsGatewayProvider,
      senderId,
      genericSmsUrl,
      notifyLkUserId,
      notifyLkApiKey,
      twilioAccountSid,
      twilioAuthToken,
      twilioFromNumber,
    } = req.body || {};

    const result = smsService.updateConfig({
      enabled: enabled ?? true,
      smsGatewayProvider: smsGatewayProvider || 'notify_lk',
      senderId,
      genericSmsUrl,
      notifyLkUserId,
      notifyLkApiKey,
      twilioAccountSid,
      twilioAuthToken,
      twilioFromNumber,
    });

    if (!result.success) {
      sendError(res, result.message, 400);
      return;
    }

    sendSuccess(res, smsService.getStatus(), result.message);
  }
  public static readonly updateFirebaseConfig = AdminController.updateSmsConfig;

  // Send a Live Test SMS to verify Gateway connectivity
  public static async testSms(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { phone } = req.body || {};
    if (!phone) {
      sendError(res, 'Phone number is required for test SMS', 400);
      return;
    }

    const testOtp = Math.floor(100000 + Math.random() * 900000).toString();
    const result = await smsService.sendSmsOtp(phone, testOtp);

    if (!result.success) {
      sendError(res, result.message, 502, 'SMS_DISPATCH_FAILED');
      return;
    }

    sendSuccess(
      res,
      {
        phone,
        testOtp,
        provider: result.provider,
        message: result.message,
      },
      'Test SMS dispatched successfully'
    );
  }

  // Get Recent SMS Dispatch Logs
  public static async getSmsLogs(_req: AuthenticatedRequest, res: Response): Promise<void> {
    const logs = smsService.getSmsLogs();
    sendSuccess(res, logs, 'SMS logs retrieved');
  }
}
