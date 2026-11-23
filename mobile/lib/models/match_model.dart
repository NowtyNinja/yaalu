import 'profile_model.dart';

class MatchModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessageAt;
  final ProfileModel otherUser;

  MatchModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessageAt,
    required this.otherUser,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final matchData = json['match'] as Map<String, dynamic>? ?? json;
    final otherProfileData = json['otherUserProfile'] as Map<String, dynamic>? ?? {};

    return MatchModel(
      id: matchData['id'] ?? '',
      user1Id: matchData['user1Id'] ?? '',
      user2Id: matchData['user2Id'] ?? '',
      lastMessageAt: matchData['lastMessageAt'],
      otherUser: ProfileModel.fromJson(otherProfileData),
    );
  }
}

class MessageModel {
  final String id;
  final String matchId;
  final String senderId;
  final String receiverId;
  final String content;
  final String? mediaUrl;
  final bool isBlurred;
  final bool isVoiceNote;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.mediaUrl,
    required this.isBlurred,
    required this.isVoiceNote,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      matchId: json['matchId'] ?? '',
      senderId: json['senderId'] ?? '',
      receiverId: json['receiverId'] ?? '',
      content: json['content'] ?? '',
      mediaUrl: json['mediaUrl'],
      isBlurred: json['isBlurred'] ?? false,
      isVoiceNote: json['isVoiceNote'] ?? false,
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PlanModel {
  final String tierKey;
  final String title;
  final double amountLkr;
  final double amountUsd;

  PlanModel({
    required this.tierKey,
    required this.title,
    required this.amountLkr,
    required this.amountUsd,
  });
}
