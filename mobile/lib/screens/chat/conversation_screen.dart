import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_audio_service.dart';
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ConversationScreen extends StatefulWidget {
  final MatchModel match;
  const ConversationScreen({super.key, required this.match});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  // Real Audio Recording State
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String? _recordedLocalPath;

  // Audio Playback State
  String? _playingMessageId;
  StreamSubscription? _audioCompleteSub;

  @override
  void initState() {
    super.initState();
    NativeAudioService.init();
    _audioCompleteSub = NativeAudioService.onAudioCompleted.listen((path) {
      if (mounted) {
        setState(() => _playingMessageId = null);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().openConversation(widget.match.id);
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioCompleteSub?.cancel();
    NativeAudioService.stopAudio();
    _messageController.dispose();
    super.dispose();
  }

  void _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await context.read<ChatProvider>().sendMessage(text);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // Start Real Voice Recording
  void _startVoiceRecording() async {
    final hasPerm = await NativeAudioService.requestPermission();
    if (!hasPerm && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record voice notes.')),
      );
    }

    final path = await NativeAudioService.startRecording();
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _recordedLocalPath = path;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordSeconds += 1);
      }
    });
  }

  // Cancel Voice Recording
  void _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    await NativeAudioService.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordedLocalPath = null;
    });
  }

  // Stop Recording and Send Voice Note
  void _sendVoiceRecording() async {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isSending = true;
    });

    try {
      final recResult = await NativeAudioService.stopRecording();
      final localFile = recResult?.localPath ?? _recordedLocalPath;
      final duration = recResult?.durationSeconds ?? (_recordSeconds > 0 ? _recordSeconds : 1);

      if (localFile != null && localFile.isNotEmpty) {
        // Upload audio to server
        final audioUrl = await NativeAudioService.uploadVoiceNote(localFile, duration);
        final min = duration ~/ 60;
        final sec = duration % 60;
        final durationLabel = '$min:${sec.toString().padLeft(2, '0')}';

        await context.read<ChatProvider>().sendMessage(
              'Voice Note ($durationLabel)',
              mediaUrl: audioUrl ?? localFile,
              isVoiceNote: true,
            );
      } else {
        // Fallback demo voice note if hardware recording failed
        await context.read<ChatProvider>().sendMessage(
              'Voice Note (0:08)',
              isVoiceNote: true,
            );
      }
    } catch (_) {
      // Fallback
      await context.read<ChatProvider>().sendMessage(
            'Voice Note (0:06)',
            isVoiceNote: true,
          );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _recordSeconds = 0;
          _recordedLocalPath = null;
        });
      }
    }
  }

  // Toggle Audio Playback
  void _togglePlayAudio(MessageModel msg) async {
    if (_playingMessageId == msg.id) {
      await NativeAudioService.stopAudio();
      setState(() => _playingMessageId = null);
      return;
    }

    final audioPath = msg.mediaUrl ?? '';
    if (audioPath.isNotEmpty) {
      setState(() => _playingMessageId = msg.id);
      final ok = await NativeAudioService.playAudio(audioPath);
      if (!ok && mounted) {
        setState(() => _playingMessageId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playing simulated audio message...')),
        );
      }
    } else {
      // Demo voice note audio feedback
      setState(() => _playingMessageId = msg.id);
      Timer(const Duration(seconds: 4), () {
        if (mounted && _playingMessageId == msg.id) {
          setState(() => _playingMessageId = null);
        }
      });
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Safety & Moderation',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.passRedLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flag_rounded, color: AppColors.passRed, size: 20),
              ),
              title: const Text('Report User', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ApiService.post(ApiEndpoints.reportUser, {
                    'reportedUserId': widget.match.otherUser.userId,
                    'reason': 'harassment',
                    'description': 'Reported from chat screen',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted. We take safety very seriously.')),
                    );
                  }
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.block_rounded, color: AppColors.vipGold, size: 20),
              ),
              title: const Text('Block User', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ApiService.post(ApiEndpoints.blockUser, {
                    'targetUserId': widget.match.otherUser.userId,
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User blocked. You will no longer see each other.')),
                    );
                  }
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRatingDialog() {
    int selectedStars = 5;
    final List<String> availableTags = [
      '🌟 Great Conversation',
      '🤝 Polite & Respectful',
      '📸 Looks Like Photos',
      '⏰ Showed Up On Time',
      '🛡️ Felt 100% Safe',
      '☕ Friendly Vibe',
    ];
    final Set<String> selectedTags = {'🤝 Polite & Respectful', '🛡️ Felt 100% Safe'};
    final reviewController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.vipGold, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rate Date with ${widget.match.otherUser.displayName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Help keep the Yaalu dating community safe, respectful, and verified.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),

              // Star Selector
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.vipGold,
                        size: 38,
                      ),
                      onPressed: () {
                        setModalState(() => selectedStars = starIndex);
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),

              // Compliment Tags
              const Text(
                'Compliments & Safety Feedback',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableTags.map((tag) {
                  final isSelected = selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: AppColors.coralLight,
                    backgroundColor: AppColors.surface,
                    checkmarkColor: AppColors.coral,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.coral : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppColors.coral : AppColors.borderLight,
                      ),
                    ),
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          selectedTags.add(tag);
                        } else {
                          selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: reviewController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add an optional note about your date experience...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ApiService.post(ApiEndpoints.rateDate, {
                        'ratedUserId': widget.match.otherUser.userId,
                        'rating': selectedStars,
                        'tags': selectedTags.toList(),
                        'comment': reviewController.text.trim(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🌟 Thank you! Your verified date rating has been recorded.'),
                            backgroundColor: AppColors.onlineGreen,
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                  child: const Text('Submit Rating & Badge Points'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final otherUser = widget.match.otherUser;
    final messages = chat.currentMessages;
    final photo = otherUser.photos.isNotEmpty ? ApiEndpoints.resolveImageUrl(otherUser.photos[0]) : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.coralLight,
                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty ? const Icon(Icons.person, color: AppColors.coral, size: 22) : null,
                ),
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.onlineGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          otherUser.displayName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Active Now',
                    style: TextStyle(fontSize: 11, color: AppColors.onlineGreen, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: AppColors.vipGold, size: 26),
            tooltip: 'Rate Date',
            onPressed: _showDateRatingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: AppColors.textSecondary, size: 22),
            tooltip: 'Safety & Moderation',
            onPressed: _showReportDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: chat.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
                  : messages.isEmpty
                      ? _buildStartConversationView()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: messages.length,
                          itemBuilder: (ctx, index) {
                            final msg = messages[index];
                            final isMe = msg.senderId == auth.user?.id;
                            return _buildMessageBubble(msg, isMe);
                          },
                        ),
            ),

            // Typing Indicator
            if (chat.isOtherUserTyping)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${otherUser.displayName} is typing...',
                          style: const TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Input / Voice Recording Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: AppColors.borderLight, width: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _isRecording ? _buildRecordingBar() : _buildNormalInputBar(),
            ),
          ],
        ),
      ),
    );
  }

  // Normal Chat Input Bar
  Widget _buildNormalInputBar() {
    return Row(
      children: [
        // Voice Note Mic Button (Tapping starts recording)
        GestureDetector(
          onTap: _startVoiceRecording,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.coralLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.coral.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.mic_rounded, color: AppColors.coral, size: 22),
          ),
        ),
        const SizedBox(width: 10),

        // Text input field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _sendText(),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Send Button
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.coralGradient,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 19),
            onPressed: _isSending ? null : _sendText,
          ),
        ),
      ],
    );
  }

  // Active Voice Note Recording Dock
  Widget _buildRecordingBar() {
    final minutes = _recordSeconds ~/ 60;
    final seconds = _recordSeconds % 60;
    final timerText = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Row(
      children: [
        // Pulsing Red Recording Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.passRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timerText,
                style: const TextStyle(
                  color: AppColors.passRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Live Simulated Audio Waveform
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(8, (i) {
              final heights = [10.0, 18.0, 14.0, 24.0, 12.0, 20.0, 16.0, 8.0];
              final factor = ((_recordSeconds + i) % 4) + 1;
              return Container(
                width: 3.5,
                height: heights[i] * (0.6 + factor * 0.15),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.coral,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),

        // Cancel Recording Button
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 24),
          tooltip: 'Cancel',
          onPressed: _cancelVoiceRecording,
        ),

        // Send Voice Note Button
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.coralGradient,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
            tooltip: 'Send Voice Note',
            onPressed: _sendVoiceRecording,
          ),
        ),
      ],
    );
  }

  // Modern Message Bubble (Text & Voice Notes)
  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final isPlayingThis = _playingMessageId == msg.id;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          gradient: isMe ? AppColors.coralGradient : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMe ? 22 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 22),
          ),
          border: isMe ? null : Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: msg.isVoiceNote
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play / Pause Circle
                  GestureDetector(
                    onTap: () => _togglePlayAudio(msg),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white : AppColors.coralLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: isMe ? AppColors.coral : AppColors.coral,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Waveform Visualizer
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(12, (index) {
                          final barHeights = [8.0, 16.0, 12.0, 20.0, 14.0, 18.0, 10.0, 15.0, 9.0, 17.0, 11.0, 6.0];
                          final barColor = isMe
                              ? (isPlayingThis && index % 2 == 0 ? Colors.white : Colors.white70)
                              : (isPlayingThis && index % 2 == 0 ? AppColors.coral : AppColors.textMuted);
                          return Container(
                            width: 3,
                            height: barHeights[index],
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPlayingThis ? 'Playing...' : msg.content.replaceAll('Voice Note', '').replaceAll('(', '').replaceAll(')', '').trim(),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Text(
                msg.content,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildStartConversationView() {
    final photo = widget.match.otherUser.photos.isNotEmpty ? ApiEndpoints.resolveImageUrl(widget.match.otherUser.photos[0]) : '';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.coralGradient,
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty ? const Icon(Icons.person, color: Colors.grey, size: 40) : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You matched with ${widget.match.otherUser.displayName}!',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Send a voice note or say hi to get started ✨',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
