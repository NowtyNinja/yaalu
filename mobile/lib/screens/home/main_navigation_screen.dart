import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../discovery/discovery_screen.dart';
import '../search/search_screen.dart';
import '../chat/chat_list_screen.dart';
import '../vip/vip_paywall_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DiscoveryScreen(),
    SearchScreen(),
    ChatListScreen(),
    VipPaywallScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.borderLight, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BottomNavigationBar(
              backgroundColor: Colors.white,
              elevation: 0,
              currentIndex: _currentIndex,
              selectedItemColor: AppColors.coral,
              unselectedItemColor: AppColors.textMuted,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: -0.2),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
              type: BottomNavigationBarType.fixed,
              onTap: (index) => setState(() => _currentIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.style_outlined, size: 24),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.style_rounded, color: AppColors.coral, size: 25),
                  ),
                  label: 'Discover',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.search_rounded, size: 24),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.saved_search_rounded, color: AppColors.coral, size: 26),
                  ),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 23),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.chat_bubble_rounded, color: AppColors.coral, size: 24),
                  ),
                  label: 'Chats',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.workspace_premium_outlined, size: 24),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.workspace_premium_rounded, color: AppColors.vipGold, size: 25),
                  ),
                  label: 'VIP',
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.person_outline_rounded, size: 24),
                  ),
                  activeIcon: Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Icon(Icons.person_rounded, color: AppColors.coral, size: 25),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
