import 'package:flutter/foundation.dart';
import '../models/profile_model.dart';
import '../models/match_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class DiscoveryProvider with ChangeNotifier {
  List<ProfileModel> _profiles = [];
  final List<ProfileModel> _history = []; // History stack for seamless undo / rewind
  bool _isLoading = false;
  String? _errorMessage;
  int _remainingSwipes = 15;
  int _superLikes = 1;
  bool _isVip = false;

  // Latest Match Popup State
  ProfileModel? _latestMatchedProfile;
  MatchModel? _latestMatch;
  bool _hasNewMatch = false;

  List<ProfileModel> get profiles => _profiles;
  bool get canRewind => _history.isNotEmpty;
  int get historyCount => _history.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get remainingSwipes => _remainingSwipes;
  int get superLikes => _superLikes;
  bool get isVip => _isVip;
  ProfileModel? get latestMatchedProfile => _latestMatchedProfile;
  MatchModel? get latestMatch => _latestMatch;
  bool get hasNewMatch => _hasNewMatch;

  Future<void> fetchDiscoveryStack({double distance = 50, int minAge = 18, int maxAge = 50}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.get(
        '${ApiEndpoints.discovery}?distance=$distance&minAge=$minAge&maxAge=$maxAge',
      );
      final data = res['data'];
      final rawList = data['profiles'] as List<dynamic>? ?? [];

      _profiles = rawList.map((p) => ProfileModel.fromJson(p)).toList();
      _isVip = data['isVip'] ?? false;
      _superLikes = data['superLikesRemaining'] ?? 1;

      if (data['remainingSwipesToday'] is int) {
        _remainingSwipes = data['remainingSwipesToday'];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Swipe / Skip Action: 'left' (pass/skip), 'right' (like), 'superlike'
  Future<bool> swipe(String targetUserId, String action, {String? superLikeMessage}) async {
    // 1. Optimistic removal & add to rewind history immediately
    final index = _profiles.indexWhere((p) => p.userId == targetUserId);
    if (index != -1) {
      final swipedProfile = _profiles.removeAt(index);
      _history.add(swipedProfile);
      if (_history.length > 30) {
        _history.removeAt(0);
      }
      notifyListeners();
    }

    try {
      final res = await ApiService.post(ApiEndpoints.swipe, {
        'targetUserId': targetUserId,
        'action': action,
        if (superLikeMessage != null) 'superLikeMessage': superLikeMessage,
      });

      final data = res['data'];
      if (data['remainingSwipesToday'] is int) {
        _remainingSwipes = data['remainingSwipesToday'];
      }

      // Check if it's a mutual match!
      if (data['isMatch'] == true) {
        if (data['matchedProfile'] != null) {
          _latestMatchedProfile = ProfileModel.fromJson(data['matchedProfile']);
          if (data['match'] != null) {
            _latestMatch = MatchModel.fromJson({
              'match': data['match'],
              'otherUserProfile': data['matchedProfile'],
            });
          }
          _hasNewMatch = true;
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Rewind / Reverse Last Skipped Profile (Zero-Latency Local Restoration)
  Future<bool> rewind() async {
    if (_history.isEmpty) return false;

    // Pop the last skipped profile and push back to top of stack
    final restoredProfile = _history.removeLast();
    _profiles.insert(0, restoredProfile);
    notifyListeners();

    // Notify backend
    try {
      await ApiService.post(ApiEndpoints.rewind, {});
    } catch (_) {
      // Free users or offline resilience: local stack already restored cleanly
    }

    return true;
  }

  void dismissMatchDialog() {
    _hasNewMatch = false;
    _latestMatchedProfile = null;
    _latestMatch = null;
    notifyListeners();
  }
}
