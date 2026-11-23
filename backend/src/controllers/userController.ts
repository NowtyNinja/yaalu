import { Response } from 'express';
import { z } from 'zod';
import { db } from '../database/store';
import { sendSuccess, sendError } from '../utils/response';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';
import { logger } from '../utils/logger';

// Update Profile Schema
export const updateProfileSchema = z.object({
  displayName: z.string().min(2, 'Name must be at least 2 characters').max(50).optional(),
  bio: z.string().max(500, 'Bio maximum 500 characters').optional(),
  birthDate: z.string().optional(),
  age: z.number().int().min(18, 'Must be at least 18 years old').max(100).optional(),
  gender: z.enum(['male', 'female', 'non-binary', 'other']).optional(),
  interestedIn: z.array(z.enum(['male', 'female', 'non-binary', 'other'])).optional(),
  datingIntention: z.enum(['casual', 'dating', 'coffee', 'serious', 'friendship', 'travel']).optional(),
  interests: z.array(z.string().max(30)).max(10).optional(),
  homeDistrict: z.string().max(50).optional(),
  photos: z.array(z.string().min(1)).max(6).optional(),
  occupation: z.string().max(100).optional(),
  education: z.string().max(100).optional(),
});

// Passport Location Schema
export const setPassportLocationSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  city: z.string().min(1).max(100),
  country: z.string().min(1).max(100),
});

// Report User Schema
export const reportUserSchema = z.object({
  reportedUserId: z.string().uuid(),
  reason: z.enum(['inappropriate_photos', 'fake_profile', 'harassment', 'spam', 'underage', 'other']),
  description: z.string().max(500).optional(),
});

// Block User Schema
export const blockUserSchema = z.object({
  targetUserId: z.string().uuid(),
});

// Date Rating Schema
export const rateDateSchema = z.object({
  targetUserId: z.string().min(1),
  stars: z.number().int().min(1).max(5),
  tags: z.array(z.string()).optional(),
  review: z.string().max(500).optional(),
});

export class UserController {
  // Search Users
  public static async searchUsers(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const { q, district, interest, gender, verifiedOnly, minAge, maxAge } = req.query as any;

    const profiles = db.searchProfiles(user.id, {
      query: q as string,
      district: district as string,
      interest: interest as string,
      gender: gender as string,
      verifiedOnly: verifiedOnly === 'true' || verifiedOnly === true,
      minAge: minAge ? Number(minAge) : undefined,
      maxAge: maxAge ? Number(maxAge) : undefined,
    });

    sendSuccess(res, { profiles, count: profiles.length }, 'Users search results retrieved');
  }

  // Get Current User Profile
  public static async getMyProfile(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const profile = db.getProfileByUserId(user.id);

    if (!profile) {
      sendError(res, 'Profile not found', 404);
      return;
    }

    sendSuccess(res, { user, profile }, 'Profile retrieved');
  }

  // Update Profile
  public static async updateMyProfile(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    const updates = req.body;

    // Automatically calculate age from birthDate if provided
    if (updates.birthDate) {
      const b = new Date(updates.birthDate);
      if (!isNaN(b.getTime())) {
        const now = new Date();
        let calculatedAge = now.getFullYear() - b.getFullYear();
        if (
          now.getMonth() < b.getMonth() ||
          (now.getMonth() === b.getMonth() && now.getDate() < b.getDate())
        ) {
          calculatedAge--;
        }
        if (calculatedAge < 18) {
          sendError(res, 'You must be at least 18 years old to use Yaalu.', 400, 'UNDERAGE_FORBIDDEN');
          return;
        }
        updates.age = calculatedAge;
      }
    }

    const updatedProfile = db.updateProfile(user.id, updates);
    if (!updatedProfile) {
      sendError(res, 'Profile not found', 404);
      return;
    }

    sendSuccess(res, updatedProfile, 'Profile updated successfully');
  }

  // Toggle Stealth Mode (VIP Feature)
  public static async toggleStealthMode(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    if (user.subscriptionTier === 'free') {
      sendError(res, 'Stealth mode is exclusive to Yaalu VIP subscribers.', 403, 'VIP_REQUIRED');
      return;
    }

    const profile = db.getProfileByUserId(user.id);
    if (!profile) {
      sendError(res, 'Profile not found', 404);
      return;
    }

    profile.isStealthMode = !profile.isStealthMode;
    db.updateProfile(user.id, { isStealthMode: profile.isStealthMode });

    sendSuccess(
      res,
      { isStealthMode: profile.isStealthMode },
      `Stealth mode ${profile.isStealthMode ? 'enabled' : 'disabled'}`
    );
  }

