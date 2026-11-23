import rateLimit from 'express-rate-limit';
import { Request, Response } from 'express';
import { config } from '../config';
import { logger } from '../utils/logger';

// Standard rate limit handler
const standardHandler = (type: string) => (req: Request, res: Response) => {
  logger.securityAlert('RATE_LIMIT_EXCEEDED', {
    type,
    ip: req.ip,
    path: req.originalUrl,
  });
  return res.status(429).json({
    success: false,
    message: 'Too many requests. Please slow down and try again later.',
    errorCode: 'RATE_LIMIT_EXCEEDED',
    timestamp: new Date().toISOString(),
  });
};

// 1. Global API Rate Limiter
export const globalRateLimiter = rateLimit({
  windowMs: config.rateLimit.windowMs, // 15 mins
  max: config.rateLimit.maxRequests, // 200 requests / 15 mins
  standardHeaders: true,
  legacyHeaders: false,
  handler: standardHandler('GLOBAL'),
});

// 2. Auth & OTP Rate Limiter (Prevent SMS bombing & PIN brute force)
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 mins
  max: config.rateLimit.authMax, // 10 attempts
  standardHeaders: true,
  legacyHeaders: false,
  handler: standardHandler('AUTH_BRUTE_FORCE_PROTECTION'),
});

// 3. Swipe Engine Anti-Bot Limiter (Prevent automated scraping/swiping)
export const swipeRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 30, // max 30 swipes per minute
  standardHeaders: true,
  legacyHeaders: false,
  handler: standardHandler('SWIPE_BOT_DETECTION'),
});

// 4. Report & Moderation Rate Limiter
export const reportRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // max 5 reports per hour
  standardHeaders: true,
  legacyHeaders: false,
  handler: standardHandler('SPAM_REPORTING_PREVENTION'),
});
