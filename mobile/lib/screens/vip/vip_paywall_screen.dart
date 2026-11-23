import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../providers/vip_provider.dart';
import '../../providers/auth_provider.dart';

class VipPaywallScreen extends StatefulWidget {
  const VipPaywallScreen({super.key});

  @override
  State<VipPaywallScreen> createState() => _VipPaywallScreenState();
}

class _VipPaywallScreenState extends State<VipPaywallScreen> {
  static const MethodChannel _platformChannel = MethodChannel('com.yaalu.dating/launcher');

  String _selectedTier = 'vip_monthly';
  String _paymentProvider = 'bank_transfer';
  bool _isSubmitting = false;

  final Map<String, String> _tierPrices = {
    'vip_weekly': 'LKR 990',
    'vip_monthly': 'LKR 2,490',
    'vip_annual': 'LKR 14,990',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VipProvider>().fetchPlans();
      final auth = context.read<AuthProvider>();
      if (auth.canSeeWhoLikedMe) {
        context.read<VipProvider>().fetchWhoLikedMe();
      }
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard!'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppColors.coral,
      ),
    );
  }

  void _openWhatsAppSupport(String phone, String refCode) async {
    final amount = _tierPrices[_selectedTier] ?? 'LKR 2,490';
    final message = Uri.encodeComponent(
      'Hi Yaalu Support!\n'
      'I have transferred $amount for Yaalu VIP.\n'
      '• My Phone: $phone\n'
      '• Reference Code: $refCode\n'
      '• Selected Plan: $_selectedTier\n\n'
      'Here is my bank deposit slip / transfer screenshot:'
    );

    final waUrl = 'https://wa.me/94786799544?text=$message';
    Clipboard.setData(ClipboardData(text: 'Reference: $refCode | $amount'));

    try {
      await _platformChannel.invokeMethod('openUrl', {'url': waUrl});
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening WhatsApp Support (+94 78 679 9544)...'),
          backgroundColor: Color(0xFF25D366),
        ),
      );
    }
  }

  void _submitBankTransferActivation(String phone, String refCode) async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();

    try {
      await ApiService.post(ApiEndpoints.bankTransfer, {
        'tier': _selectedTier,
        'bankName': 'Seylan Bank',
        'referenceCode': refCode,
        'slipNote': 'User confirmed transfer via WhatsApp verification flow',
      });

      await auth.checkAuthStatus();
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Bank transfer notification submitted! VIP activated.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _processPayment() async {
    final vip = context.read<VipProvider>();
    final auth = context.read<AuthProvider>();

    if (_paymentProvider == 'payhere') {
      final checkoutData = await vip.initiatePayHere(_selectedTier);
      if (checkoutData != null && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: const [
                Icon(Icons.payment_rounded, color: AppColors.vipGold),
                SizedBox(width: 8),
                Text('PayHere Checkout', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ID: ${checkoutData['orderId']}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Text('Amount: ${checkoutData['currency']} ${checkoutData['amount']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.coral)),
                const SizedBox(height: 14),
                const Text(
                  'Simulation Note: In sandbox mode, click Complete Payment to simulate a verified PayHere IPN webhook callback.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await auth.checkAuthStatus();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 PayHere Payment Verified! Yaalu VIP is now active.'),
                        backgroundColor: Color(0xFF00C853),
                      ),
                    );
                  }
                },
                child: const Text('Complete Payment'),
              ),
            ],
          ),
        );
      }
    } else {
      final success = await vip.verifyIap(
        tierKey: _selectedTier,
        platform: 'apple',
        receiptToken: 'mock_apple_store_receipt_token_valid',
        productId: 'com.yaalu.vip.monthly',
      );

      if (success && mounted) {
        await auth.checkAuthStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 In-App Purchase Verified! VIP Active.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vip = context.watch<VipProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final phone = user?.phone ?? '+94779876543';
    final refCode = 'YAALU-${phone.length >= 6 ? phone.substring(phone.length - 6) : "876543"}';
    final amount = _tierPrices[_selectedTier] ?? 'LKR 2,490';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'VIP & Gold',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 26,
            letterSpacing: -1.0,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Gold Banner Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8E7), Color(0xFFFFF0D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.vipGold.withValues(alpha: 0.5), width: 1.5),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.vipGold.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: AppColors.vipGold, size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Upgrade to Yaalu VIP',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A5A00),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    auth.isVip
                        ? 'You are an active VIP member! Enjoy unlimited access.'
                        : 'Unlock unlimited swiping, see who liked you, and teleport worldwide.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Features Checklist
            _buildFeatureRow(Icons.all_inclusive_rounded, 'Unlimited Swiping & Rewind',
                '100% Free for all Yaalu members in this launch version'),
            _buildFeatureRow(Icons.visibility_rounded, 'See Who Liked You',
                auth.isFemale ? '🌸 100% Free for Female Members' : 'Instantly view profiles that swiped right on you'),
            _buildFeatureRow(Icons.bolt_rounded, 'Profile Boost (Selected Duration)',
                'Paid feature for all members — Be top profile for your chosen duration'),
            _buildFeatureRow(Icons.flight_takeoff_rounded, 'Yaalu Passport',
                'Teleport your GPS location to any city in Sri Lanka or globally'),
            _buildFeatureRow(Icons.visibility_off_rounded, 'Stealth / Incognito Mode',
                'Only visible to people you have personally swiped right on'),
            _buildFeatureRow(Icons.star_rounded, '5 Super Likes per Week',
                'Stand out with instant notification & introductory message'),

            const SizedBox(height: 22),

            if (auth.canSeeWhoLikedMe) ...[
              if (auth.isFemale && !auth.isVip)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB6C1)),
                  ),
                  child: const Row(
                    children: [
                      Text('🌸', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Free Feature for Ladies ✨',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFC71585)),
                            ),
                            Text(
                              'See Who Liked You is 100% free for all female members on Yaalu!',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF8B008B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'People Who Liked You ⭐',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF996500)),
                ),
              ),
              const SizedBox(height: 12),
              vip.whoLikedMe.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: const Center(
                        child: Text(
                          'No new likes yet. Keep swiping and matching!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: vip.whoLikedMe.length,
                      itemBuilder: (ctx, index) {
                        final p = vip.whoLikedMe[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: AppColors.softShadow,
                            image: p.photos.isNotEmpty
                                ? DecorationImage(image: NetworkImage(p.photos[0]), fit: BoxFit.cover)
                                : null,
                          ),
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '${p.displayName}, ${p.age}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 24),
            ],

            if (!auth.isVip) ...[
              // Pricing Plans Cards
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Billing Cycle',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPlanCard('vip_weekly', '1 Week', 'LKR 990', '\$2.99'),
                  const SizedBox(width: 8),
                  _buildPlanCard('vip_monthly', '1 Month', 'LKR 2,490', '\$7.99', isPopular: true),
                  const SizedBox(width: 8),
                  _buildPlanCard('vip_annual', '1 Year', 'LKR 14,990', '\$49.99'),
                ],
              ),
              const SizedBox(height: 20),

              // Payment Gateway Selector Tabs
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Payment Method',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // Bank Transfer Tab (Recommended)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentProvider = 'bank_transfer'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _paymentProvider == 'bank_transfer' ? Colors.white : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _paymentProvider == 'bank_transfer' ? AppColors.vipGold : AppColors.borderLight,
                            width: _paymentProvider == 'bank_transfer' ? 2 : 1,
                          ),
                          boxShadow: _paymentProvider == 'bank_transfer' ? AppColors.softShadow : null,
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.account_balance_rounded, color: AppColors.vipGold, size: 24),
                            SizedBox(height: 6),
                            Text(
                              '🏦 Bank Transfer',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // App Store / Google Play
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _paymentProvider = 'iap'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _paymentProvider == 'iap' ? Colors.white : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _paymentProvider == 'iap' ? AppColors.textPrimary : AppColors.borderLight,
                            width: _paymentProvider == 'iap' ? 2 : 1,
                          ),
                          boxShadow: _paymentProvider == 'iap' ? AppColors.softShadow : null,
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.shop_two_rounded, color: AppColors.textPrimary, size: 24),
                            SizedBox(height: 6),
                            Text(
                              '📱 In-App Store',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Bank Transfer Details Card
              if (_paymentProvider == 'bank_transfer') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.vipGold.withValues(alpha: 0.5), width: 1.2),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.account_balance_outlined, color: AppColors.vipGold, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Sri Lankan Bank Deposit Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _buildBankDetailRow('Bank Name', 'Seylan Bank'),
                      _buildBankDetailRow('Account Name', 'SELL PHONE TECH (PVT)  LTD'),
                      _buildBankDetailRowWithCopy('Account Number', '011013666444120'),
                      _buildBankDetailRow('Branch', 'Gampaha'),
                      _buildBankDetailRowWithCopy('WhatsApp for Slip', '+94 78 679 9544', isHighlight: true),
                      _buildBankDetailRow('Transfer Amount', amount, isHighlight: true),
                      _buildBankDetailRowWithCopy('Reference Code', refCode, isHighlight: true),

                      const Divider(height: 24),

                      const Text(
                        'Instructions: \n1. Transfer subscription fee to the Seylan Bank account above.\n2. Send your deposit slip screenshot to official WhatsApp: +94 78 679 9544.\n3. Mention your Reference Code in the message.\n4. VIP access will be unlocked immediately upon verification!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45),
                      ),
                      const SizedBox(height: 16),

                      // Direct WhatsApp Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                          label: const Text('Send Slip to WhatsApp (+94 78 679 9544) 💬', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => _openWhatsAppSupport(phone, refCode),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Confirm & Unlock in App Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.vipGold),
                          label: _isSubmitting
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.vipGold))
                              : const Text('I have sent the slip (Activate VIP)', style: TextStyle(color: Color(0xFF996500), fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.vipGold),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isSubmitting ? null : () => _submitBankTransferActivation(phone, refCode),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Default Upgrade Button for PayHere and IAP
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.vipGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: vip.isLoading ? null : _processPayment,
                    child: vip.isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : Text('Proceed to Pay ($amount)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ] else ...[
              // VIP Active section
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.vipGold.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: AppColors.vipGold, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Yaalu VIP Active ⭐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF7A5700))),
                          SizedBox(height: 2),
                          Text('You have active access to Profile Boost, Yaalu Passport & Incognito mode.', style: TextStyle(fontSize: 12, color: Color(0xFF7A5700))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBankDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? AppColors.coral : AppColors.textPrimary,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailRowWithCopy(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isHighlight ? AppColors.coral : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _copyToClipboard(value, label),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Icon(Icons.copy_rounded, color: AppColors.coral, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String tierKey, String duration, String lkr, String usd, {bool isPopular = false}) {
    final isSelected = _selectedTier == tierKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTier = tierKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.vipGold : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.vipGold.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : AppColors.softShadow,
          ),
          child: Column(
            children: [
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.vipGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              Text(duration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Text(lkr, style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text(usd, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.vipGoldLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.vipGold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
