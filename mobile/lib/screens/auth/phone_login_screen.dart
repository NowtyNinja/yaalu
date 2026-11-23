import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../home/main_navigation_screen.dart';
import '../onboarding/profile_builder_screen.dart';
import 'otp_verification_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+94'; // Default Sri Lanka

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showEmailRecoveryDialog(BuildContext context) {
    final emailController = TextEditingController();
    final otpController = TextEditingController();
    final newPhoneController = TextEditingController();

    int step = 1;
    bool isLoading = false;
    String? errorMessage;
    String? maskedPhone;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sim_card_alert_rounded, color: AppColors.coral, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                step == 1 ? 'Lost SIM Recovery' : 'Verify Recovery',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step == 1) ...[
                  const Text(
                    'Did you lose or damage your SIM card? Enter your linked recovery email to reclaim your account and messages.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Registered Recovery Email',
                      hintText: 'name@example.com',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.coral),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Account found: ${maskedPhone ?? ""}',
                    style: const TextStyle(color: AppColors.onlineGreen, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter the 6-digit recovery OTP and your new phone number:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(letterSpacing: 6, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '------',
                      labelText: 'Recovery OTP',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'New SIM Phone Number',
                      hintText: '07X XXXXXXX or +947X...',
                      prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.coral),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.passRed, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.coral,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final auth = context.read<AuthProvider>();
                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      if (step == 1) {
                        final email = emailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          setState(() {
                            isLoading = false;
                            errorMessage = 'Please enter a valid recovery email address';
                          });
                          return;
                        }
                        final res = await auth.recoverAccountRequest(email);
                        if (res['success'] == true) {
                          setState(() {
                            step = 2;
                            isLoading = false;
                            if (res['data'] != null) {
                              maskedPhone = res['data']['maskedPhone']?.toString();
                            }
                          });
                        } else {
                          setState(() {
                            isLoading = false;
                            errorMessage = res['message'] ?? 'No account linked with this email';
                          });
                        }
                      } else {
                        final email = emailController.text.trim();
                        final otp = otpController.text.trim();
                        final newPhone = newPhoneController.text.trim();
                        if (otp.length < 4 || newPhone.isEmpty) {
                          setState(() {
                            isLoading = false;
                            errorMessage = 'Please enter OTP and your new phone number';
                          });
                          return;
                        }

                        final success = await auth.recoverAccountVerify(
                          email: email,
                          otp: otp,
                          newPhone: newPhone,
                        );

                        if (success) {
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.onlineGreen,
                                content: Text('Account recovered successfully! Welcome back! 🎉'),
                              ),
                            );

                            if (auth.isNewUser || auth.profile == null || auth.profile!.displayName.isEmpty) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const ProfileBuilderScreen()),
                                (route) => false,
                              );
                            } else {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                                (route) => false,
                              );
                            }
                          }
                        } else {
                          setState(() {
                            isLoading = false;
                            errorMessage = auth.errorMessage ?? 'Invalid recovery code or phone number';
                          });
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      step == 1 ? 'Find Account' : 'Recover & Login',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    final rawNumber = _phoneController.text.trim();
    if (rawNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    String digitsOnly = rawNumber.replaceAll(RegExp(r'[\s\-\(\)\.]+'), '');

    String fullPhone;
    if (digitsOnly.startsWith('+')) {
      fullPhone = digitsOnly;
    } else if (digitsOnly.startsWith('94') && digitsOnly.length >= 11) {
      fullPhone = '+$digitsOnly';
    } else {
      if (digitsOnly.startsWith('0')) {
        digitsOnly = digitsOnly.substring(1);
      }
      fullPhone = '$_selectedCountryCode$digitsOnly';
    }

    if (fullPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number (e.g. 77 123 4567)')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.requestOtp(fullPhone);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phone: fullPhone),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to send SMS OTP. Check connection.'),
          backgroundColor: AppColors.passRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - 40,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // App Brand Mark
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.obsidianBlack,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Yaalu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.coralLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sri Lanka',
                          style: TextStyle(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Headline
                  const Text(
                    'Enter your\nphone number',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -1.0,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We will send a 6-digit verification code to log you in securely.',
                    style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 36),

                  // Country Code & Phone Input Card
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.borderLight, width: 1.2),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCountryCode,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                              items: const [
                                DropdownMenuItem(value: '+94', child: Text('🇱🇰 +94')),
                                DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                                DropdownMenuItem(value: '+61', child: Text('🇦🇺 +61')),
                                DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                                DropdownMenuItem(value: '+971', child: Text('🇦🇪 +971')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCountryCode = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                            decoration: const InputDecoration(
                              hintText: '77 123 4567',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Terms & Compliance
                  const Center(
                    child: Text(
                      'By continuing, you accept Yaalu\'s Terms of Use & Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Continue Gradient Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.coralGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: AppColors.buttonShadow,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lost SIM / Account Recovery Option
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      icon: const Icon(Icons.sim_card_alert_rounded, size: 18, color: AppColors.coral),
                      label: const Text(
                        'Lost your SIM? Recover via Email 📧',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      onPressed: () => _showEmailRecoveryDialog(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
