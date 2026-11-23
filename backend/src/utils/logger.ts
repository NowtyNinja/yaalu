// Security-conscious Structured Logger for Yaalu API
// Strips sensitive headers, passwords, and tokens before logging

const SENSITIVE_KEYS = new Set([
  'password',
  'token',
  'authorization',
  'refreshtoken',
  'otp',
  'card_number',
  'cvv',
  'secret',
]);

function sanitize(obj: any): any {
  if (!obj || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(sanitize);

  const clean: Record<string, any> = {};
  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_KEYS.has(key.toLowerCase())) {
      clean[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      clean[key] = sanitize(value);
    } else {
      clean[key] = value;
    }
  }
  return clean;
}

export const logger = {
  info: (message: string, meta?: any) => {
    const timestamp = new Date().toISOString();
    console.log(`[INFO] [${timestamp}] ${message}`, meta ? JSON.stringify(sanitize(meta)) : '');
  },
  warn: (message: string, meta?: any) => {
    const timestamp = new Date().toISOString();
    console.warn(`[WARN] [${timestamp}] ${message}`, meta ? JSON.stringify(sanitize(meta)) : '');
  },
  error: (message: string, error?: any) => {
    const timestamp = new Date().toISOString();
    console.error(`[ERROR] [${timestamp}] ${message}`, error ? (error.stack || JSON.stringify(sanitize(error))) : '');
  },
  securityAlert: (threatType: string, details: Record<string, any>) => {
    const timestamp = new Date().toISOString();
    console.warn(
      `[SECURITY_AUDIT] [${timestamp}] ALERT: [${threatType}] Details:`,
      JSON.stringify(sanitize(details))
    );
  },
};
