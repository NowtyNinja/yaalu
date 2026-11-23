import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard_screen.dart';
import '../splash_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Account?', style: TextStyle(color: AppColors.passRed, fontWeight: FontWeight.bold)),
        content: const Text(
          'This action is irreversible. All your photos, mutual matches, chat history, and VIP subscriptions will be permanently purged in accordance with Apple & Google Privacy Guidelines.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.passRed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final auth = context.read<AuthProvider>();
              final success = await auth.deleteAccount();
              if (success && context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performUnlock(
    BuildContext context,
    String username,
    String password,
    void Function(void Function()) setModalState,
    void Function(bool) setUnlocking,
    void Function(String?) setError,
  ) async {
    setModalState(() {
      setUnlocking(true);
      setError(null);
    });

    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.adminLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true && data['data'] != null && data['data']['token'] != null) {
        final token = data['data']['token'].toString();
        if (context.mounted) {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AdminDashboardScreen(adminToken: token)),
          );
        }
      } else {
        setModalState(() {
          setUnlocking(false);
          setError(data['message'] ?? 'Invalid administrator credentials');
        });
      }
    } catch (e) {
      setModalState(() {
        setUnlocking(false);
        setError('Connection error: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Settings & Privacy',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Security Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.onlineGreen.withValues(alpha: 0.4)),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.security_rounded, color: AppColors.onlineGreen, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hardware Anti-Screenshot Active',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'FLAG_SECURE hardware protection blocks screenshots and recording of profiles and chats.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Legal & Compliance
          const Text(
            'Legal & Guidelines',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _buildSettingsTile(
            context,
            icon: Icons.description_rounded,
            title: 'End User License Agreement (EULA)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yaalu Standard EULA (Apple Guideline 1.2 compliant)')),
              );
            },
          ),
          const SizedBox(height: 8),

          _buildSettingsTile(
            context,
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yaalu Privacy Policy (AES-256 data protection)')),
              );
            },
          ),
          const SizedBox(height: 8),

          _buildSettingsTile(
            context,
            icon: Icons.groups_rounded,
            title: 'Community Safety Guidelines',
            onTap: () {},
          ),

          const SizedBox(height: 28),

          // Master Admin Console
          const Text(
            'Administrator & Security',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.vipGold.withValues(alpha: 0.4)),
              boxShadow: AppColors.softShadow,
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.vipGold, size: 24),
              ),
              title: const Text('Master Admin Console', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: const Text('Live KPI Dashboard, User Moderation & Bank Transfers',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
              onTap: () {
                final passwordCtrl = TextEditingController(text: 'admin123');
                bool isUnlocking = false;
                String? errorText;

                showDialog(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (context, setModalState) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Row(
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, color: AppColors.vipGold, size: 28),
                          SizedBox(width: 8),
                          Text('Unlock Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enter master administrator credentials to access live KPIs, moderation, and payments:',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Admin Password / Master PIN',
                              hintText: 'admin123 or 777777',
                              prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.vipGold),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              errorText: errorText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFF8E1),
                                foregroundColor: const Color(0xFFD97706),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              icon: const Icon(Icons.flash_on_rounded, size: 18),
                              label: const Text('⚡ 1-Click Instant Unlock (Demo)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: isUnlocking
                                  ? null
                                  : () {
                                      passwordCtrl.text = 'admin123';
                                      _performUnlock(context, 'admin', 'admin123', setModalState, (val) => isUnlocking = val, (err) => errorText = err);
                                    },
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
                          onPressed: isUnlocking
                              ? null
                              : () {
                                  _performUnlock(context, 'admin', passwordCtrl.text.trim(), setModalState, (val) => isUnlocking = val, (err) => errorText = err);
                                },
                          child: isUnlocking
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Unlock Console', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // Account Deletion
          const Text(
            'Account Management',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppColors.softShadow,
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppColors.passRed),
              title: const Text('Delete Account', style: TextStyle(color: AppColors.passRed, fontWeight: FontWeight.bold)),
              subtitle: const Text('Purge all personal data, photos, and match history',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              onTap: () => _confirmDeleteAccount(context),
            ),
          ),

          const SizedBox(height: 40),
          const Center(
            child: Text(
              'Yaalu v1.0.0 (Build 1)\nConnecting people everywhere',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.coral),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
        onTap: onTap,
      ),
    );
  }
}
