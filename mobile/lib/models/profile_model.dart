class ProfileModel {
  final String id;
  final String userId;
  final String displayName;
  final int age;
  final String gender;
  final List<String> interestedIn;
  final String bio;
  final List<String> photos;
  final List<String> interests;
  final String datingIntention;
  final String? homeDistrict;
  final String? birthDate;
  final String? occupation;
  final String? education;
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final bool isPassportActive;
  final bool isStealthMode;
  final String verificationStatus;
  final double distanceKm;
  final double rating;
  final int ratingCount;
  final String ratingBadge;

  ProfileModel({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.age,
    required this.gender,
    required this.interestedIn,
    required this.bio,
    required this.photos,
    required this.interests,
    required this.datingIntention,
    this.homeDistrict,
    this.birthDate,
    this.occupation,
    this.education,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.isPassportActive,
    required this.isStealthMode,
    required this.verificationStatus,
    this.distanceKm = 0.0,
    this.rating = 5.0,
    this.ratingCount = 0,
    this.ratingBadge = '⭐ Top Rated Date',
  });

  bool get isVerified => verificationStatus == 'verified';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    return ProfileModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? '',
      age: json['age'] ?? 18,
      gender: json['gender'] ?? 'other',
      interestedIn: List<String>.from(json['interestedIn'] ?? []),
      bio: json['bio'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      datingIntention: json['datingIntention'] ?? 'dating',
      homeDistrict: json['homeDistrict'],
      birthDate: json['birthDate'],
      occupation: json['occupation'],
      education: json['education'],
      latitude: (loc['latitude'] as num?)?.toDouble() ?? 6.9271,
      longitude: (loc['longitude'] as num?)?.toDouble() ?? 79.8612,
      city: loc['city'] ?? 'Colombo',
      country: loc['country'] ?? 'Sri Lanka',
      isPassportActive: loc['isPassportActive'] ?? false,
      isStealthMode: json['isStealthMode'] ?? false,
      verificationStatus: json['verificationStatus'] ?? 'unverified',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      ratingCount: json['ratingCount'] ?? 2,
      ratingBadge: json['ratingBadge'] ?? '⭐ 100% Safe & Respectful',
    );
  }
}
