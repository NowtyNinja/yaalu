import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/profile_model.dart';
import '../core/services/api_service.dart';
import '../core/constants/api_endpoints.dart';
import '../core/security/secure_storage.dart';
import '../core/services/socket_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  ProfileModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isNewUser = false;
  String? _mockOtpHint;

  UserModel? get user => _user;
  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isNewUser => _isNewUser;
  bool get isVip => _user?.isVip ?? false;
  String? get mockOtpHint => _mockOtpHint;

  // Check existing session
  Future<bool> checkAuthStatus() async {
    final token = await SecureStorageService.getAccessToken();
    if (token == null) return false;

    try {
      final res = await ApiService.get(ApiEndpoints.myProfile);
      final data = res['data'];
      _user = UserModel.fromJson(data['user']);
      _profile = ProfileModel.fromJson(data['profile']);
      await SocketService.connect();
      notifyListeners();
      return true;
    } catch (_) {
      await SecureStorageService.clearAll();
      return false;
    }
  }

  // Request SMS OTP
  Future<bool> requestOtp(String phone) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await ApiService.post(ApiEndpoints.requestOtp, {'phone': phone});
      if (res['data'] != null && res['data']['mockOtpHint'] != null) {
        _mockOtpHint = res['data']['mockOtpHint'].toString();
      } else {
        _mockOtpHint = null;
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _mockOtpHint = null;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Verify OTP & Store Encrypted Tokens
  Future<bool> verifyOtp(String phone, String otp) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await ApiService.post(ApiEndpoints.verifyOtp, {
        'phone': phone,
        'otp': otp,
      });

      final data = res['data'];
      final tokens = data['tokens'];
      _isNewUser = data['isNewUser'] ?? false;
      _user = UserModel.fromJson(data['user']);
      _profile = ProfileModel.fromJson(data['profile']);

      await SecureStorageService.saveTokens(
        accessToken: tokens['accessToken'],
        refreshToken: tokens['refreshToken'],
        userId: _user!.id,
      );

      await SocketService.connect();

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Update Profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    _setLoading(true);
    try {
      final res = await ApiService.patch(ApiEndpoints.myProfile, updates);
      _profile = ProfileModel.fromJson(res['data']);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final refresh = await SecureStorageService.getRefreshToken();
      if (refresh != null) {
        await ApiService.post(ApiEndpoints.logout, {'refreshToken': refresh});
      }
    } catch (_) {}

    await SecureStorageService.clearAll();
    SocketService.disconnect();
    _user = null;
    _profile = null;
    notifyListeners();
  }

  // Mandatory for App Store (Guideline 5.1.1(v)) and Google Play Data Safety
  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      await ApiService.delete(ApiEndpoints.deleteAccount);
      await SecureStorageService.clearAll();
      SocketService.disconnect();
      _user = null;
      _profile = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
