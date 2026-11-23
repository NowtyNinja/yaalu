import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/api_service.dart';
import '../../core/services/native_image_picker.dart';
import '../../providers/auth_provider.dart';
import 'ai_liveness_check_screen.dart';

class ProfileBuilderScreen extends StatefulWidget {
  const ProfileBuilderScreen({super.key});

  @override
  State<ProfileBuilderScreen> createState() => _ProfileBuilderScreenState();
}

class _ProfileBuilderScreenState extends State<ProfileBuilderScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime _birthDate = DateTime(2002, 6, 15);
  String _gender = 'female';
  String _intention = 'dating';
  String _homeDistrict = 'Colombo';
  final List<String> _selectedInterests = ['Beach Trips', 'Kottu Lover'];

  // Real Uploaded Photos
  final List<String> _photos = [];
  int _uploadingSlot = -1;

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
  ];

  int get _calculatedAge {
    final now = DateTime.now();
    int age = now.year - _birthDate.year;
    if (now.month < _birthDate.month ||
        (now.month == _birthDate.month && now.day < _birthDate.day)) {
      age--;
    }
    return age;
  }

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

  final List<String> _allInterests = [
    'Beach Trips',
    'Kottu Lover',
    'Cricket',
    'Surfing',
    'Acoustic Music',
    'Photography',
    'Hiking & Knuckles',
    'Tech & Startups',
    'Ceylon Tea',
    'Fashion',
    'Art & Design',
    'Fitness & Gym',
    'Foodie & Cafes',
    'Road Trips',
    'Cat Lover',
    'Dog Lover',
  ];

  final List<String> _intentions = [
    'casual',
    'dating',
    'coffee',
    'serious',
    'friendship',
    'travel',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
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
                Text('Uploading photo to your profile...'),
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
        setState(() {
          if (index < _photos.length) {
            _photos[index] = photoUrl;
          } else {
            _photos.add(photoUrl);
          }
        });

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

  void _showPhotoOptionsModal(int index) {
    final hasPhoto = index < _photos.length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 18),
                Text(
                  hasPhoto ? 'Change Photo (Slot ${index + 1})' : 'Add Profile Photo (Slot ${index + 1})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.coralLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.coral),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture live portrait with phone camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(index, true);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF2E7D32)),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select existing photo from device storage'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadPhoto(index, false);
                  },
                ),
                const Divider(),
                const Text(
                  'Or Pick Curated Avatar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presetAvatars.length,
                    itemBuilder: (context, i) {
                      final p = _presetAvatars[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            if (index < _photos.length) {
                              _photos[index] = p['url']!;
                            } else {
                              _photos.add(p['url']!);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.coral, width: 1.5),
                            image: DecorationImage(
                              image: NetworkImage(p['url']!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (hasPhoto) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.passRed),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove Photo'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _photos.removeAt(index);
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _proceedToAiVerification() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Please add at least 1 profile photo to continue!'),
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile({
      'displayName': name,
      'bio': _bioController.text.trim().isEmpty
          ? 'Hey there! Ready to connect on Yaalu ✨'
          : _bioController.text.trim(),
      'birthDate': _birthDate.toIso8601String().split('T')[0],
      'age': _calculatedAge,
      'gender': _gender,
      'datingIntention': _intention,
      'homeDistrict': _homeDistrict,
      'interests': _selectedInterests,
      'photos': _photos,
    });

    if (!mounted) return;

    if (success) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AiLivenessCheckScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Create Profile', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.coralLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'STEP 1 OF 2',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.coral),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add real photos and accurate info to get quality matches.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Photos Grid Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile Photos',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_photos.length}/6 photos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _photos.isEmpty ? AppColors.coral : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 6-Photo Slots (3 columns x 2 rows)
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final hasPhoto = index < _photos.length;
                  final isUploading = _uploadingSlot == index;
                  final isMain = index == 0;

                  return GestureDetector(
                    onTap: () => _showPhotoOptionsModal(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasPhoto
                              ? (isMain ? AppColors.coral : AppColors.borderLight)
                              : (_photos.isEmpty && index == 0 ? AppColors.coral : AppColors.borderLight),
                          width: (hasPhoto && isMain) || (_photos.isEmpty && index == 0) ? 2 : 1,
                        ),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasPhoto)
                              Image.network(
                                ApiEndpoints.resolveImageUrl(_photos[index]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted),
                                ),
                              )
                            else
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 26,
                                    color: (index == 0 && _photos.isEmpty) ? AppColors.coral : AppColors.textMuted,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    index == 0 ? 'Main Photo' : 'Slot ${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: (index == 0 && _photos.isEmpty) ? AppColors.coral : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),

                            // Main Badge
                            if (hasPhoto && isMain)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.coral,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '⭐ MAIN',
                                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),

                            // Loading Overlay
                            if (isUploading)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

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
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Kasuni, Dineth',
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Birthday (Date of Birth) & Auto-Calculated Age
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
                              'Tap to change birth date',
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

              // Gender
              const Text('Gender', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ['female', 'male', 'other'].map((g) {
                  final isSelected = _gender == g;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = g),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.coral : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.coral : AppColors.borderLight,
                          ),
                          boxShadow: isSelected ? AppColors.buttonShadow : AppColors.softShadow,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          g.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Dating Intention
              const Text('Looking For', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _intentions.map((intent) {
                  final isSelected = _intention == intent;
                  return ChoiceChip(
                    label: Text(intent[0].toUpperCase() + intent.substring(1)),
                    selected: isSelected,
                    selectedColor: AppColors.coral,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? AppColors.coral : AppColors.borderLight),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _intention = intent);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Home District / Region
              const Text('District / Region', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: AppColors.softShadow,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _homeDistrict,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                    items: _allDistricts.map((d) {
                      return DropdownMenuItem(value: d, child: Text(d));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _homeDistrict = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Interests
              const Text('Interests & Passions', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    selectedColor: AppColors.coralLight,
                    checkmarkColor: AppColors.coral,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? AppColors.coral : AppColors.borderLight),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.coral : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Bio
              const Text('Bio', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                ),
                child: TextField(
                  controller: _bioController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Share a bit about your passions, vibe, or ideal weekend...',
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _proceedToAiVerification,
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Next: AI Face Verification 📸'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
