import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/profile_model.dart';
import 'widgets/match_dialog.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  int _photoIndex = 0;
  double _distanceFilter = 50.0;
  int _minAge = 18;
  int _maxAge = 45;
  Offset _dragOffset = Offset.zero;

  void _triggerSwipe(String targetUserId, String action) {
    setState(() {
      _photoIndex = 0;
      _dragOffset = Offset.zero;
    });
    context.read<DiscoveryProvider>().swipe(
      targetUserId,
      action,
      superLikeMessage: action == 'superlike' ? 'Hey! Loved your profile ✨' : null,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoveryProvider>().fetchDiscoveryStack(
            distance: _distanceFilter,
            minAge: _minAge,
            maxAge: _maxAge,
          );
    });
  }

  void _showFilterDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Discovery Filters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Distance Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Maximum Distance', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  Text(
                    '${_distanceFilter.toInt()} km',
                    style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: _distanceFilter,
                min: 5,
                max: 150,
                divisions: 29,
                activeColor: AppColors.coral,
                inactiveColor: AppColors.borderLight,
                onChanged: (val) {
                  setModalState(() => _distanceFilter = val);
                  setState(() => _distanceFilter = val);
                },
              ),
              const SizedBox(height: 12),

              // Age Range
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Age Preference', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                  Text(
                    '$_minAge - $_maxAge',
                    style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
                min: 18,
                max: 60,
                divisions: 42,
                activeColor: AppColors.coral,
                inactiveColor: AppColors.borderLight,
                onChanged: (values) {
                  setModalState(() {
                    _minAge = values.start.toInt();
                    _maxAge = values.end.toInt();
                  });
                  setState(() {
                    _minAge = values.start.toInt();
                    _maxAge = values.end.toInt();
                  });
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.read<DiscoveryProvider>().fetchDiscoveryStack(
                          distance: _distanceFilter,
                          minAge: _minAge,
                          maxAge: _maxAge,
                        );
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDetailModal(ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull indicator
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

              // Name & Verified Badge
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${profile.displayName}, ${profile.age}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.verified_rounded, color: Color(0xFF00B0FF), size: 24),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Location & Distance
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.coral, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${profile.homeDistrict ?? profile.city} • ${profile.distanceKm} km away',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Date Rating & Safety Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.vipGoldLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.vipGold.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.vipGold, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile.rating} / 5.0 Rating • ${profile.ratingBadge}',
                            style: const TextStyle(
                              color: Color(0xFF996500),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Verified respectful behavior by mutual Yaalu date feedback',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 32),

              // Bio
              const Text('About Me', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                profile.bio,
                style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 22),

              // Looking For
              const Text('Looking For', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
                ),
                child: Text(
                  profile.datingIntention.toUpperCase(),
                  style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(height: 22),

              // Interests
              const Text('Passions & Interests', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.interests.map((interest) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<DiscoveryProvider>();
    final auth = context.watch<AuthProvider>();

    // Listen for mutual matches
    if (discovery.hasNewMatch && discovery.latestMatchedProfile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => MatchDialog(
            matchedProfile: discovery.latestMatchedProfile!,
            match: discovery.latestMatch,
            onDismiss: () => discovery.dismissMatchDialog(),
          ),
        );
      });
    }

    final profiles = discovery.profiles;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded, color: AppColors.coral, size: 20),
              ),
            ],
          ),
        ),
        title: const Text(
          'Yaalu',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 26,
            letterSpacing: -1.2,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Remaining Swipes Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.coral, size: 16),
                const SizedBox(width: 4),
                Text(
                  auth.isVip ? 'VIP' : '${discovery.remainingSwipes}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: auth.isVip ? AppColors.vipGold : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
            onPressed: _showFilterDrawer,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: discovery.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.coral))
          : profiles.isEmpty
              ? _buildEmptyDeckView()
              : _buildCardStack(profiles[0]),
    );
  }

  Widget _buildCardStack(ProfileModel current) {
    final photos = current.photos;
    final currentPhoto = photos.isNotEmpty ? ApiEndpoints.resolveImageUrl(photos[_photoIndex % photos.length]) : '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() => _dragOffset += details.delta);
                },
                onPanEnd: (details) {
                  final dx = _dragOffset.dx;
                  final dy = _dragOffset.dy;
                  const threshold = 85.0;

                  if (dy < -110 && dx.abs() < 90) {
                    _triggerSwipe(current.userId, 'superlike');
                  } else if (dx > threshold) {
                    _triggerSwipe(current.userId, 'right');
                  } else if (dx < -threshold) {
                    _triggerSwipe(current.userId, 'left');
                  } else {
                    setState(() => _dragOffset = Offset.zero);
                  }
                },
                onTapUp: (details) {
                  if (_dragOffset.distance > 10) return;
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.localPosition.dx > screenWidth / 2) {
                    if (photos.isNotEmpty) {
                      setState(() => _photoIndex = (_photoIndex + 1) % photos.length);
                    }
                  } else {
                    if (photos.isNotEmpty && _photoIndex > 0) {
                      setState(() => _photoIndex -= 1);
                    }
                  }
                },
                child: Transform.translate(
                  offset: _dragOffset,
                  child: Transform.rotate(
                    angle: _dragOffset.dx / 1200,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white,
                        image: currentPhoto.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(currentPhoto),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Real-time Visual Stamps for Swipe
                          if (_dragOffset.dx > 25)
                            Positioned(
                              top: 40,
                              left: 24,
                              child: Transform.rotate(
                                angle: -0.25,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF00E676), width: 3.5),
                                    color: Colors.black45,
                                  ),
                                  child: const Text(
                                    'LIKE ❤️',
                                    style: TextStyle(
                                      color: Color(0xFF00E676),
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          if (_dragOffset.dx < -25)
                            Positioned(
                              top: 40,
                              right: 24,
                              child: Transform.rotate(
                                angle: 0.25,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.passRed, width: 3.5),
                                    color: Colors.black45,
                                  ),
                                  child: const Text(
                                    'NOPE ✕',
                                    style: TextStyle(
                                      color: AppColors.passRed,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          if (_dragOffset.dy < -35 && _dragOffset.dx.abs() < 60)
                            Positioned(
                              top: 50,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.superLikeBlue, width: 3.5),
                                    color: Colors.black54,
                                  ),
                                  child: const Text(
                                    'SUPER LIKE ⭐',
                                    style: TextStyle(
                                      color: AppColors.superLikeBlue,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      // Gradient Vignette for readable overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.45, 1.0],
                          ),
                        ),
                      ),

                      // Photo Progress Indicators
                      if (photos.length > 1)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Row(
                            children: List.generate(photos.length, (index) {
                              final isActive = index == (_photoIndex % photos.length);
                              return Expanded(
                                child: Container(
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.white : Colors.white38,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                      // Profile Info Overlay
                      Positioned(
                        bottom: 16,
                        left: 18,
                        right: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Verified Date Rating Pill
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.vipGold.withValues(alpha: 0.7), width: 0.9),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: AppColors.vipGold, size: 15),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${current.rating} • ${current.ratingBadge}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.vipGold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Name, Age, Verification & Info Icon
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${current.displayName}, ${current.age}',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      if (current.isVerified) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: Color(0xFF00B0FF),
                                          size: 22,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  onPressed: () => _showProfileDetailModal(current),
                                ),
                              ],
                            ),

                            // District & Distance
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: AppColors.coral, size: 15),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${current.homeDistrict ?? current.city} • ${current.distanceKm} km',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Bio Preview
                            Text(
                              current.bio,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

            // Modern Light Controls Dock (Rewind, Pass, SuperLike, Like)
            _buildActionDock(current.userId),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildActionDock(String targetUserId) {
    final discovery = context.watch<DiscoveryProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Rewind / Reverse
        _buildCircleButton(
          icon: Icons.replay_rounded,
          color: discovery.canRewind ? AppColors.vipGold : AppColors.textMuted.withValues(alpha: 0.5),
          size: 50,
          tooltip: 'Rewind skipped profile',
          onTap: () async {
            if (!discovery.canRewind) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No previous profile to rewind.'),
                  duration: Duration(milliseconds: 900),
                ),
              );
              return;
            }
            setState(() => _photoIndex = 0);
            final success = await discovery.rewind();
            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⏪ Restored previously skipped profile!'),
                  duration: Duration(milliseconds: 900),
                ),
              );
            }
          },
        ),

        // Pass / Skip (Swipe Left)
        _buildCircleButton(
          icon: Icons.close_rounded,
          color: AppColors.passRed,
          size: 60,
          tooltip: 'Skip profile',
          onTap: () => _triggerSwipe(targetUserId, 'left'),
        ),

        // Super Like (Super Yaalu)
        _buildCircleButton(
          icon: Icons.star_rounded,
          color: AppColors.superLikeBlue,
          size: 50,
          tooltip: 'Super Like',
          onTap: () => _triggerSwipe(targetUserId, 'superlike'),
        ),

        // Like (Swipe Right) - Radiant Coral Gradient Button
        _buildCircleButton(
          icon: Icons.favorite_rounded,
          color: Colors.white,
          size: 64,
          isPrimary: true,
          tooltip: 'Like & Match',
          onTap: () => _triggerSwipe(targetUserId, 'right'),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
    String? tooltip,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: isPrimary ? AppColors.coralGradient : null,
              color: isPrimary ? null : Colors.white,
              shape: BoxShape.circle,
              border: isPrimary ? null : Border.all(color: AppColors.borderLight, width: 1.2),
              boxShadow: isPrimary
                  ? AppColors.buttonShadow
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Center(
              child: Icon(icon, color: color, size: size * 0.48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDeckView() {
    final discovery = context.watch<DiscoveryProvider>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
                boxShadow: AppColors.softShadow,
              ),
              child: const Icon(Icons.travel_explore_rounded, size: 60, color: AppColors.coral),
            ),
            const SizedBox(height: 24),
            const Text(
              'No More Profiles Nearby',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Expand your distance radius or try Yaalu Passport to explore other cities worldwide!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (discovery.canRewind) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.replay_rounded, color: AppColors.vipGold),
                label: const Text('Rewind Last Profile', style: TextStyle(color: AppColors.vipGold)),
                onPressed: () => discovery.rewind(),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: _showFilterDrawer,
              child: const Text('Adjust Discovery Radius'),
            ),
          ],
        ),
      ),
    );
  }
}
