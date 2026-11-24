import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminToken;
  const AdminDashboardScreen({super.key, required this.adminToken});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  Map<String, dynamic> _stats = {};
  List<dynamic> _users = [];
  List<dynamic> _payments = [];
  List<dynamic> _reports = [];
  List<dynamic> _staff = [];

  final TextEditingController _userSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchStats(),
      _fetchStaff(),
      _fetchUsers(_userSearchCtrl.text),
      _fetchPayments(),
      _fetchReports(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.adminToken}',
      };

  Future<void> _fetchStats() async {
    try {
      final res = await http.get(Uri.parse(ApiEndpoints.adminStats), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) setState(() => _stats = data['data']);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchStaff() async {
    try {
      final res = await http.get(Uri.parse(ApiEndpoints.adminStaff), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) setState(() => _staff = data['data']['staff'] ?? []);
        }
      }
    } catch (_) {}
  }

  Future<bool> _addStaffMember({
    required String name,
    required String phone,
    required String username,
    required String role,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.adminStaff),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'username': username,
          'role': role,
          'password': password,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _showToast('Staff member added: $name ($role) 🎉');
        await _fetchStaff();
        return true;
      } else {
        _showToast(data['message'] ?? 'Failed to add staff member');
        return false;
      }
    } catch (e) {
      _showToast('Network error: $e');
      return false;
    }
  }

  Future<void> _removeStaffMember(String staffId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Staff Access?'),
        content: Text('Are you sure you want to revoke staff privileges for $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.passRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(
        Uri.parse(ApiEndpoints.adminDeleteStaff(staffId)),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        _showToast('Staff privileges revoked for $name');
        await _fetchStaff();
      }
    } catch (e) {
      _showToast('Error revoking staff: $e');
    }
  }

  Future<void> _fetchUsers([String query = '']) async {
    try {
      final res = await http.get(Uri.parse(ApiEndpoints.adminUsers(query)), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) setState(() => _users = data['data']['users'] ?? []);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchPayments() async {
    try {
      final res = await http.get(Uri.parse(ApiEndpoints.adminPayments), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) setState(() => _payments = data['data']['payments'] ?? []);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchReports() async {
    try {
      final res = await http.get(Uri.parse(ApiEndpoints.adminReports), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) setState(() => _reports = data['data']['reports'] ?? []);
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleBan(String userId, bool newBanned) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newBanned ? 'Ban User?' : 'Unban User?'),
        content: Text(newBanned
            ? 'Are you sure you want to BAN this user from Yaalu? They will be unable to log in.'
            : 'Unban this user and restore access?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: newBanned ? AppColors.passRed : AppColors.onlineGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newBanned ? 'Ban User' : 'Unban'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.patch(
        Uri.parse(ApiEndpoints.adminBan(userId)),
        headers: _headers,
        body: jsonEncode({'isBanned': newBanned}),
      );
      if (res.statusCode == 200) {
        _showToast(newBanned ? 'User banned 🚫' : 'User unbanned');
        _fetchUsers(_userSearchCtrl.text);
        _fetchStats();
      }
    } catch (e) {
      _showToast('Failed to update ban status: $e');
    }
  }

  void _showGrantVipDialog(String userId, String name) {
    String selectedTier = 'vip_monthly';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.vipGold),
              const SizedBox(width: 8),
              Expanded(child: Text('Grant VIP: $name', style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select subscription tier to grant manually:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedTier,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'vip_weekly', child: Text('Weekly VIP (7 Days)')),
                  DropdownMenuItem(value: 'vip_monthly', child: Text('Monthly VIP (30 Days)')),
                  DropdownMenuItem(value: 'vip_3month', child: Text('3-Month VIP (90 Days)')),
                  DropdownMenuItem(value: 'vip_annual', child: Text('Annual VIP (365 Days)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedTier = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.vipGold),
              onPressed: () async {
                Navigator.pop(ctx);
                final days = selectedTier == 'vip_weekly'
                    ? 7
                    : selectedTier == 'vip_monthly'
                        ? 30
                        : selectedTier == 'vip_3month'
                            ? 90
                            : 365;
                try {
                  final res = await http.patch(
                    Uri.parse(ApiEndpoints.adminVip(userId)),
                    headers: _headers,
                    body: jsonEncode({'tier': selectedTier, 'durationDays': days}),
                  );
                  if (res.statusCode == 200) {
                    _showToast('VIP successfully activated! 👑');
                    _fetchUsers(_userSearchCtrl.text);
                    _fetchStats();
                  }
                } catch (e) {
                  _showToast('Failed to grant VIP: $e');
                }
              },
              child: const Text('Activate VIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approvePayment(String paymentId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Bank Transfer?'),
        content: Text('Confirm approval and activate Yaalu VIP immediately for $userName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.onlineGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve & Activate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.adminApprovePayment(paymentId)),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        _showToast('Payment approved & VIP activated! ✓');
        _fetchPayments();
        _fetchUsers(_userSearchCtrl.text);
        _fetchStats();
      }
    } catch (e) {
      _showToast('Failed to approve payment: $e');
    }
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      final res = await http.delete(
        Uri.parse(ApiEndpoints.adminDismissReport(reportId)),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        _showToast('Report dismissed');
        _fetchReports();
        _fetchStats();
      }
    } catch (e) {
      _showToast('Failed to dismiss report: $e');
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.vipGold, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yaalu Master Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                Text('Full Control & Safety Hub', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.passRed),
            tooltip: 'Exit Admin',
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.coral,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.coral,
          indicatorWeight: 3,
          tabs: [
            const Tab(icon: Icon(Icons.dashboard_rounded, size: 20), text: 'KPIs'),
            Tab(
              icon: const Icon(Icons.badge_rounded, size: 20),
              text: 'Team Staff (${_staff.length})',
            ),
            Tab(
              icon: const Icon(Icons.people_alt_rounded, size: 20),
              text: 'Users (${_users.length})',
            ),
            Tab(
              icon: const Icon(Icons.payment_rounded, size: 20),
              text: 'Payments (${_payments.where((p) => p['status'] == 'pending').length})',
            ),
            Tab(
              icon: const Icon(Icons.shield_rounded, size: 20),
              text: 'Reports (${_reports.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildKpiTab(),
                _buildStaffTab(),
                _buildUsersTab(),
                _buildPaymentsTab(),
                _buildReportsTab(),
              ],
            ),
    );
  }

  Widget _buildKpiTab() {
    final totalRevenue = _stats['totalRevenueLkr'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Revenue Highlight Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD4AF37), Color(0xFFF39C12)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxStyle.boxShadow(const Color(0xFFD4AF37).withValues(alpha: 0.3), blur: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL REVENUE GENERATED', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Icon(Icons.monetization_on_rounded, color: Colors.white, size: 28),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'LKR ${totalRevenue.toString()}',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text('From VIP subscriptions & PayHere bank transfers', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Grid KPI Cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard('Total Users', '${_stats['totalUsers'] ?? 0}', Icons.people_rounded, AppColors.coral),
            _buildStatCard('Team Staff', '${_staff.length}', Icons.badge_rounded, const Color(0xFF8B5CF6)),
            _buildStatCard('VIP Active', '${_stats['vipUsers'] ?? 0}', Icons.workspace_premium_rounded, AppColors.vipGold),
            _buildStatCard('Banned Users', '${_stats['bannedUsers'] ?? 0}', Icons.block_rounded, AppColors.passRed),
            _buildStatCard('Total Matches', '${_stats['totalMatches'] ?? 0}', Icons.favorite_rounded, const Color(0xFFE91E63)),
            _buildStatCard('Chat Messages', '${_stats['totalMessages'] ?? 0}', Icons.chat_bubble_rounded, const Color(0xFF4CAF50)),
          ],
        ),

        const SizedBox(height: 24),
        // Web Dashboard banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.laptop_chromebook_rounded, color: AppColors.coral),
                  SizedBox(width: 8),
                  Text('Laptop Web Portal URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 6),
              SelectableText(
                'http://${ApiEndpoints.activeHost}/admin',
                style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text('Open this in any browser on the same Wi-Fi network to access the desktop admin panel.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Firebase & SMS Gateway Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text('🇱🇰', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('Notify.lk SMS Gateway', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.coralLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Live / Notify.lk', style: TextStyle(color: AppColors.coral, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'High-speed Sri Lankan SMS OTP delivery powered by Notify.lk. Manage credentials in the Web Admin portal or backend/config/sms.json.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Credentials: backend/config/sms.json',
                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // --- Professional Staff & Roles Management Tab ---
  Widget _buildStaffTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Professional Header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, color: AppColors.vipGold, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'STAFF & ROLE HIERARCHY',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.vipGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_staff.length} Active',
                      style: const TextStyle(color: AppColors.vipGold, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Internal Operations Team',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Assign staff roles (Moderators, Finance, Support) with isolated security permissions.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add Staff Member', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddStaffDialog(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'Registered Staff Members',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),

        if (_staff.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Center(
              child: Text('No staff members registered yet.', style: TextStyle(color: AppColors.textSecondary)),
            ),
          )
        else
          ..._staff.map((s) => _buildStaffCard(s)),
      ],
    );
  }

  Widget _buildStaffCard(dynamic s) {
    final role = (s['role'] ?? 'moderator').toString().toLowerCase();
    final name = s['name'] ?? 'Staff Member';
    final phone = s['phone'] ?? '';
    final username = s['username'] ?? '';
    final staffId = s['id'] ?? '';
    final isOwner = role == 'super_admin' || phone == '+94786799544';

    Color roleColor;
    IconData roleIcon;
    String roleLabel;

    switch (role) {
      case 'super_admin':
        roleColor = AppColors.vipGold;
        roleIcon = Icons.workspace_premium_rounded;
        roleLabel = 'SUPER ADMIN / OWNER';
        break;
      case 'admin':
        roleColor = const Color(0xFFE65100);
        roleIcon = Icons.security_rounded;
        roleLabel = 'ADMINISTRATOR';
        break;
      case 'moderator':
        roleColor = const Color(0xFF7C3AED);
        roleIcon = Icons.shield_rounded;
        roleLabel = 'CONTENT MODERATOR';
        break;
      case 'finance':
        roleColor = AppColors.onlineGreen;
        roleIcon = Icons.account_balance_wallet_rounded;
        roleLabel = 'FINANCE / BANK SLIPS';
        break;
      case 'support':
        roleColor = const Color(0xFF0284C7);
        roleIcon = Icons.headset_mic_rounded;
        roleLabel = 'CUSTOMER SUPPORT';
        break;
      default:
        roleColor = AppColors.textSecondary;
        roleIcon = Icons.badge_rounded;
        roleLabel = role.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(roleIcon, color: roleColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(color: roleColor, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$phone • @$username',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.passRed, size: 20),
              tooltip: 'Revoke Privileges',
              onPressed: () => _removeStaffMember(staffId, name),
            ),
        ],
      ),
    );
  }

  void _showAddStaffDialog([Map<String, dynamic>? initialUser]) {
    final nameCtrl = TextEditingController(text: initialUser?['displayName'] ?? '');
    final phoneCtrl = TextEditingController(text: initialUser?['phone'] ?? '');
    final usernameCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'staff123');
    String selectedRole = 'moderator';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: AppColors.coral, size: 24),
              SizedBox(width: 8),
              Text('Add Staff Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Full Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Kasun Perera',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Mobile Phone:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '077 XXXXXXX or +947X...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Staff Username:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. kasun_mod',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Assign Role:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'moderator', child: Text('🛡️ Content Moderator')),
                    DropdownMenuItem(value: 'finance', child: Text('💳 Finance & Bank Slips')),
                    DropdownMenuItem(value: 'support', child: Text('🎧 Customer Support')),
                    DropdownMenuItem(value: 'admin', child: Text('⭐ Operations Administrator')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Staff Login Password:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final username = usernameCtrl.text.trim();
                final pass = passCtrl.text.trim();
                if (name.isEmpty || phone.isEmpty || username.isEmpty) {
                  _showToast('Please fill all fields');
                  return;
                }
                Navigator.pop(ctx);
                await _addStaffMember(
                  name: name,
                  phone: phone,
                  username: username,
                  role: selectedRole,
                  password: pass.isEmpty ? 'staff123' : pass,
                );
              },
              child: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _userSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, phone, district...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.coral),
              suffixIcon: _userSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _userSearchCtrl.clear();
                        _fetchUsers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => _fetchUsers(val),
          ),
        ),

        // User list
        Expanded(
          child: _users.isEmpty
              ? const Center(child: Text('No users found', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final u = _users[index];
                    final isVerified = u['isVerified'] == true;
                    final isBanned = u['isBanned'] == true;
                    final tier = (u['subscriptionTier'] ?? 'free').toString();
                    final isVip = tier.startsWith('vip');
                    final photos = (u['photos'] as List<dynamic>?) ?? [];
                    final photoUrl = photos.isNotEmpty ? ApiEndpoints.resolveImageUrl(photos[0].toString()) : '';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isBanned ? AppColors.passRed : AppColors.borderLight),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.coralLight,
                                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                child: photoUrl.isEmpty ? Text(u['displayName']?[0] ?? '?', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.coral)) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            u['displayName'] ?? 'Unnamed',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isVerified) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 16),
                                        ],
                                        if (isVip) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.workspace_premium_rounded, color: AppColors.vipGold, size: 16),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${u['phone'] ?? ''} • ${u['homeDistrict'] ?? 'Sri Lanka'} • ${u['gender'] ?? ''}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (isBanned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('BANNED', style: TextStyle(color: AppColors.passRed, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Make Staff
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: AppColors.coral,
                                  side: const BorderSide(color: AppColors.coral),
                                ),
                                icon: const Icon(Icons.badge_outlined, size: 14),
                                label: const Text('+ Staff', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _showAddStaffDialog(u),
                              ),
                              const SizedBox(width: 6),

                              // Grant VIP
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: const Color(0xFFFFF8E1),
                                  foregroundColor: const Color(0xFFD97706),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.star_rounded, size: 14),
                                label: Text(isVip ? 'Update VIP' : '+VIP', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _showGrantVipDialog(u['id'], u['displayName'] ?? 'User'),
                              ),
                              const SizedBox(width: 6),

                              // Ban / Unban
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: isBanned ? const Color(0xFFE8F5E9) : const Color(0xFFFEE2E2),
                                  foregroundColor: isBanned ? AppColors.onlineGreen : AppColors.passRed,
                                  elevation: 0,
                                ),
                                icon: Icon(isBanned ? Icons.check_circle_rounded : Icons.block_rounded, size: 14),
                                label: Text(isBanned ? 'Unban' : 'Ban', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _toggleBan(u['id'], !isBanned),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return const Center(child: Text('No payment records found', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final p = _payments[index];
        final isSuccess = p['status'] == 'success';
        final isPending = p['status'] == 'pending';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isPending ? AppColors.vipGold : AppColors.borderLight),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p['userName'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (p['status'] ?? '').toString().toUpperCase(),
                      style: TextStyle(
                        color: isSuccess ? AppColors.onlineGreen : const Color(0xFFD97706),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'LKR ${p['amount'] ?? 0} • ${(p['tier'] ?? '').toString().replaceAll('vip_', '').toUpperCase()} VIP',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.coral),
              ),
              const SizedBox(height: 2),
              Text(
                'Bank: ${p['bankName'] ?? p['provider'] ?? 'Bank Transfer'} | Ref: ${p['referenceCode'] ?? p['slipNote'] ?? 'None'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (isPending) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.onlineGreen),
                    onPressed: () => _approvePayment(p['id'], p['userName'] ?? 'User'),
                    child: const Text('Approve Bank Transfer & Activate VIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsTab() {
    if (_reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.onlineGreen, size: 48),
            SizedBox(height: 12),
            Text('No Pending Safety Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Community is 100% clean and safe.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final r = _reports[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.passRed.withValues(alpha: 0.3)),
            boxShadow: AppColors.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reported: ${r['reportedName'] ?? 'User'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.passRed)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                    child: Text((r['reason'] ?? '').toString().toUpperCase(), style: const TextStyle(color: AppColors.passRed, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Reported by: ${r['reporterName'] ?? 'User'}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (r['description'] != null) ...[
                const SizedBox(height: 6),
                Text('"${r['description']}"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _dismissReport(r['id']),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.passRed),
                    onPressed: () => _toggleBan(r['reportedUserId'], true),
                    child: const Text('Ban User', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class BoxStyle {
  static BoxShadow boxShadow(Color color, {double blur = 8, Offset offset = Offset.zero}) {
    return BoxShadow(color: color, blurRadius: blur, offset: offset);
  }
}
