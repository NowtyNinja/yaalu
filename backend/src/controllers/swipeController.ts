import { Response } from 'express';
import { z } from 'zod';
import { db } from '../database/store';
import { sendSuccess, sendError } from '../utils/response';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';
import { logger } from '../utils/logger';

// Record Swipe Schema
export const recordSwipeSchema = z.object({
  targetUserId: z.string().uuid('Invalid user ID format'),
  action: z.enum(['left', 'right', 'superlike']),
  superLikeMessage: z.string().max(140, 'Intro message maximum 140 characters').optional(),
});

// Discovery Query Schema
export const discoveryQuerySchema = z.object({
  distance: z.coerce.number().min(1).max(500).optional().default(50),
  minAge: z.coerce.number().min(18).max(99).optional().default(18),
  maxAge: z.coerce.number().min(18).max(99).optional().default(50),
});

export class SwipeController {
  // Get Discovery Profile Deck
  public static async getDiscoveryStack(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const { distance, minAge, maxAge } = req.query as any;

    const profiles = db.getDiscoveryProfiles(
      user.id,
      Number(distance) || 50,
      Number(minAge) || 18,
      Number(maxAge) || 50
    );

    sendSuccess(
      res,
      {
        profiles,
        remainingSwipesToday: 'unlimited',
        superLikesRemaining: user.superLikesRemaining,
        isVip: user.subscriptionTier !== 'free',
      },
      'Discovery stack retrieved'
    );
  }

  // Record Swipe Action (Left / Right / Superlike)
  public static async recordSwipe(req: AuthenticatedRequest, res: Response): Promise<void> {
    const fromUserId = req.user!.id;
    const { targetUserId, action, superLikeMessage } = req.body;

    if (fromUserId === targetUserId) {
      sendError(res, 'Cannot swipe on your own profile', 400);
      return;
    }

    try {
      const result = db.recordSwipe(fromUserId, targetUserId, action, superLikeMessage);

      // If it's a match, get counterpart profile for celebration modal
      let matchedProfile = undefined;
      if (result.isMatch) {
        matchedProfile = db.getProfileByUserId(targetUserId);
      }

      sendSuccess(
        res,
        {
          isMatch: result.isMatch,
          match: result.match,
          matchedProfile,
          remainingSwipesToday: 'unlimited',
        },
        result.isMatch ? "It's a Match! 🎉" : 'Swipe recorded successfully'
      );
    } catch (err: any) {
      if (err.message === 'SWIPE_LIMIT_EXCEEDED') {
        sendError(
          res,
          'You have reached your daily swipe limit (15 swipes/day). Upgrade to Yaalu VIP for unlimited swipes!',
          429,
          'SWIPE_LIMIT_REACHED'
        );
        return;
      }
      if (err.message === 'NO_SUPER_LIKES_REMAINING') {
        sendError(
          res,
          'You have no Super Likes remaining. Upgrade to VIP or wait for weekly refresh.',
          403,
          'NO_SUPER_LIKES'
        );
        return;
      }
      logger.error('Error recording swipe:', err);
      sendError(res, err.message, 400);
    }
  }

  // Rewind Last Swipe (VIP Only)
  public static async rewind(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;

    try {
      const rewoundSwipe = db.rewindLastSwipe(userId);
      if (!rewoundSwipe) {
        sendError(res, 'No previous swipe found to rewind', 400, 'NO_SWIPE_TO_REWIND');
        return;
      }

      sendSuccess(res, rewoundSwipe, 'Previous swipe rewound successfully');
    } catch (err: any) {
      if (err.message === 'VIP_REQUIRED_FOR_REWIND') {
        sendError(res, 'Rewind is a premium feature available to Yaalu VIP subscribers.', 403, 'VIP_REQUIRED');
        return;
      }
      sendError(res, err.message, 400);
    }
  }

  // See Who Liked You (VIP Only)
  public static async getWhoLikedYou(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;

    try {
      const profiles = db.getWhoLikedUser(userId);
      sendSuccess(res, { count: profiles.length, profiles }, 'Profiles that liked you retrieved');
    } catch (err: any) {
      if (err.message === 'VIP_REQUIRED_SEE_LIKES') {
        sendError(
          res,
          'Seeing who liked you requires a Yaalu VIP subscription (Free for female members).',
          403,
          'VIP_REQUIRED'
        );
        return;
      }
      sendError(res, err.message, 400);
    }
  }
}
