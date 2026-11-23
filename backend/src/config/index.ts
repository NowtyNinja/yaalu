import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '5000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
  apiPrefix: process.env.API_PREFIX || '/api/v1',

  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'yaalu_dev_fallback_secret_key_change_me_in_prod',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'yaalu_dev_fallback_refresh_key_change_me_in_prod',
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  },

  cors: {
    allowedOrigins: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['*'],
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '200', 10),
    authMax: parseInt(process.env.AUTH_RATE_LIMIT_MAX || '10', 10),
  },

  payhere: {
    merchantId: process.env.PAYHERE_MERCHANT_ID || '1220001',
    secret: process.env.PAYHERE_SECRET || 'yaalu_payhere_secret_hash',
    env: process.env.PAYHERE_ENV || 'sandbox',
  },

  storage: {
    type: process.env.UPLOAD_STORAGE_TYPE || 'local',
  },
};
