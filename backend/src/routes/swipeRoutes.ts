import { Router } from 'express';
import {
  SwipeController,
  recordSwipeSchema,
  discoveryQuerySchema,
} from '../controllers/swipeController';
import { authenticateJwt } from '../middlewares/authMiddleware';
import { validateSchema } from '../middlewares/validator';
import { swipeRateLimiter } from '../middlewares/rateLimiter';

const router = Router();

router.use(authenticateJwt);

router.get('/discovery', validateSchema(discoveryQuerySchema, 'query'), SwipeController.getDiscoveryStack);
router.post('/swipe', swipeRateLimiter, validateSchema(recordSwipeSchema), SwipeController.recordSwipe);
router.post('/rewind', SwipeController.rewind);
router.get('/who-liked-me', SwipeController.getWhoLikedYou);

export default router;
