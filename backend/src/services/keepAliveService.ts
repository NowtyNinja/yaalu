import { logger } from '../utils/logger';

/**
 * 24/7 Server Keep-Alive Service
 * Sends a lightweight heartbeat ping to the public URL every 10 minutes,
 * preventing Render Free Tier from entering cold sleep (15-min inactivity threshold).
 */
export class KeepAliveService {
  private static intervalTimer: NodeJS.Timeout | null = null;
  private static readonly PING_INTERVAL_MS = 10 * 60 * 1000; // 10 minutes
  private static readonly TARGET_URL = process.env.KEEP_ALIVE_URL || 'https://yaalu-backend.onrender.com/api/v1/health';

  public static start(): void {
    if (this.intervalTimer) return;

    // Only activate auto-ping in production environments
    const isProduction = process.env.NODE_ENV === 'production';
    if (!isProduction) {
      logger.info('KeepAliveService: Skipped (non-production environment)');
      return;
    }

    logger.info(`⏰ KeepAliveService started: Target [${this.TARGET_URL}] every 10 minutes`);

    // Initial warm-up ping after 2 minutes of startup
    setTimeout(() => {
      this.ping();
    }, 2 * 60 * 1000);

    // Recurring 10-minute heartbeat
    this.intervalTimer = setInterval(() => {
      this.ping();
    }, this.PING_INTERVAL_MS);
  }

  private static async ping(): Promise<void> {
    try {
      const startTime = Date.now();
      const res = await fetch(this.TARGET_URL, {
        method: 'GET',
        headers: {
          'User-Agent': 'Yaalu-KeepAlive-Heartbeat/1.0',
        },
      });
      const duration = Date.now() - startTime;
      if (res.ok) {
        logger.info(`💚 KeepAlive Heartbeat OK (${res.status}) in ${duration}ms - Server kept awake`);
      } else {
        logger.warn(`⚠️ KeepAlive Heartbeat returned status: ${res.status}`);
      }
    } catch (err: any) {
      logger.error('KeepAlive Heartbeat error (non-fatal):', err.message);
    }
  }

  public static stop(): void {
    if (this.intervalTimer) {
      clearInterval(this.intervalTimer);
      this.intervalTimer = null;
      logger.info('KeepAliveService stopped.');
    }
  }
}
