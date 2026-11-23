import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../models/profile_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class VipProvider with ChangeNotifier {
  List<PlanModel> _plans = [];
  bool _isLoading = false;
  String? _errorMessage;
  List<ProfileModel> _whoLikedMe = [];

  List<PlanModel> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ProfileModel> get whoLikedMe => _whoLikedMe;

  Future<void> fetchPlans() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.get(ApiEndpoints.paymentPlans);
      final data = res['data'] as Map<String, dynamic>;

      _plans = [
        PlanModel(
          tierKey: 'vip_weekly',
          title: data['vip_weekly']['title'],
          amountLkr: (data['vip_weekly']['amountLkr'] as num).toDouble(),
          amountUsd: (data['vip_weekly']['amountUsd'] as num).toDouble(),
        ),
        PlanModel(
          tierKey: 'vip_monthly',
          title: data['vip_monthly']['title'],
          amountLkr: (data['vip_monthly']['amountLkr'] as num).toDouble(),
          amountUsd: (data['vip_monthly']['amountUsd'] as num).toDouble(),
        ),
        PlanModel(
          tierKey: 'vip_3month',
          title: data['vip_3month']['title'],
          amountLkr: (data['vip_3month']['amountLkr'] as num).toDouble(),
          amountUsd: (data['vip_3month']['amountUsd'] as num).toDouble(),
        ),
        PlanModel(
          tierKey: 'vip_annual',
          title: data['vip_annual']['title'],
          amountLkr: (data['vip_annual']['amountLkr'] as num).toDouble(),
          amountUsd: (data['vip_annual']['amountUsd'] as num).toDouble(),
        ),
      ];
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Initiate PayHere Checkout (Sri Lanka Gateway)
  Future<Map<String, dynamic>?> initiatePayHere(String tierKey) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.post(ApiEndpoints.payhereInitiate, {'tier': tierKey});
      _isLoading = false;
      notifyListeners();
      return res['data'] as Map<String, dynamic>;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Apple & Google In-App Purchase Verification
  Future<bool> verifyIap({
    required String tierKey,
    required String platform,
    required String receiptToken,
    required String productId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await ApiService.post(ApiEndpoints.iapVerify, {
        'tier': tierKey,
        'platform': platform,
        'receiptToken': receiptToken,
        'productId': productId,
      });
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // "See Who Liked You" (VIP Feature)
  Future<void> fetchWhoLikedMe() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.get(ApiEndpoints.whoLikedMe);
      final rawList = res['data']['profiles'] as List<dynamic>? ?? [];
      _whoLikedMe = rawList.map((p) => ProfileModel.fromJson(p)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }
}
