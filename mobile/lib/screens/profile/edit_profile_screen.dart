import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_image_picker.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  int _uploadingSlot = -1;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _occupationController;
  late TextEditingController _educationController;

  late List<String> _photos;
  late DateTime _birthDate;
  late String _gender;
  late String _datingIntention;
  late String _homeDistrict;
  late List<String> _selectedInterests;

  bool _isSaving = false;

  final List<String> _allDistricts = [
    'Colombo',
    'Gampaha',
    'Kandy',
    'Galle',
    'Matara',
    'Jaffna',
    'Kurunegala',
    'Negombo',
    'Badulla',
    'Kalutara',
    'Anuradhapura',
    'Ratnapura',
    'Batticaloa',
    'Nuwara Eliya',
    'Trincomalee',
    'Hambantota',
    'Matale',
    'Puttalam',
    'Kegalle',
    'Monaragala',
    'Polonnaruwa',
    'Ampara',
    'Mannar',
    'Vavuniya',
    'Kilinochchi',
    'Mullaitivu',
    'Diaspora (UK)',
    'Diaspora (Australia)',
    'Diaspora (Canada)',
    'Diaspora (USA)',
  ];

  final List<String> _availableInterests = [
    'Beach Trips 🏖️',
    'Kottu Lover 🥘',
    'Cricket 🏏',
    'Surfing 🏄',
    'Acoustic Music 🎸',
    'Photography 📷',
    'Hiking & Knuckles ⛰️',
    'Tech & Startups 💻',
    'Ceylon Tea ☕',
    'Fashion 👗',
    'Art & Design 🎨',
    'Fitness & Gym 🏋️',
    'Foodie & Cafes 🍜',
    'Road Trips 🚗',
    'Cat Lover 🐱',
    'Dog Lover 🐶',
    'Books & Reading 📚',
    'Cooking & Baking 🍳',
  ];

  final List<Map<String, String>> _presetAvatars = [
    {
      'title': 'Studio Chic',
      'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80',
    },
    {
      'title': 'Warm Sunset',
      'url': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&q=80',
    },
    {
      'title': 'Urban Casual',
      'url': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&q=80',
    },
    {
      'title': 'Clean Portrait',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80',
    },
    {
      'title': 'Golden Hour',
      'url': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&q=80',
    },
    {
      'title': 'Cafe Aesthetic',
      'url': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=800&q=80',
    },
    {
      'title': 'Ocean Breeze',
      'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=800&q=80',
    },
    {
      'title': 'Vibrant Smile',
      'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&q=80',
    },
    {
      'title': 'Chic Travel',
      'url': 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=800&q=80',
    },
    {
      'title': 'Editorial Style',
      'url': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=80',
    },
    {
      'title': 'Minimalist',
      'url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=80',
    },
    {
      'title': 'Smart Casual',
      'url': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=80',
    },
    {
      'title': 'Nature & Outdoor',
      'url': 'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=800&q=80',
    },
    {
      'title': 'Relaxed Smile',
      'url': 'https://images.unsplash.com/photo-1463453091185-61582044d556?w=800&q=80',
    },
    {
      'title': 'Artistic Glow',
      'url': 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=800&q=80',
    },
    {
      'title': 'Coffee Lounge',
      'url': 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=800&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;

    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _occupationController = TextEditingController(text: profile?.occupation ?? '');
    _educationController = TextEditingController(text: profile?.education ?? '');

    _photos = List<String>.from(profile?.photos ?? []);
    if (_photos.isEmpty) {
      _photos.add('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80');
    }

    if (profile?.birthDate != null && profile!.birthDate!.isNotEmpty) {
      try {
        _birthDate = DateTime.parse(profile.birthDate!);
      } catch (_) {
        _birthDate = DateTime.now().subtract(Duration(days: 365 * (profile.age)));
      }
    } else {
      _birthDate = DateTime.now().subtract(Duration(days: 365 * (profile?.age ?? 22)));
    }

    _gender = profile?.gender ?? 'female';
    _datingIntention = profile?.datingIntention ?? 'dating';
    _homeDistrict = profile?.homeDistrict ?? profile?.city ?? 'Colombo';
    _selectedInterests = List<String>.from(profile?.interests ?? ['Beach Trips 🏖️', 'Kottu Lover 🥘']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _occupationController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  int get _calculatedAge {
    final now = DateTime.now();
    int age = now.year - _birthDate.year;
    if (now.month < _birthDate.month ||
        (now.month == _birthDate.month && now.day < _birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickAndUploadPhoto(int index, bool fromCamera) async {
    try {
      final String? pickedPath = fromCamera
          ? await NativeImagePicker.takePhoto()
          : await NativeImagePicker.pickFromGallery();

      if (pickedPath == null || pickedPath.isEmpty) return;

      setState(() => _uploadingSlot = index);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Uploading photo directly to server...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      final res = await ApiService.uploadMultipart(
        ApiEndpoints.uploadPhoto,
        pickedPath,
        fieldName: 'photo',
      );

      if (res['success'] == true && res['data'] != null && res['data']['photoUrl'] != null) {
        final photoUrl = res['data']['photoUrl'] as String;
        _updatePhotoAt(index, photoUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Photo uploaded directly from device!'),
              backgroundColor: AppColors.onlineGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(res['message'] ?? 'Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.passRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingSlot = -1);
      }
    }
  }

  void _showPhotoManagementModal(int index) {
    final hasPhoto = index < _photos.length;
    final currentUrl = hasPhoto ? _photos[index] : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasPhoto ? 'Change Photo (Slot ${index + 1})' : 'Add Photo (Slot ${index + 1})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (hasPhoto && _photos.length > 1)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _photos.removeAt(index);
                            });
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.delete_outline, color: AppColors.passRed, size: 18),
                          label: const Text('Remove', style: TextStyle(color: AppColors.passRed, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Directly snap a photo with your Camera or pick from your Phone Gallery.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),

                  // Direct Action 1: Gallery Upload
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndUploadPhoto(index, false);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF90CAF9)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.photo_library_rounded, color: Color(0xFF1976D2), size: 28),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose from Phone Gallery',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Direct upload from your device albums & photos',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1976D2)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Direct Action 2: Camera Capture
                  InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndUploadPhoto(index, true);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.coralLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.camera_alt_rounded, color: AppColors.coral, size: 28),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Take Photo with Camera',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Take a live selfie or fresh portrait right now',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.coral),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR USE OTHER METHODS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Option 1: Custom URL Input
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.link_rounded, color: AppColors.coral, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Paste Custom Photo URL',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: currentUrl),
                                decoration: InputDecoration(
                                  hintText: 'https://images.unsplash.com/...',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    _updatePhotoAt(index, val.trim());
                                    Navigator.of(ctx).pop();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                  const Text(
                    'Curated Aesthetics & Avatars',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  // Preset Gallery Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _presetAvatars.length,
                    itemBuilder: (context, i) {
                      final item = _presetAvatars[i];
                      final isSelected = currentUrl == item['url'];

                      return GestureDetector(
                        onTap: () {
                          _updatePhotoAt(index, item['url']!);
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.coral : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  item['url']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                      ),
                                    ),
                                    child: Text(
                                      item['title']!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppColors.coral,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updatePhotoAt(int index, String url) {
    setState(() {
      if (index < _photos.length) {
        _photos[index] = url;
      } else {
        _photos.add(url);
      }
    });
  }

  void _makePhotoMain(int index) {
    if (index == 0 || index >= _photos.length) return;
    setState(() {
      final selected = _photos.removeAt(index);
      _photos.insert(0, selected);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⭐ Photo set as Primary Profile Picture!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display Name cannot be empty')),
      );
      return;
    }

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least 1 profile photo')),
      );
      return;
    }

    if (_calculatedAge < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be at least 18 years old')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final updateData = {
      'displayName': name,
      'bio': _bioController.text.trim().isEmpty
          ? 'Ready to connect and discover great moments ✨'
          : _bioController.text.trim(),
      'birthDate': _birthDate.toIso8601String().split('T')[0],
      'age': _calculatedAge,
      'gender': _gender,
      'datingIntention': _datingIntention,
      'homeDistrict': _homeDistrict,
      'interests': _selectedInterests,
      'photos': _photos,
      'occupation': _occupationController.text.trim(),
      'education': _educationController.text.trim(),
    };

    final success = await auth.updateProfile(updateData);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Profile updated successfully!'),
          backgroundColor: AppColors.onlineGreen,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to update profile. Please try again.'),
          backgroundColor: AppColors.passRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                    )
                  : const Icon(Icons.check_circle_rounded, color: AppColors.coral, size: 20),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(color: AppColors.coral, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photos Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile Photos (Up to 6)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.coralLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_photos.length}/6 Photos',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'First photo is your main profile picture. Tap a slot to change or add.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),

              // 6-Photo Smart Grid (3 cols x 2 rows)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.76,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final isSlotFilled = index < _photos.length;
                  final isMainPhoto = index == 0;
                  final isUploading = _uploadingSlot == index;

                  if (isUploading) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.coral, width: 2),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.coral, strokeWidth: 2.5),
                            SizedBox(height: 8),
                            Text(
                              'Uploading...',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.coral),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (isSlotFilled) {
                    final photoUrl = ApiEndpoints.resolveImageUrl(_photos[index]);
                    return GestureDetector(
                      onTap: () => _showPhotoManagementModal(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isMainPhoto ? AppColors.coral : AppColors.borderLight,
                            width: isMainPhoto ? 2.5 : 1.2,
                          ),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                              // Slot Badge
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isMainPhoto ? AppColors.coral : Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isMainPhoto ? 'MAIN' : '#${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              // Delete Button
                              if (_photos.length > 1)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _photos.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              // "Set Main" quick pill if secondary
                              if (!isMainPhoto)
                                Positioned(
                                  bottom: 6,
                                  left: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _makePhotoMain(index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '⭐ Make Main',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.coral,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    // Empty Slot
                    return GestureDetector(
                      onTap: () => _showPhotoManagementModal(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.4),
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppColors.coralLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, color: AppColors.coral, size: 20),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add Photo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.coral,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 28),

              // Basic Info Section
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),

              // Display Name
              const Text('Display Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                ),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Kasuni, Dineth',
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.coral),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Birthday (Date of Birth) & Age
              const Text('Birthday (Date of Birth)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthDate,
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                    helpText: 'SELECT YOUR BIRTHDAY (18+ ONLY)',
                    builder: (ctx, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.coral,
                            onPrimary: Colors.white,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _birthDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.coralLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cake_rounded, color: AppColors.coral, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tap to update birth date',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_calculatedAge Years Old',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Gender Selector
              const Text('Gender', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildGenderChip('Female', 'female', Icons.female_rounded),
                  const SizedBox(width: 10),
                  _buildGenderChip('Male', 'male', Icons.male_rounded),
                  const SizedBox(width: 10),
                  _buildGenderChip('Non-binary', 'non-binary', Icons.transgender_rounded),
                ],
              ),
              const SizedBox(height: 24),

              // Bio
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('About Me (Bio)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(
                    '${_bioController.text.length}/500',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                ),
                child: TextField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Share a little about who you are, what brings you joy, or what kind of connection you are looking for...',
                    fillColor: Colors.white,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Dating Intention
              const Text(
                'Dating Intention',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text('Be transparent about what you are currently looking for.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildIntentionChip('casual', '🎉 Casual & Fun'),
                  _buildIntentionChip('dating', '🌹 Dates & Romance'),
                  _buildIntentionChip('serious', '💍 Serious Relationship'),
                  _buildIntentionChip('coffee', '☕ Coffee & Chat'),
                  _buildIntentionChip('friendship', '🤝 New Friends'),
                  _buildIntentionChip('travel', '✈️ Travel Companion'),
                ],
              ),
              const SizedBox(height: 24),

              // Sri Lanka District
              const Text(
                'Home District / Diaspora',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _allDistricts.contains(_homeDistrict) ? _homeDistrict : _allDistricts[0],
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.coral),
                    items: _allDistricts.map((d) {
                      return DropdownMenuItem<String>(
                        value: d,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18, color: AppColors.coral),
                            const SizedBox(width: 8),
                            Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _homeDistrict = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Lifestyle Interests
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Interests & Hobbies',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    '${_selectedInterests.length}/10 selected',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Pick what you love doing to find better conversational matches.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          if (_selectedInterests.length < 10) {
                            _selectedInterests.add(interest);
                          }
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                    selectedColor: AppColors.coralLight,
                    checkmarkColor: AppColors.coral,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.coral : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.coral : AppColors.borderLight,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Career & Education
              const Text(
                'Career & Education',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 14),

              // Occupation
              const Text('Occupation / Work', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                ),
                child: TextField(
                  controller: _occupationController,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Software Engineer, Doctor, Creative',
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.work_outline_rounded, color: AppColors.coral),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Education
              const Text('Education / College', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                ),
                child: TextField(
                  controller: _educationController,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'e.g. University of Colombo, SLIIT',
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.school_outlined, color: AppColors.coral),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Bottom Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Profile Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String label, String value, IconData icon) {
    final isSelected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.coralLight : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.coral : AppColors.borderLight,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.coral : AppColors.textSecondary, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.coral : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntentionChip(String value, String label) {
    final isSelected = _datingIntention == value;
    return GestureDetector(
      onTap: () => setState(() => _datingIntention = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coralLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.coral : AppColors.borderLight,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.coral : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
