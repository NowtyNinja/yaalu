import { Router } from 'express';
import {
  VerificationController,
  submitVerificationSchema,
} from '../controllers/verificationController';
import { authenticateJwt } from '../middlewares/authMiddleware';
import { validateSchema } from '../middlewares/validator';

const router = Router();

router.use(authenticateJwt);

router.post(
  '/submit',
  validateSchema(submitVerificationSchema),
  VerificationController.submitVerification
);

router.get('/status', VerificationController.getStatus);

export default router;
