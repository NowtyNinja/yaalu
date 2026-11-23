import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { db } from '../database/store';
import { sendError } from '../utils/response';
import { logger } from '../utils/logger';
import { User } from '../models/types';

export interface AuthenticatedRequest extends Request {
  user?: User;
}

export function authenticateJwt(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    sendError(res, 'Authentication token missing or invalid format', 401, 'UNAUTHORIZED');
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload = jwt.verify(token, config.jwt.accessSecret) as {
      userId: string;
      role: string;
    };

    const user = db.getUserById(payload.userId);

    if (!user) {
      sendError(res, 'User account no longer exists', 401, 'USER_NOT_FOUND');
      return;
    }

    if (user.isBanned) {
      logger.securityAlert('BANNED_USER_ACCESS_ATTEMPT', { userId: user.id });
      sendError(res, 'Account has been suspended for terms violation', 403, 'ACCOUNT_BANNED');
      return;
    }

    if (user.isDeleted) {
      sendError(res, 'Account has been deleted', 401, 'ACCOUNT_DELETED');
      return;
    }

    req.user = user;
    next();
  } catch (err: any) {
    if (err.name === 'TokenExpiredError') {
      sendError(res, 'Token has expired. Please refresh your session.', 401, 'TOKEN_EXPIRED');
      return;
    }
    logger.securityAlert('INVALID_TOKEN_PRESENTED', { ip: req.ip, error: err.message });
    sendError(res, 'Invalid authentication token', 401, 'INVALID_TOKEN');
  }
}

// VIP Tier Guard Middleware
export function requireVip(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void {
  if (!req.user || req.user.subscriptionTier === 'free') {
    sendError(
      res,
      'This premium feature requires a Yaalu VIP or Gold subscription.',
      403,
      'VIP_REQUIRED'
    );
    return;
  }
  next();
}
