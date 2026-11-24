import { Router } from 'express';
import { AdminController } from '../controllers/adminController';
import { authenticateJwt } from '../middlewares/authMiddleware';
import { requireAdmin } from '../middlewares/adminMiddleware';

const router = Router();

// Public: Admin Login
router.post('/login', AdminController.login);

// Protected: Admin only
router.use(authenticateJwt);
router.use(requireAdmin);

// Analytics & Dashboard KPIs
router.get('/stats', AdminController.getStats);

// User Management
router.get('/users', AdminController.getUsers);
router.patch('/users/:userId/verify', AdminController.toggleVerify);
router.patch('/users/:userId/ban', AdminController.toggleBan);
router.patch('/users/:userId/vip', AdminController.grantVip);
router.post('/purge-demo', AdminController.purgeDemoData);

// Moderation & UGC Safety Reports
router.get('/reports', AdminController.getReports);
router.delete('/reports/:reportId', AdminController.resolveReport);

// Payments & Bank Transfer Slip Approvals
router.get('/payments', AdminController.getPayments);
router.post('/payments/:paymentId/approve', AdminController.approvePayment);

// Staff Management
router.get('/staff', AdminController.getStaff);
router.post('/staff', AdminController.createStaff);
router.delete('/staff/:staffId', AdminController.removeStaff);

// Firebase & SMS Gateway Credentials Management
router.get('/firebase-config', AdminController.getFirebaseConfig);
router.post('/firebase-config', AdminController.updateFirebaseConfig);
router.post('/test-sms', AdminController.testSms);
router.get('/sms-logs', AdminController.getSmsLogs);

export default router;
