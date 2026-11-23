import { Response } from 'express';
import { z } from 'zod';
import { db } from '../database/store';
import { sendSuccess, sendError } from '../utils/response';
import { AuthenticatedRequest } from '../middlewares/authMiddleware';
import { logger } from '../utils/logger';
import { broadcastNewMessage, broadcastTyping } from '../sockets/chatSocket';

// Send Message Schema
export const sendMessageSchema = z.object({
  matchId: z.string().uuid(),
  content: z.string().min(1, 'Message cannot be empty').max(1000, 'Message maximum 1000 characters'),
  mediaUrl: z.string().min(1).optional(),
  isVoiceNote: z.boolean().optional().default(false),
});

export class ChatController {
  // Get All Mutual Matches
  public static async getMatches(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const matches = db.getUserMatches(userId);
    sendSuccess(res, matches, 'Matches retrieved');
  }

  // Get Messages for Match (Protected against IDOR)
  public static async getMessages(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { matchId } = req.params;

    try {
      const messages = db.getMessagesForMatch(matchId, userId);
      sendSuccess(res, messages, 'Messages retrieved');
    } catch (err: any) {
      if (err.message === 'FORBIDDEN_MATCH_ACCESS') {
        sendError(res, 'Access denied to this match conversation', 403, 'FORBIDDEN');
        return;
      }
      sendError(res, 'Match not found', 404);
    }
  }

  // Send Message
  public static async sendMessage(req: AuthenticatedRequest, res: Response): Promise<void> {
    const senderId = req.user!.id;
    const { matchId, content, mediaUrl, isVoiceNote } = req.body;

    try {
      const message = db.addMessage(matchId, senderId, content, mediaUrl, isVoiceNote);
      broadcastNewMessage(matchId, message, senderId);

      // Respond immediately to sender
      sendSuccess(res, message, 'Message sent', 201);

      // If counterpart is demo user, simulate conversational reply
      const match = db.matches.get(matchId);
      if (match) {
        const receiverId = match.user1Id === senderId ? match.user2Id : match.user1Id;
        if (db.demoUserIds.has(receiverId)) {
          setTimeout(() => {
            broadcastTyping(matchId, true);
          }, 600);

          setTimeout(() => {
            broadcastTyping(matchId, false);
            const replies = [
              'That sounds wonderful! 😊 How was your week so far?',
              'Totally agree with you! ✨ Are you free this weekend for coffee?',
              'Haha I love that! Sri Lankan weather has been crazy lately though ☀️',
              'Nice to hear that! What kind of places do you like around Colombo?',
              'That\'s so cool! Tell me more about your favorite hobbies 😊',
            ];
            const autoReply = replies[Math.floor(Math.random() * replies.length)];
            const replyMsg = db.addMessage(matchId, receiverId, autoReply);
            broadcastNewMessage(matchId, replyMsg);
          }, 1800);
        }
      }
    } catch (err: any) {
      if (err.message === 'FORBIDDEN_MESSAGE_SEND') {
        sendError(res, 'You are not a participant in this conversation', 403, 'FORBIDDEN');
        return;
      }
      logger.error('Error sending message:', err);
      sendError(res, 'Failed to send message', 400);
    }
  }

  // Upload Voice Note Audio File
  public static async uploadVoice(req: AuthenticatedRequest, res: Response): Promise<void> {
    if (!req.file) {
      sendError(res, 'No audio file provided', 400);
      return;
    }

    const relativeUrl = `/uploads/audio/${req.file.filename}`;
    const fullUrl = `http://${req.get('host')}${relativeUrl}`;
    logger.info(`Voice note uploaded: [${req.file.filename}] (${req.file.size} bytes)`);

    sendSuccess(
      res,
      {
        audioUrl: relativeUrl,
        fullUrl,
        duration: req.body.duration || '0:05',
      },
      'Voice note uploaded successfully',
      201
    );
  }

  // Toggle Media Blur (Privacy Protection)
  public static async toggleBlur(req: AuthenticatedRequest, res: Response): Promise<void> {
    const userId = req.user!.id;
    const { messageId } = req.params;

    try {
      const updatedMessage = db.toggleMessageBlur(messageId, userId);
      sendSuccess(res, updatedMessage, 'Photo blur updated');
    } catch (err: any) {
      sendError(res, 'Unable to update media blur', 403);
    }
  }
}
