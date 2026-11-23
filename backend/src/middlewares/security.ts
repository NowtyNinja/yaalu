import { Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import hpp from 'hpp';
import validator from 'validator';

// 1. Deep Sanitizer: Recursively strip dangerous characters, NoSQL injection operators ($gt, $where),
// prototype pollution (__proto__, prototype), and XSS script tags
export function sanitizeInput(value: any, key?: string): any {
  if (value === null || value === undefined) return value;

  if (typeof value === 'string') {
    // Strip null bytes
    let clean = value.replace(/\0/g, '').trim();

    // Do NOT HTML-escape URLs, file paths, emails, or passwords as it corrupts slashes and queries
    if (
      key === 'url' ||
      key === 'photoUrl' ||
      key === 'photos' ||
      key === 'password' ||
      key === 'email' ||
      clean.startsWith('http://') ||
      clean.startsWith('https://') ||
      clean.startsWith('/uploads/') ||
      clean.includes('&amp;#x2F;') ||
      clean.includes('&#x2F;')
    ) {
      // Unescape any previously corrupted slashes
      return clean
        .replace(/&amp;#x2F;/g, '/')
        .replace(/&#x2F;/g, '/')
        .replace(/&amp;/g, '&');
    }

    // Strip script and iframe tags to prevent XSS without corrupting normal text
    clean = clean.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
    clean = clean.replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '');
    return clean;
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeInput(item, key));
  }

  if (typeof value === 'object') {
    const cleanObj: Record<string, any> = {};
    for (const [k, v] of Object.entries(value)) {
      // Prevent Prototype Pollution
      if (k === '__proto__' || k === 'constructor' || k === 'prototype') {
        continue;
      }
      // Prevent NoSQL operator injection ($gt, $ne, $regex, etc.)
      if (k.startsWith('$')) {
        continue;
      }
      cleanObj[k] = sanitizeInput(v, k);
    }
    return cleanObj;
  }

  return value;
}

// Middleware to clean request body, query, and params
export function inputSanitizer(req: Request, _res: Response, next: NextFunction): void {
  if (req.body) req.body = sanitizeInput(req.body);
  if (req.query) req.query = sanitizeInput(req.query);
  if (req.params) req.params = sanitizeInput(req.params);
  next();
}

// 2. Strict Security Headers configuration
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", 'https://cdn.tailwindcss.com'],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
      imgSrc: ["'self'", 'data:', 'https://images.unsplash.com', 'https://*.amazonaws.com'],
      connectSrc: ["'self'", 'wss:', 'https:', 'http:'],
      fontSrc: ["'self'", 'https://fonts.gstatic.com'],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'", 'https://*.amazonaws.com'],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false,
  crossOriginResourcePolicy: false,
  dnsPrefetchControl: { allow: false },
  frameguard: { action: 'deny' }, // Clickjacking prevention
  hidePoweredBy: true, // Conceal tech stack
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true }, // Strict Transport Security
  ieNoOpen: true,
  noSniff: true, // Prevent MIME sniffing
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
  xssFilter: true,
});

// 3. HTTP Parameter Pollution Guard
export const hppProtection = hpp();

// 4. Cache Control Header for Sensitive Routes
export function noCacheHeaders(_req: Request, res: Response, next: NextFunction): void {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  next();
}
