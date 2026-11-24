import { Request, Response } from 'express';
import crypto from 'crypto';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { config } from '../config';
import { db } from '../database/store';
import { sendSuccess, sendError } from '../utils/response';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';
import { SubscriptionTier, PaymentTransaction } from '../models/types';
import { logger } from '../utils/logger';

// Official Bank Account Details for VIP Transfers
export const BANK_DETAILS = {
  accountName: 'SELL PHONE TECH (PVT) LTD',
  accountNumber: '011013666444120',
  bankName: 'Seylan Bank',
  branch: 'Gampaha',
  whatsappSupport: '+94786799544',
  instructions: 'Transfer the subscription fee via Online Banking, CDM, or Bank Counter. Use your phone number as reference and send the slip to WhatsApp +94 78 679 9544.',
};

// VIP Tier Pricing Table
export const TIER_PRICING: Record<SubscriptionTier, { amountLkr: number; amountUsd: number; title: string }> = {
  free: { amountLkr: 0, amountUsd: 0, title: 'Free Tier' },
  vip_weekly: { amountLkr: 990, amountUsd: 2.99, title: 'Yaalu VIP (1 Week)' },
  vip_monthly: { amountLkr: 2490, amountUsd: 7.99, title: 'Yaalu VIP (1 Month)' },
  vip_3month: { amountLkr: 5990, amountUsd: 18.99, title: 'Yaalu VIP (3 Months)' },
  vip_annual: { amountLkr: 14990, amountUsd: 49.99, title: 'Yaalu VIP (1 Year)' },
};

// Initiate PayHere Payment Schema
export const initiatePaymentSchema = z.object({
  tier: z.enum(['vip_weekly', 'vip_monthly', 'vip_3month', 'vip_annual']),
});

// Apple / Google IAP Schema
export const verifyIapReceiptSchema = z.object({
  tier: z.enum(['vip_weekly', 'vip_monthly', 'vip_3month', 'vip_annual']),
  platform: z.enum(['apple', 'google']),
  receiptToken: z.string().min(10, 'Invalid receipt token'),
  productId: z.string(),
});

// Bank Transfer Schema
export const bankTransferSchema = z.object({
  tier: z.enum(['vip_weekly', 'vip_monthly', 'vip_3month', 'vip_annual']),
  bankName: z.string().min(2),
  referenceCode: z.string().min(2),
  slipNote: z.string().max(300).optional(),
});

export class PaymentController {
  // Get VIP Pricing Plans & Bank Details
  public static async getPlans(_req: Request, res: Response): Promise<void> {
    sendSuccess(res, { plans: TIER_PRICING, bankDetails: BANK_DETAILS, ...TIER_PRICING }, 'Subscription plans retrieved');
  }

  // Initiate PayHere Transaction (Currently Disabled per business policy)
  public static async initiatePayHere(_req: AuthenticatedRequest, res: Response): Promise<void> {
    sendError(res, 'PayHere is currently disabled. Please use Direct Bank Transfer to Seylan Bank.', 400, 'PAYHERE_DISABLED');
  }

  // PayHere IPN Webhook (Server-to-Server Instant Payment Notification)
  public static async payhereWebhook(req: Request, res: Response): Promise<void> {
    const {
      merchant_id,
      order_id,
      payhere_amount,
      payhere_currency,
      status_code,
      md5sig,
      custom_1: userId,
      custom_2: tier,
    } = req.body;

    const merchantSecret = config.payhere.secret;

    // Verify incoming signature against spoofing attacks
    const hashedSecret = crypto
      .createHash('md5')
      .update(merchantSecret)
      .digest('hex')
      .toUpperCase();

    const expectedHashString = `${merchant_id}${order_id}${payhere_amount}${payhere_currency}${status_code}${hashedSecret}`;
    const expectedSig = crypto
      .createHash('md5')
      .update(expectedHashString)
      .digest('hex')
      .toUpperCase();

    // Constant-time comparison to prevent timing attacks
    const isValidSignature =
      expectedSig.length === (md5sig || '').length &&
      crypto.timingSafeEqual(Buffer.from(expectedSig), Buffer.from(md5sig || ''));

    if (!isValidSignature) {
      logger.securityAlert('PAYHERE_INVALID_SIGNATURE_RECEIVED', {
        order_id,
        receivedSig: md5sig,
      });
      res.status(400).send('Invalid signature');
      return;
    }

    // Status 2 = Success in PayHere IPN
    if (status_code === '2' || status_code === 2) {
      if (userId && tier) {
        db.activateSubscription(
          userId,
          tier as SubscriptionTier,
          'payhere',
          parseFloat(payhere_amount),
          order_id
        );
        logger.info(`PayHere IPN processed: User [${userId}] upgraded to VIP [${tier}]`);
      }
    }

    res.status(200).send('OK');
  }

  // Apple & Google In-App Purchase Receipt Validation (Disabled temporarily per owner request)
  public static async verifyIapReceipt(_req: AuthenticatedRequest, res: Response): Promise<void> {
    sendError(res, 'In-App Purchase is currently disabled. Please use Bank Transfer via Seylan Bank.', 400);
  }

  // Bank Transfer Submission (Direct Bank Transfer with WhatsApp verification)
  public static async submitBankTransfer(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const { tier, bankName, referenceCode, slipNote } = req.body;

    const plan = TIER_PRICING[tier as SubscriptionTier];
    if (!plan) {
      sendError(res, 'Invalid subscription tier selected', 400);
      return;
    }

    const orderId = `BT_${Date.now()}_${uuidv4().substring(0, 6).toUpperCase()}`;
    const amount = plan.amountLkr;

    // Create a PENDING transaction requiring admin approval upon slip receipt
    const paymentId = uuidv4();
    const transaction: PaymentTransaction = {
      id: paymentId,
      userId: user.id,
      orderId,
      amount,
      currency: 'LKR',
      tier: tier as SubscriptionTier,
      provider: 'bank_transfer',
      status: 'pending',
      bankName: bankName || 'Seylan Bank',
      referenceCode: referenceCode,
      slipNote: slipNote || 'Deposit slip submitted for verification',
      createdAt: new Date().toISOString(),
    };

    db.payments.set(paymentId, transaction);
    db.scheduleSave();

    logger.info(
      `Bank transfer submitted (PENDING) for user [${user.id}], Bank: [${bankName}], Ref: [${referenceCode}], Order: [${orderId}]`
    );

    sendSuccess(
      res,
      transaction,
      'Bank transfer registered! Please ensure deposit slip is sent to WhatsApp +94 78 679 9544. VIP will be activated upon admin verification.'
    );
  }
}
