import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import 'edit_profile_screen.dart';
import 'passport_screen.dart';
import 'settings_screen.dart';
import '../vip/vip_paywall_screen.dart';
import '../splash_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final user = auth.user;

    final photo = (profile != null && profile.photos.isNotEmpty)
        ? ApiEndpoints.resolveImageUrl(profile.photos[0])
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 26,
            letterSpacing: -1.0,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Avatar & Name Card
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  );
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: user?.isVip == true
                            ? AppColors.vipGradient
                            : AppColors.coralGradient,
                        boxShadow: AppColors.softShadow,
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                        child: photo.isEmpty ? const Icon(Icons.person, size: 54, color: Colors.grey) : null,
                      ),
                    ),
                    if (profile?.isVerified == true)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00B0FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 14),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${profile?.displayName ?? 'Yaalu User'}, ${profile?.age ?? 22}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (profile?.isVerified == true) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, color: Color(0xFF00B0FF), size: 20),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${profile?.homeDistrict ?? profile?.city ?? 'Colombo'} • ${user?.phone ?? ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Edit Profile Button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.coral,
                    elevation: 1,
                    side: const BorderSide(color: AppColors.coral, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text(
                    'Edit Profile & Photos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // My Photos Gallery Preview
            if (profile != null && profile.photos.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 18, color: AppColors.coral),
                            const SizedBox(width: 8),
                            Text(
                              'My Photos (${profile.photos.length}/6)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                            );
                          },
                          child: const Text(
                            '+ Manage',
                            style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 94,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: profile.photos.length < 6 ? profile.photos.length + 1 : profile.photos.length,
                        itemBuilder: (context, i) {
                          if (i < profile.photos.length) {
                            final pUrl = ApiEndpoints.resolveImageUrl(profile.photos[i]);
                            final isMain = i == 0;
                            return Container(
                              width: 74,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isMain ? AppColors.coral : AppColors.borderLight,
                                  width: isMain ? 2 : 1,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      pUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  if (isMain)
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.coral,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'MAIN',
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          } else {
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                );
                              },
                              child: Container(
                                width: 74,
                                decoration: BoxDecoration(
                                  color: AppColors.coralLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_rounded, color: AppColors.coral, size: 20),
                                    SizedBox(height: 4),
                                    Text('Add', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Bio & Details Card
            if (profile != null && profile.bio.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.format_quote_rounded, color: AppColors.coral, size: 18),
                        SizedBox(width: 6),
                        Text('About Me', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.bio,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
                    ),
                    if (profile.interests.isNotEmpty) ...[
                      const Divider(height: 24),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: profile.interests.map((it) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              it,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

            // VIP Upgrade Callout
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VipPaywallScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: user?.isVip == true ? AppColors.vipGoldLight : AppColors.coralLight,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: user?.isVip == true
                        ? AppColors.vipGold.withValues(alpha: 0.5)
                        : AppColors.coral.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: user?.isVip == true ? AppColors.vipGold : AppColors.coral,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        user?.isVip == true ? Icons.workspace_premium_rounded : Icons.star_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.isVip == true ? 'Yaalu VIP Active ⭐' : 'Upgrade to Yaalu VIP',
                            style: TextStyle(
                              color: user?.isVip == true ? const Color(0xFF996500) : AppColors.coral,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.isVip == true
                                ? 'Unlimited swipes, Passport & Stealth enabled'
                                : 'Get unlimited swipes, passport & see who liked you',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Feature Options
            _buildProfileTile(
              icon: Icons.flight_takeoff_rounded,
              title: 'Yaalu Passport (Worldwide GPS)',
              subtitle: profile?.isPassportActive == true
                  ? 'Currently set to ${profile?.city}'
                  : 'Teleport to London, Melbourne, or any city',
              trailing: user?.isVip == true ? 'ACTIVE' : 'VIP ONLY',
              isVipOnly: user?.isVip != true,
              onTap: () {
                if (user?.isVip != true) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VipPaywallScreen()),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PassportScreen()),
                  );
                }
              },
            ),

            _buildProfileTile(
              icon: Icons.visibility_off_rounded,
              title: 'Stealth / Incognito Mode',
              subtitle: 'Only show my profile to people I like',
              trailing: profile?.isStealthMode == true ? 'ON' : 'OFF',
              isVipOnly: user?.isVip != true,
              onTap: () async {
                if (user?.isVip != true) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VipPaywallScreen()),
                  );
                  return;
                }
                try {
                  await ApiService.post(ApiEndpoints.stealthMode, {});
                  await auth.checkAuthStatus();
                } catch (_) {}
              },
            ),

            _buildProfileTile(
              icon: Icons.bolt_rounded,
              title: 'Profile Boost',
              subtitle: 'Be the top profile in your district for 1 hour',
              trailing: 'BOOST',
              isVipOnly: user?.isVip != true,
              onTap: () async {
                if (user?.isVip != true) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VipPaywallScreen()),
                  );
                  return;
                }
                try {
                  await ApiService.post(ApiEndpoints.boost, {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ Profile boosted to top stack!')),
                  );
                } catch (_) {}
              },
            ),

            const Divider(height: 32),

            // Logout & Delete
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: Colors.white,
              leading: const Icon(Icons.logout_rounded, color: AppColors.passRed),
              title: const Text('Log Out', style: TextStyle(color: AppColors.passRed, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
              onTap: () async {
                await auth.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required bool isVipOnly,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isVipOnly ? AppColors.vipGoldLight : AppColors.coralLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isVipOnly ? AppColors.vipGold : AppColors.coral, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isVipOnly ? AppColors.vipGoldLight : AppColors.coralLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isVipOnly ? AppColors.vipGold.withValues(alpha: 0.4) : AppColors.coral.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            trailing,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isVipOnly ? const Color(0xFF996500) : AppColors.coral,
            ),
          ),
        ),
      ),
    );
  }
}
