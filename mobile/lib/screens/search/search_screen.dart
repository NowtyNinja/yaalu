import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../models/profile_model.dart';
import '../../providers/discovery_provider.dart';
import '../discovery/widgets/match_dialog.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ProfileModel> _searchResults = [];
  String _selectedDistrict = 'All';
  String _selectedInterest = 'All';
  bool _verifiedOnly = false;

  final List<String> _districts = const [
    'All',
    'Colombo',
    'Gampaha',
    'Kandy',
    'Galle',
    'Kurunegala',
    'Kalutara',
    'Matara',
    'Jaffna',
    'Negombo',
    'Badulla',
    'Anuradhapura',
    'Ratnapura',
  ];

  final List<String> _interests = const [
    'All',
    'Travel',
    'Tech',
    'Music',
    'Beach Trips',
    'Hiking',
    'Photography',
    'Fitness',
    'Fashion',
    'Cats',
    'Kottu Lover',
  ];

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    final query = _searchController.text.trim();

    try {
      final queryParams = <String, String>{};
      if (query.isNotEmpty) queryParams['q'] = query;
      if (_selectedDistrict != 'All') queryParams['district'] = _selectedDistrict;
      if (_selectedInterest != 'All') queryParams['interest'] = _selectedInterest;
      if (_verifiedOnly) queryParams['verifiedOnly'] = 'true';

      final uri = Uri.parse(ApiEndpoints.searchUsers).replace(queryParameters: queryParams);
      final res = await ApiService.get(uri.toString());

      final profilesData = res['data']?['profiles'] as List<dynamic>? ?? [];
      final list = profilesData.map((json) => ProfileModel.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _searchResults = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _likeUser(ProfileModel profile) async {
    final discovery = context.read<DiscoveryProvider>();
    await discovery.swipe(profile.userId, 'right');

    if (discovery.hasNewMatch && discovery.latestMatchedProfile != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => MatchDialog(
          matchedProfile: discovery.latestMatchedProfile!,
          onDismiss: () {
            discovery.dismissMatchDialog();
            Navigator.of(ctx).pop();
          },
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Liked ${profile.displayName}! ♥'),
          backgroundColor: AppColors.coral,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showProfileModal(ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Photo Carousel / Main Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      profile.photos.isNotEmpty ? ApiEndpoints.resolveImageUrl(profile.photos[0]) : '',
                      height: 340,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 340,
                        color: AppColors.surface,
                        child: const Icon(Icons.person, size: 80, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Name & Verified Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${profile.displayName}, ${profile.age}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (profile.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 16),
                              SizedBox(width: 4),
                              Text('Verified', style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Location & Distance
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.coral, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${profile.homeDistrict} • ${(profile.distanceKm).round()} km away',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Bio Card
                  if (profile.bio.isNotEmpty) ...[
                    const Text('About Me', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        profile.bio,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Interests
                  if (profile.interests.isNotEmpty) ...[
                    const Text('Interests & Passions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.interests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Text(
                            interest,
                            style: const TextStyle(color: AppColors.coral, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderLight),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Close', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _likeUser(profile);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coral,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Like & Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Explore',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderLight, width: 0.8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by name, district, interest...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.coral, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // District Chips Horizontal Scroll
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _districts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, index) {
                      final dist = _districts[index];
                      final isSelected = _selectedDistrict == dist;
                      return ChoiceChip(
                        label: Text(dist),
                        selected: isSelected,
                        selectedColor: AppColors.coralLight,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.coral : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? AppColors.coral : AppColors.borderLight,
                            width: 0.8,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedDistrict = dist);
                            _performSearch();
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Verified Only Toggle Row
                Row(
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF0284C7)),
                      label: const Text('Verified Only'),
                      selected: _verifiedOnly,
                      selectedColor: const Color(0xFFE0F2FE),
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: _verifiedOnly ? const Color(0xFF0284C7) : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: _verifiedOnly ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: _verifiedOnly ? const Color(0xFF0284C7) : AppColors.borderLight,
                        ),
                      ),
                      onSelected: (val) {
                        setState(() => _verifiedOnly = val);
                        _performSearch();
                      },
                    ),
                    const SizedBox(width: 8),
                    // Quick Interests Chip
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _interests.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (ctx, index) {
                            final interest = _interests[index];
                            final isSelected = _selectedInterest == interest;
                            return ChoiceChip(
                              label: Text(interest),
                              selected: isSelected,
                              selectedColor: AppColors.coralLight,
                              backgroundColor: AppColors.surface,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.coral : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isSelected ? AppColors.coral : AppColors.borderLight,
                                ),
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedInterest = interest);
                                  _performSearch();
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Results Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
                : _searchResults.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.all(14),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, index) {
                          final profile = _searchResults[index];
                          return _buildProfileCard(profile);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ProfileModel profile) {
    final photo = profile.photos.isNotEmpty ? ApiEndpoints.resolveImageUrl(profile.photos[0]) : '';

    return GestureDetector(
      onTap: () => _showProfileModal(profile),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderLight, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Photo
            Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surface,
                child: const Icon(Icons.person, size: 50, color: AppColors.textMuted),
              ),
            ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Top Badges
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (profile.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 14),
                          SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  // Quick Like Button
                  GestureDetector(
                    onTap: () => _likeUser(profile),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.coral, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Profile Info
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${profile.displayName}, ${profile.age}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.coralLight, size: 13),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          profile.homeDistrict ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (profile.interests.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        profile.interests[0],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.coralLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, color: AppColors.coral, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Profiles Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try clearing your search query or picking "All Districts" to see more singles across Sri Lanka.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedDistrict = 'All';
                  _selectedInterest = 'All';
                  _verifiedOnly = false;
                });
                _performSearch();
              },
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }
}
