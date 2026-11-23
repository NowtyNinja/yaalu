import { Router } from 'express';
import {
  PaymentController,
  initiatePaymentSchema,
  verifyIapReceiptSchema,
  bankTransferSchema,
} from '../controllers/paymentController';
import { authenticateJwt } from '../middlewares/authMiddleware';
import { validateSchema } from '../middlewares/validator';

const router = Router();

// Public Pricing List
router.get('/plans', PaymentController.getPlans);

// PayHere Webhook (Called by PayHere gateway server, no client JWT header)
router.post('/payhere/notify', PaymentController.payhereWebhook);

// Protected Payment Endpoints
router.post(
  '/payhere/initiate',
  authenticateJwt,
  validateSchema(initiatePaymentSchema),
  PaymentController.initiatePayHere
);

router.post(
  '/iap/verify',
  authenticateJwt,
  validateSchema(verifyIapReceiptSchema),
  PaymentController.verifyIapReceipt
);

router.post(
  '/bank-transfer',
  authenticateJwt,
  validateSchema(bankTransferSchema),
  PaymentController.submitBankTransfer
);

export default router;
