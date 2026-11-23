import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from './authMiddleware';
import { sendError } from '../utils/response';
import { logger } from '../utils/logger';

export function requireAdmin(req: AuthenticatedRequest, res: Response, next: NextFunction): void {
  if (!req.user || req.user.role !== 'admin') {
    logger.securityAlert('UNAUTHORIZED_ADMIN_ACCESS_ATTEMPT', {
      userId: req.user?.id,
      role: req.user?.role,
      ip: req.ip,
      path: req.originalUrl,
    });
    sendError(res, 'Access denied. Administrator privileges required.', 403, 'FORBIDDEN');
    return;
  }
  next();
}
