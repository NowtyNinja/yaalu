import { Response } from 'express';

export interface ApiResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
  errorCode?: string;
  timestamp: string;
}

export function sendSuccess<T>(
  res: Response,
  data: T,
  message: string = 'Success',
  statusCode: number = 200
): Response {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
    timestamp: new Date().toISOString(),
  });
}

export function sendError(
  res: Response,
  message: string,
  statusCode: number = 400,
  errorCode?: string
): Response {
  return res.status(statusCode).json({
    success: false,
    message,
    errorCode: errorCode || 'INTERNAL_ERROR',
    timestamp: new Date().toISOString(),
  });
}
