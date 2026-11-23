class ApiEndpoints {
  // Live Production Server (Render Cloud with SSL/HTTPS)
  static String activeHost = 'yaalu-backend.onrender.com';
  static const String fallbackHost = 'yaalu-backend.onrender.com';

  static bool get isHttps => !activeHost.contains('192.168.') && !activeHost.contains('localhost') && !activeHost.contains('127.0.0.1');
  static String get scheme => isHttps ? 'https' : 'http';

  static String get baseUrl => '$scheme://$activeHost/api/v1';
  static String get socketUrl => '$scheme://$activeHost';

  // Auth
  static String get requestOtp => '$baseUrl/auth/request-otp';
  static String get verifyOtp => '$baseUrl/auth/verify-otp';
  static String get refreshToken => '$baseUrl/auth/refresh-token';
  static String get logout => '$baseUrl/auth/logout';
  static String get deleteAccount => '$baseUrl/auth/delete-account';
  static String get changePhoneRequest => '$baseUrl/auth/change-phone/request';
  static String get changePhoneVerify => '$baseUrl/auth/change-phone/verify';
  static String get recoveryEmail => '$baseUrl/auth/recovery-email';
  static String get recoverAccountRequest => '$baseUrl/auth/recover/request';
  static String get recoverAccountVerify => '$baseUrl/auth/recover/verify';

  // User & Profile
  static String get myProfile => '$baseUrl/users/me';
  static String get searchUsers => '$baseUrl/users/search';
  static String get uploadPhoto => '$baseUrl/users/upload-photo';
  static String get stealthMode => '$baseUrl/users/stealth-mode';
  static String get passport => '$baseUrl/users/passport';
  static String get boost => '$baseUrl/users/boost';
  static String get reportUser => '$baseUrl/users/report';
  static String get blockUser => '$baseUrl/users/block';

  // Discovery & Swipes
  static String get discovery => '$baseUrl/swipes/discovery';
  static String get swipe => '$baseUrl/swipes/swipe';
  static String get rewind => '$baseUrl/swipes/rewind';
  static String get whoLikedMe => '$baseUrl/swipes/who-liked-me';

  // Real-time Chat & Matches
  static String get matches => '$baseUrl/chat/matches';
  static String get messages => '$baseUrl/chat/messages';
  static String matchMessages(String matchId) => '$baseUrl/chat/matches/$matchId/messages';
  static String toggleBlur(String messageId) => '$baseUrl/chat/messages/$messageId/toggle-blur';

  // Date Rating & Safety Reviews
  static String get rateDate => '$baseUrl/users/rate-date';
  static String userRatings(String userId) => '$baseUrl/users/$userId/ratings';

  // Payments & VIP
  static String get paymentPlans => '$baseUrl/payments/plans';
  static String get payhereInitiate => '$baseUrl/payments/payhere/initiate';
  static String get iapVerify => '$baseUrl/payments/iap/verify';
  static String get bankTransfer => '$baseUrl/payments/bank-transfer';

  // AI Verification
  static String get submitVerification => '$baseUrl/verification/submit';
  static String get verificationStatus => '$baseUrl/verification/status';

  // Master Admin API
  static String get adminLogin => '$baseUrl/admin/login';
  static String get adminStats => '$baseUrl/admin/stats';
  static String adminUsers([String q = '']) => '$baseUrl/admin/users?q=${Uri.encodeComponent(q)}';
  static String adminVerify(String userId) => '$baseUrl/admin/users/$userId/verify';
  static String adminBan(String userId) => '$baseUrl/admin/users/$userId/ban';
  static String adminVip(String userId) => '$baseUrl/admin/users/$userId/vip';
  static String get adminPayments => '$baseUrl/admin/payments';
  static String adminApprovePayment(String paymentId) => '$baseUrl/admin/payments/$paymentId/approve';
  static String get adminReports => '$baseUrl/admin/reports';
  static String adminDismissReport(String reportId) => '$baseUrl/admin/reports/$reportId';

  // Switch to alternate host if connection error occurs
  static void switchHost() {
    if (activeHost == '192.168.43.199:5000') {
      activeHost = fallbackHost;
    } else {
      activeHost = '192.168.43.199:5000';
    }
  }

  // Resolves image URLs dynamically to the active host and unescapes HTML entities
  static String resolveImageUrl(String url) {
    if (url.isEmpty) return '';
    String clean = url
        .replaceAll('&amp;#x2F;', '/')
        .replaceAll('&#x2F;', '/')
        .replaceAll('&amp;', '&');

    if (clean.startsWith('/uploads/')) {
      return '$scheme://$activeHost$clean';
    }

    if (clean.contains('/uploads/')) {
      final sub = clean.substring(clean.indexOf('/uploads/'));
      return '$scheme://$activeHost$sub';
    }

    return clean;
  }
}
