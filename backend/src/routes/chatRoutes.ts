import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';
import {
  ChatController,
  sendMessageSchema,
} from '../controllers/chatController';
import { authenticateJwt } from '../middlewares/authMiddleware';
import { validateSchema } from '../middlewares/validator';

const router = Router();

// Multer Storage for Voice Note Audio Uploads
const audioStorage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    const dir = path.join(__dirname, '../../uploads/audio');
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || '.m4a';
    cb(null, `voice_${uuidv4()}${ext}`);
  },
});

const uploadAudio = multer({
  storage: audioStorage,
  limits: { fileSize: 15 * 1024 * 1024 }, // 15MB limit
});

router.use(authenticateJwt);

router.get('/matches', ChatController.getMatches);
router.get('/matches/:matchId/messages', ChatController.getMessages);
router.post('/messages', validateSchema(sendMessageSchema), ChatController.sendMessage);
router.post('/upload-voice', uploadAudio.single('voice'), ChatController.uploadVoice);
router.post('/messages/:messageId/toggle-blur', ChatController.toggleBlur);

export default router;
