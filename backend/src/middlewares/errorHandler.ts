import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { config } from '../config';

export function errorHandler(
  err: any,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  // Always log internal details securely on the server
  logger.error(`Unhandled Exception at [${req.method}] ${req.originalUrl}:`, err);

  const statusCode = err.statusCode || (err.status ? Number(err.status) : 500);
  const isProd = config.isProduction;

  // Never reveal stack traces or database driver errors to clients
  const message =
    isProd && statusCode === 500
      ? 'An unexpected internal error occurred. Please try again shortly.'
      : err.message || 'Internal Server Error';

  res.status(statusCode).json({
    success: false,
    message,
    errorCode: err.errorCode || 'INTERNAL_ERROR',
    timestamp: new Date().toISOString(),
  });
}
