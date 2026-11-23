import { Server as SocketIOServer, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { db } from '../database/store';
import { logger } from '../utils/logger';

interface AuthenticatedSocket extends Socket {
  userId?: string;
}

let globalIo: SocketIOServer | null = null;

export function broadcastNewMessage(matchId: string, message: any, excludeUserId?: string): void {
  if (globalIo) {
    if (excludeUserId) {
      const room = globalIo.sockets.adapter.rooms.get(`match:${matchId}`);
      if (room) {
        for (const socketId of room) {
          const s = globalIo.sockets.sockets.get(socketId) as AuthenticatedSocket | undefined;
          if (s && s.userId !== excludeUserId) {
            s.emit('new_message', message);
          }
        }
        return;
      }
    }
    globalIo.to(`match:${matchId}`).emit('new_message', message);
  }
}

export function broadcastTyping(matchId: string, isTyping: boolean): void {
  if (globalIo) {
    globalIo.to(`match:${matchId}`).emit('user_typing', { matchId, isTyping });
  }
}

export function initializeSockets(io: SocketIOServer): void {
  globalIo = io;

  // Authentication Middleware for WebSocket handshakes
  io.use((socket: AuthenticatedSocket, next) => {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace('Bearer ', '');

    if (!token) {
      logger.securityAlert('UNAUTHORIZED_WEBSOCKET_HANDSHAKE', {
        ip: socket.handshake.address,
      });
      return next(new Error('AUTHENTICATION_FAILED: Missing JWT token'));
    }

    try {
      const payload = jwt.verify(token, config.jwt.accessSecret) as { userId: string };
      const user = db.getUserById(payload.userId);

      if (!user || user.isBanned || user.isDeleted) {
        return next(new Error('AUTHENTICATION_FAILED: User inactive or banned'));
      }

      socket.userId = payload.userId;
      next();
    } catch {
      return next(new Error('AUTHENTICATION_FAILED: Invalid or expired token'));
    }
  });

  io.on('connection', (socket: AuthenticatedSocket) => {
    const userId = socket.userId!;
    logger.info(`WebSocket client connected: [${userId}], Socket ID: [${socket.id}]`);

    // Join user's personal notification room
    socket.join(`user:${userId}`);

    // Update user's last active status
    const profile = db.getProfileByUserId(userId);
    if (profile) {
      profile.lastActive = new Date().toISOString();
    }

    // Join specific match room
    socket.on('join_match_room', (data: { matchId: string }) => {
      const { matchId } = data;
      const match = db.matches.get(matchId);

      // Security Check: Only participants can join the match room
      if (match && (match.user1Id === userId || match.user2Id === userId)) {
        socket.join(`match:${matchId}`);
        logger.info(`User [${userId}] joined room [match:${matchId}]`);
      } else {
        logger.securityAlert('UNAUTHORIZED_ROOM_JOIN_ATTEMPT', { userId, matchId });
        socket.emit('error', { message: 'Unauthorized match room join' });
      }
    });

    // Leave match room
    socket.on('leave_match_room', (data: { matchId: string }) => {
      socket.leave(`match:${data.matchId}`);
    });

    // Typing Indicators
    socket.on('typing_start', (data: { matchId: string }) => {
      socket.to(`match:${data.matchId}`).emit('user_typing', {
        userId,
        matchId: data.matchId,
        isTyping: true,
      });
    });

    socket.on('typing_stop', (data: { matchId: string }) => {
      socket.to(`match:${data.matchId}`).emit('user_typing', {
        userId,
        matchId: data.matchId,
        isTyping: false,
      });
    });

    // Send Real-Time Message
    socket.on(
      'send_message',
      (data: {
        matchId: string;
        content: string;
        mediaUrl?: string;
        isVoiceNote?: boolean;
      }) => {
        try {
          const match = db.matches.get(data.matchId);
          if (!match || (match.user1Id !== userId && match.user2Id !== userId)) {
            socket.emit('error', { message: 'Forbidden: Invalid match access' });
            return;
          }

          const message = db.addMessage(
            data.matchId,
            userId,
            data.content,
            data.mediaUrl,
            data.isVoiceNote
          );

          // Broadcast to everyone in the match room
          io.to(`match:${data.matchId}`).emit('new_message', message);

          // Notify receiver in their personal notification room if they are not inside chat screen
          const receiverId = match.user1Id === userId ? match.user2Id : match.user1Id;
          const senderProfile = db.getProfileByUserId(userId);

          io.to(`user:${receiverId}`).emit('match_notification', {
            type: 'NEW_MESSAGE',
            matchId: data.matchId,
            senderName: senderProfile?.displayName || 'Someone',
            preview: data.isVoiceNote ? '🎤 Voice message' : data.content,
          });

          // If the counterpart is a demo user, simulate an interactive reply!
          if (db.demoUserIds.has(receiverId)) {
            setTimeout(() => {
              io.to(`match:${data.matchId}`).emit('user_typing', {
                matchId: data.matchId,
                isTyping: true,
              });
            }, 600);

            setTimeout(() => {
              io.to(`match:${data.matchId}`).emit('user_typing', {
                matchId: data.matchId,
                isTyping: false,
              });
              const replies = [
                'That sounds wonderful! 😊 How was your week so far?',
                'Totally agree with you! ✨ Are you free this weekend for coffee?',
                'Haha I love that! Sri Lankan weather has been crazy lately though ☀️',
                'Nice to hear that! What kind of places do you like around Colombo?',
                'That\'s so cool! Tell me more about your favorite hobbies 😊',
              ];
              const autoReply = replies[Math.floor(Math.random() * replies.length)];
              const replyMsg = db.addMessage(data.matchId, receiverId, autoReply);
              io.to(`match:${data.matchId}`).emit('new_message', replyMsg);
            }, 1800);
          }
        } catch (err: any) {
          socket.emit('error', { message: err.message });
        }
      }
    );

    socket.on('disconnect', () => {
      logger.info(`WebSocket client disconnected: [${userId}]`);
    });
  });
}
