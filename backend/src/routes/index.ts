import { Router } from 'express';
import authRoutes from './authRoutes';
import userRoutes from './userRoutes';
import swipeRoutes from './swipeRoutes';
import chatRoutes from './chatRoutes';
import paymentRoutes from './paymentRoutes';
import verificationRoutes from './verificationRoutes';
import adminRoutes from './adminRoutes';

const router = Router();

// Root API Explorer
router.get('/', (_req, res) => {
  res.status(200).json({
    success: true,
    message: 'Welcome to Yaalu Dating & Social Discovery API (v1) 🇱🇰',
    version: '1.0.0',
    documentation: 'https://github.com/yaalu-dating/api-docs',
    security: {
      zeroTrust: true,
      sqlInjectionProtected: true,
      xssProtected: true,
      rateLimited: true,
    },
    availableRoutes: {
      health: 'GET /api/v1/health',
      auth: {
        requestOtp: 'POST /api/v1/auth/request-otp',
        verifyOtp: 'POST /api/v1/auth/verify-otp',
        refreshToken: 'POST /api/v1/auth/refresh-token',
        logout: 'POST /api/v1/auth/logout',
        deleteAccount: 'DELETE /api/v1/auth/delete-account',
      },
      users: {
        myProfile: 'GET /api/v1/users/me',
        updateProfile: 'PATCH /api/v1/users/me',
        stealthMode: 'POST /api/v1/users/stealth-mode',
        passport: 'POST /api/v1/users/passport',
        boost: 'POST /api/v1/users/boost',
        report: 'POST /api/v1/users/report',
        block: 'POST /api/v1/users/block',
      },
      discovery: {
        deck: 'GET /api/v1/swipes/discovery',
        swipe: 'POST /api/v1/swipes/swipe',
        rewind: 'POST /api/v1/swipes/rewind',
        whoLikedMe: 'GET /api/v1/swipes/who-liked-me',
      },
      chat: {
        matches: 'GET /api/v1/chat/matches',
        matchMessages: 'GET /api/v1/chat/matches/:matchId/messages',
        sendMessage: 'POST /api/v1/chat/messages',
        toggleBlur: 'POST /api/v1/chat/messages/:messageId/toggle-blur',
      },
      payments: {
        plans: 'GET /api/v1/payments/plans',
        payhereInitiate: 'POST /api/v1/payments/payhere/initiate',
        iapVerify: 'POST /api/v1/payments/iap/verify',
      },
      verification: {
        submitAiSelfie: 'POST /api/v1/verification/submit',
        status: 'GET /api/v1/verification/status',
      },
    },
    timestamp: new Date().toISOString(),
  });
});

// Health Check Endpoint
router.get('/health', (_req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'Yaalu Dating App API',
    version: '1.0.0',
    security: {
      zeroTrust: true,
      sqlInjectionProtected: true,
      xssProtected: true,
      rateLimited: true,
    },
  });
});

router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/swipes', swipeRoutes);
router.use('/chat', chatRoutes);
router.use('/payments', paymentRoutes);
router.use('/verification', verificationRoutes);
router.use('/admin', adminRoutes);

export default router;
