import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';
import {
  UserController,
  updateProfileSchema,
  setPassportLocationSchema,
  reportUserSchema,
  blockUserSchema,
  rateDateSchema,
} from '../controllers/userController';
import { authenticateJwt } from '../middlewares/authMiddleware';
import { validateSchema } from '../middlewares/validator';
import { reportRateLimiter } from '../middlewares/rateLimiter';

const router = Router();

// Multer Storage for Direct Device Photo Uploads
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    const dir = path.join(__dirname, '../../uploads/photos');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB per photo
  fileFilter: (_req, file, cb) => {
    const allowed = /jpeg|jpg|png|webp|heic/i;
    const isMime = allowed.test(file.mimetype);
    const isExt = allowed.test(path.extname(file.originalname).toLowerCase());
    if (isMime || isExt) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, WEBP, and HEIC images are allowed.'));
    }
  },
});

router.use(authenticateJwt);

// Direct Photo Upload (from Camera or Gallery)
router.post('/upload-photo', upload.single('photo'), UserController.uploadPhoto);

router.get('/search', UserController.searchUsers);
router.get('/me', UserController.getMyProfile);
router.patch('/me', validateSchema(updateProfileSchema), UserController.updateMyProfile);

// VIP Actions
router.post('/stealth-mode', UserController.toggleStealthMode);
router.post('/passport', validateSchema(setPassportLocationSchema), UserController.setPassportLocation);
router.post('/boost', UserController.boostProfile);

// Apple UGC Compliance: Report and Block
router.post('/report', reportRateLimiter, validateSchema(reportUserSchema), UserController.reportUser);
router.post('/block', validateSchema(blockUserSchema), UserController.blockUser);

// Date Rating & Safety Review
router.post('/rate-date', validateSchema(rateDateSchema), UserController.rateDate);
router.get('/:userId/ratings', UserController.getDateRatings);

export default router;
