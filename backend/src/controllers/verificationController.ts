import { Response } from 'express';
import { z } from 'zod';
import { db } from '../database/store';
import { sendSuccess, sendError } from '../utils/response';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';
import { logger } from '../utils/logger';

export const submitVerificationSchema = z.object({
  selfieUrl: z.string().min(1, 'Must provide a valid selfie URL'),
  livenessConfidence: z.number().min(0).max(100).optional().default(98.5),
});

export class VerificationController {
  // Submit AI Selfie Verification
  public static async submitVerification(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const profile = db.getProfileByUserId(user.id);
    const { selfieUrl, livenessConfidence } = req.body;

    if (!profile) {
      sendError(res, 'Profile not found', 404);
      return;
    }

    if (profile.photos.length === 0) {
      sendError(res, 'Please upload at least one profile photo before verifying', 400);
      return;
    }

    // In production: AWS Rekognition CompareFaces API
    // Compares live selfie against primary profile photo
    logger.info(`AI Face Verification check for user [${user.id}], Confidence: [${livenessConfidence}%]`);

    if (livenessConfidence >= 80) {
      profile.verificationStatus = 'verified';
      profile.verificationSelfieUrl = selfieUrl;
      db.updateProfile(user.id, {
        verificationStatus: 'verified',
        verificationSelfieUrl: selfieUrl,
      });

      sendSuccess(
        res,
        { verificationStatus: 'verified', livenessScore: livenessConfidence },
        'Congratulations! Your profile has been verified with the Yaalu Blue Badge. ✨'
      );
    } else {
      profile.verificationStatus = 'rejected';
      db.updateProfile(user.id, { verificationStatus: 'rejected' });
      sendError(
        res,
        'Face match or liveness check confidence was below the required threshold. Please retry with proper lighting.',
        422,
        'VERIFICATION_FAILED'
      );
    }
  }

  // Get Verification Status
  public static async getStatus(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const profile = db.getProfileByUserId(user.id);

    sendSuccess(
      res,
      {
        status: profile?.verificationStatus || 'unverified',
      },
      'Verification status retrieved'
    );
  }
}