  // Set Yaalu Passport Coordinates (VIP Feature)
  public static async setPassportLocation(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    if (user.subscriptionTier === 'free') {
      sendError(res, 'Yaalu Passport is exclusive to Yaalu VIP subscribers.', 403, 'VIP_REQUIRED');
      return;
    }

    const { latitude, longitude, city, country } = req.body;

    const profile = db.getProfileByUserId(user.id);
    if (!profile) {
      sendError(res, 'Profile not found', 404);
      return;
    }

    profile.location = {
      latitude,
      longitude,
      city,
      country,
      isPassportActive: true,
    };

    db.updateProfile(user.id, { location: profile.location });
    logger.info(`User [${user.id}] teleported location to [${city}, ${country}]`);

    sendSuccess(res, profile.location, `Location updated to ${city}, ${country}`);
  }

  // Profile Boost (Paid Feature for Everyone - Selected duration stack boost)
  public static async boostProfile(req: AuthenticatedRequest, res: Response): Promise<void> {
    const user = req.user!;
    if (user.subscriptionTier === 'free') {
      sendError(res, 'Profile Boost is a paid feature exclusive to Yaalu VIP subscribers.', 403, 'VIP_REQUIRED');
      return;
    }

    // User-selected boost duration (e.g. 30, 60, 120, 360, 1440 minutes, default 60)
    const durationMinutes = Math.min(1440, Math.max(15, Number(req.body.durationMinutes) || 60));
    const boostExpiration = new Date(Date.now() + durationMinutes * 60 * 1000).toISOString();
    const updated = db.updateProfile(user.id, { boostedUntil: boostExpiration });

    const timeLabel = durationMinutes < 60
      ? `${durationMinutes} minutes`
      : `${(durationMinutes / 60).toFixed(1).replace('.0', '')} hour(s)`;

    sendSuccess(
      res,
      { boostedUntil: boostExpiration, durationMinutes },
      `Profile boosted to top stack for ${timeLabel}!`
    );
  }

  // Report User (Apple App Store Guideline 1.2 requirement)
  public static async reportUser(req: AuthenticatedRequest, res: Response): Promise<void> {
    const reporterId = req.user!.id;
    const { reportedUserId, reason, description } = req.body;

    if (reporterId === reportedUserId) {
      sendError(res, 'Cannot report yourself', 400);
      return;
    }

    const report = db.createReport(reporterId, reportedUserId, reason, description);
    sendSuccess(res, report, 'Report submitted. Our moderation team reviews all reports within 24 hours.');
  }

  // Block User (Apple App Store Guideline 1.2 requirement)
  public static async blockUser(req: AuthenticatedRequest, res: Response): Promise<void> {
    const currentUserId = req.user!.id;
    const { targetUserId } = req.body;

    if (currentUserId === targetUserId) {
      sendError(res, 'Cannot block yourself', 400);
      return;
    }

    db.blockUser(currentUserId, targetUserId);
    sendSuccess(res, null, 'User blocked successfully. You will no longer see each other.');
  }

  // Rate Date & Safety Review
  public static async rateDate(req: AuthenticatedRequest, res: Response): Promise<void> {
    const fromUserId = req.user!.id;
    const { targetUserId, stars, tags, review } = req.body;

    if (fromUserId === targetUserId) {
      sendError(res, 'Cannot rate yourself', 400);
      return;
    }

    const targetUser = db.getUserById(targetUserId);
    if (!targetUser) {
      sendError(res, 'Target user not found', 404);
      return;
    }

    const rating = db.addDateRating(fromUserId, targetUserId, stars, tags || [], review);
    const summary = db.getDateRatingSummary(targetUserId);

    sendSuccess(
      res,
      { rating, summary },
      'Thank you for rating your date! Your feedback keeps Yaalu safe and verified.'
    );
  }

  // Get Date Ratings and Safety Summary
  public static async getDateRatings(req: AuthenticatedRequest, res: Response): Promise<void> {
    const { userId } = req.params;
    const summary = db.getDateRatingSummary(userId);
    sendSuccess(res, summary, 'Ratings retrieved');
  }

  // Upload Photo directly from device
  public static async uploadPhoto(req: AuthenticatedRequest, res: Response): Promise<void> {
    if (!req.file) {
      sendError(res, 'No photo file provided.', 400, 'NO_FILE_UPLOADED');
      return;
    }

    const host = req.get('host') || '127.0.0.1:5000';
    const protocol = req.protocol === 'https' ? 'https' : 'http';
    const photoUrl = `${protocol}://${host}/uploads/photos/${req.file.filename}`;

    logger.info(`User [${req.user!.id}] uploaded photo: ${photoUrl}`);

    sendSuccess(
      res,
      {
        photoUrl,
        filename: req.file.filename,
        size: req.file.size,
        mimetype: req.file.mimetype,
      },
      'Photo uploaded successfully'
    );
  }
}
