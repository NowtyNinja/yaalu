import { Router } from 'express';
import {
  AuthController,
  requestOtpSchema,
  verifyOtpSchema,
  refreshTokenSchema,
} from '../controllers/authController';
import { validateSchema } from '../middlewares/validator';
import { authRateLimiter } from '../middlewares/rateLimiter';
import { authenticateJwt } from '../middlewares/authMiddleware';
import { noCacheHeaders } from '../middlewares/security';

const router = Router();

router.post(
  '/request-otp',
  authRateLimiter,
  noCacheHeaders,
  validateSchema(requestOtpSchema),
  AuthController.requestOtp
);

router.post(
  '/verify-otp',
  authRateLimiter,
  noCacheHeaders,
  validateSchema(verifyOtpSchema),
  AuthController.verifyOtp
);

router.post(
  '/refresh-token',
  authRateLimiter,
  validateSchema(refreshTokenSchema),
  AuthController.refreshToken
);

router.post('/logout', authenticateJwt, AuthController.logout);

// Firebase Client ID Token Authentication
router.post('/firebase-login', authRateLimiter, noCacheHeaders, AuthController.firebaseLogin);

// Mandatory for Apple App Store (Guideline 5.1.1(v)) and Google Play Data Safety
router.delete('/delete-account', authenticateJwt, AuthController.deleteAccount);

export default router;
