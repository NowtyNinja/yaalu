import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../models/profile_model.dart';
import '../../../models/match_model.dart';
import '../../chat/conversation_screen.dart';
import '../../chat/chat_list_screen.dart';

class MatchDialog extends StatelessWidget {
  final ProfileModel matchedProfile;
  final MatchModel? match;
  final VoidCallback onDismiss;

  const MatchDialog({
    super.key,
    required this.matchedProfile,
    this.match,
    required this.onDismiss,
  });

  void _openChat(BuildContext context) {
    onDismiss();
    if (match != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConversationScreen(match: match!)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = matchedProfile.photos.isNotEmpty
        ? ApiEndpoints.resolveImageUrl(matchedProfile.photos[0])
        : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.coral.withValues(alpha: 0.25),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.coralLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'IT\'S A YAALU MATCH! 🎉',
                style: TextStyle(
                  color: AppColors.coral,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Profile photo circle
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.coralGradient,
                  ),
                  child: CircleAvatar(
                    radius: 52,
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    backgroundColor: AppColors.surface,
                    child: photo.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'You & ${matchedProfile.displayName}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'You both liked each other! Say hello or send a voice note.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 20),

            // Quick Icebreaker Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                'Ayubowan! 😊',
                'Hey there! ✨',
                'Coffee sometime? ☕',
              ].map((greeting) {
                return InkWell(
                  onTap: () => _openChat(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.coralLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.coral.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // Direct Chat Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppColors.coralGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: AppColors.buttonShadow,
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => _openChat(context),
                icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Start Chatting Now',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Keep Swiping Button
            TextButton(
              onPressed: onDismiss,
              child: const Text(
                'Keep Exploring',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
