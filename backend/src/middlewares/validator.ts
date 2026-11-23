import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { sendError } from '../utils/response';

export function validateSchema(
  schema: ZodSchema,
  target: 'body' | 'query' | 'params' = 'body'
) {
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse(req[target]);
      req[target] = parsed; // Replaces with sanitized, validated data
      next();
    } catch (err: any) {
      if (err instanceof ZodError) {
        const issues = err.issues.map((i) => ({
          path: i.path.join('.'),
          message: i.message,
        }));
        res.status(422).json({
          success: false,
          message: 'Validation failed for submitted data',
          errors: issues,
          errorCode: 'VALIDATION_ERROR',
          timestamp: new Date().toISOString(),
        });
        return;
      }
      sendError(res, 'Malformed request data', 400, 'MALFORMED_INPUT');
    }
  };
}
