import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import { config } from './config';
import { securityHeaders, hppProtection, inputSanitizer } from './middlewares/security';
import { globalRateLimiter } from './middlewares/rateLimiter';
import { errorHandler } from './middlewares/errorHandler';
import apiRoutes from './routes';

export function createApp(): Application {
  const app: Application = express();

  // Trust proxy for reverse proxy environments (e.g., AWS ALB, Nginx, Cloudflare)
  app.set('trust proxy', 1);

  // 1. Strict Security Headers
  app.use(securityHeaders);

  // 2. CORS configuration
  app.use(
    cors({
      origin: (origin, callback) => {
        // Allow requests with no origin (mobile apps, curl)
        if (!origin) return callback(null, true);
        if (config.cors.allowedOrigins.includes('*') || config.cors.allowedOrigins.includes(origin)) {
          return callback(null, true);
        }
        return callback(new Error('Blocked by CORS policy'));
      },
      credentials: true,
      methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    })
  );

  // 3. Body Parsing with Payload Size Limits (Mitigates Buffer Overflow / Denial of Service)
  app.use(express.json({ limit: '50kb' }));
  app.use(express.urlencoded({ extended: true, limit: '50kb' }));

  // 4. Parameter Pollution Guard
  app.use(hppProtection);

  // 5. Deep Input Sanitization (Anti-XSS, Anti-NoSQL injection)
  app.use(inputSanitizer);

  // 6. Global Rate Limiter
  app.use(globalRateLimiter);

  // Root redirect to API Prefix
  app.get('/', (_req: Request, res: Response) => {
    res.redirect(config.apiPrefix);
  });

  // Static uploads directory for user photos
  const uploadsDir = path.join(__dirname, '../uploads');
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
  }
  const photosDir = path.join(uploadsDir, 'photos');
  if (!fs.existsSync(photosDir)) {
    fs.mkdirSync(photosDir, { recursive: true });
  }
  const audioDir = path.join(uploadsDir, 'audio');
  if (!fs.existsSync(audioDir)) {
    fs.mkdirSync(audioDir, { recursive: true });
  }
  app.use('/uploads', express.static(uploadsDir));

  // Direct APK Download Endpoint for instant wireless installation on phone
  app.get('/download-apk', (_req: Request, res: Response) => {
    res.removeHeader('Content-Security-Policy');
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    
    const releaseApk = path.resolve(__dirname, '../../mobile/build/app/outputs/flutter-apk/app-release.apk');
    const debugApk = path.resolve(__dirname, '../../mobile/build/app/outputs/flutter-apk/app-debug.apk');
    const apkPath = fs.existsSync(releaseApk) ? releaseApk : debugApk;
    
    // Provide a distinct versioned filename to prevent browser cache & download collisions
    res.download(apkPath, 'yaalu-dating-v1.0.9.apk', (err) => {
      if (err && !res.headersSent) {
        res.status(500).send('APK file not found or still compiling: ' + err.message);
      }
    });
  });

  // Mobile App Installation Web Page
  app.get(['/install', '/download'], (_req: Request, res: Response) => {
    res.removeHeader('Content-Security-Policy');
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Yaalu Dating - Install Android 8.1+ Build</title>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:ital,wght@0,400;0,600;0,700;0,800;1,800;1,900&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', sans-serif; }
    body { background: #08090C; color: #FFFFFF; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 24px 16px; }
    .card { background: #13141A; border: 1px solid rgba(255,255,255,0.08); border-radius: 28px; padding: 36px 24px; max-width: 440px; width: 100%; box-shadow: 0 20px 50px rgba(0,0,0,0.5); text-align: center; }
    .logo { font-size: 44px; font-weight: 900; font-style: italic; letter-spacing: -1.5px; margin-bottom: 4px; background: linear-gradient(135deg, #FFFFFF 40%, #FF1A53); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
    .tagline { color: rgba(255,255,255,0.5); font-size: 11px; font-weight: 700; letter-spacing: 3px; margin-bottom: 24px; }
    .badge { display: inline-block; background: rgba(255,26,83,0.15); color: #FF1A53; border: 1px solid rgba(255,26,83,0.3); padding: 6px 14px; border-radius: 20px; font-size: 13px; font-weight: 700; margin-bottom: 24px; }
    .features { text-align: left; background: rgba(255,255,255,0.03); border-radius: 16px; padding: 16px; margin-bottom: 24px; }
    .feature-item { display: flex; align-items: center; gap: 12px; margin-bottom: 10px; font-size: 14px; color: #E2E8F0; }
    .feature-item:last-child { margin-bottom: 0; }
    .btn { display: block; width: 100%; background: linear-gradient(135deg, #FF1A53, #FF4B72); color: #FFFFFF; text-decoration: none; padding: 18px; border-radius: 18px; font-size: 16px; font-weight: 800; box-shadow: 0 10px 24px rgba(255,26,83,0.35); transition: transform 0.2s; margin-bottom: 20px; }
    .btn:active { transform: scale(0.98); }
    .alert-box { background: rgba(245, 158, 11, 0.12); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: 14px; padding: 14px; text-align: left; font-size: 12.5px; color: #FCD34D; line-height: 1.5; }
    .alert-title { font-weight: 800; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }
  </style>
</head>
<body>
  <div class="card">
    <img src="/icon.png" alt="Yaalu Logo" style="width: 84px; height: 84px; border-radius: 22px; margin-bottom: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5);">
    <div class="logo">Yaalu</div>
    <div class="tagline">MEET • VIBE • CONNECT</div>
    <div class="badge">🚀 Version 1.0.9 (Custom App Icon Build)</div>
    
    <div class="features">
      <div class="feature-item"><span>🎨</span> <strong>Official Yaalu App Icon</strong> Embedded</div>
      <div class="feature-item"><span>☁️</span> <strong>Live Cloud Connected</strong> (Render HTTPS / WSS)</div>
      <div class="feature-item"><span>📩</span> <strong>Instant SMS OTP</strong> via Notify.lk Gateway</div>
      <div class="feature-item"><span>📱</span> <strong>Universal Compatibility</strong> (32-bit & 64-bit Android)</div>
      <div class="feature-item"><span>🎙️</span> <strong>Real Voice Notes</strong> (Record & Send)</div>
      <div class="feature-item"><span>📸</span> <strong>Instant Photo Uploads</strong> (Gallery & Camera)</div>
    </div>

    <a href="/download-apk?v=1.0.9&t=${Date.now()}" class="btn">
      ⬇️ Download Yaalu v1.0.9 APK
    </a>

    <div class="alert-box">
      <div class="alert-title">⚠️ IMPORTANT STEP</div>
      Please <strong>UNINSTALL</strong> the previous Yaalu app from your phone first so the new 32-bit package installs cleanly without conflicts.
    </div>

    <div style="margin-top: 24px; font-size: 12px; color: rgba(255,255,255,0.4);">
      <a href="/privacy" style="color: rgba(255,255,255,0.6); text-decoration: none; margin-right: 10px;">Privacy Policy</a> &bull;
      <a href="/terms" style="color: rgba(255,255,255,0.6); text-decoration: none; margin: 0 10px;">Terms of Service</a> &bull;
      <a href="/delete-account" style="color: rgba(255,255,255,0.6); text-decoration: none; margin-left: 10px;">Account Deletion</a>
    </div>
  </div>
</body>
</html>`);
  });

  // Legal & App Store Compliance Web Pages (Privacy Policy, Terms of Service / EULA, Account Deletion)
  const publicDir = path.join(__dirname, '../public');

  app.get('/privacy', (_req: Request, res: Response) => {
    res.sendFile(path.join(publicDir, 'privacy.html'));
  });

  app.get('/terms', (_req: Request, res: Response) => {
    res.sendFile(path.join(publicDir, 'terms.html'));
  });

  app.get(['/delete-account', '/delete-data'], (_req: Request, res: Response) => {
    res.sendFile(path.join(publicDir, 'delete-account.html'));
  });

  // Serve static assets from public directory
  app.use(express.static(publicDir));

  // Admin Dashboard Web Portal - remove restrictive CSP for web admin portal
  app.use('/admin', (_req: Request, res: Response, next) => {
    res.removeHeader('Content-Security-Policy');
    res.removeHeader('X-Frame-Options');
    next();
  }, express.static(path.join(__dirname, '../public/admin')));

  app.get('/admin*', (_req: Request, res: Response) => {
    res.removeHeader('Content-Security-Policy');
    res.removeHeader('X-Frame-Options');
    res.sendFile(path.join(__dirname, '../public/admin/index.html'));
  });

  // 7. Mount Main API Routes
  app.use(config.apiPrefix, apiRoutes);

  // 8. 404 Handler for Unmatched Routes
  app.use((req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      message: `The requested endpoint [${req.method}] ${req.originalUrl} does not exist.`,
      errorCode: 'ROUTE_NOT_FOUND',
      timestamp: new Date().toISOString(),
    });
  });

  // 9. Centralized Error Handler (Prevents stack trace / database error disclosure)
  app.use(errorHandler);

  return app;
}
