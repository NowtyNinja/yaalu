import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import { createApp } from './app';
import { config } from './config';
import { initializeSockets } from './sockets/chatSocket';
import { logger } from './utils/logger';

const app = createApp();
const server = http.createServer(app);

// Initialize Real-time Socket.io
const io = new SocketIOServer(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 30000,
  pingInterval: 10000,
});

initializeSockets(io);

server.listen(config.port, '0.0.0.0', () => {
  logger.info(`=======================================================`);
  logger.info(`🔥 YAALU Dating App API Server successfully started!`);
  logger.info(`🚀 Listening on port: ${config.port}`);
  logger.info(`🛡️ Environment: ${config.nodeEnv}`);
  logger.info(`🔒 Security Engine: Zero-Trust Active (Anti-SQLi, Anti-XSS, RateLimited)`);
  logger.info(`📡 API Base: http://localhost:${config.port}${config.apiPrefix}`);
  logger.info(`=======================================================`);
});

// Handle graceful shutdown
const shutdown = () => {
  logger.info('Shutting down server gracefully...');
  server.close(() => {
    logger.info('HTTP server closed.');
    process.exit(0);
  });
};

process.on('uncaughtException', (err) => {
  logger.error(`Uncaught Exception caught: ${err.message}`, { stack: err.stack });
});
process.on('unhandledRejection', (reason) => {
  logger.error(`Unhandled Rejection caught: ${reason}`);
});

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
