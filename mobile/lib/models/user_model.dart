class UserModel {
  final String id;
  final String phone;
  final String? email;
  final String role;
  final String subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final int dailySwipeCount;
  final int superLikesRemaining;
  final bool isVip;

  UserModel({
    required this.id,
    required this.phone,
    this.email,
    required this.role,
    required this.subscriptionTier,
    this.subscriptionExpiresAt,
    required this.dailySwipeCount,
    required this.superLikesRemaining,
    required this.isVip,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final tier = json['subscriptionTier'] ?? 'free';
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'user',
      subscriptionTier: tier,
      subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
          ? DateTime.tryParse(json['subscriptionExpiresAt'])
          : null,
      dailySwipeCount: json['dailySwipeCount'] ?? 0,
      superLikesRemaining: json['superLikesRemaining'] ?? 0,
      isVip: tier != 'free',
    );
  }
}
