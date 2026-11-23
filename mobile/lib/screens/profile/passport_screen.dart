import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discovery_provider.dart';

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  final List<Map<String, dynamic>> _popularDestinations = [
    {'city': 'Colombo', 'country': 'Sri Lanka', 'lat': 6.9271, 'lon': 79.8612, 'flag': '📍'},
    {'city': 'Kandy', 'country': 'Sri Lanka', 'lat': 7.2906, 'lon': 80.6337, 'flag': '📍'},
    {'city': 'Galle', 'country': 'Sri Lanka', 'lat': 6.0535, 'lon': 80.2210, 'flag': '📍'},
    {'city': 'London', 'country': 'United Kingdom', 'lat': 51.5074, 'lon': -0.1278, 'flag': '🇬🇧'},
    {'city': 'Melbourne', 'country': 'Australia', 'lat': -37.8136, 'lon': 144.9631, 'flag': '🇦🇺'},
    {'city': 'Toronto', 'country': 'Canada', 'lat': 43.6532, 'lon': -79.3832, 'flag': '🇨🇦'},
    {'city': 'Dubai', 'country': 'United Arab Emirates', 'lat': 25.2048, 'lon': 55.2708, 'flag': '🇦🇪'},
  ];

  void _teleport(Map<String, dynamic> dest) async {
    try {
      await ApiService.post(ApiEndpoints.passport, {
        'city': dest['city'],
        'country': dest['country'],
        'latitude': dest['lat'],
        'longitude': dest['lon'],
      });

      if (!mounted) return;
      await context.read<AuthProvider>().checkAuthStatus();
      await context.read<DiscoveryProvider>().fetchDiscoveryStack();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✈️ Teleported to ${dest['city']}, ${dest['country']}! Your discovery stack updated.'),
          backgroundColor: AppColors.onlineGreen,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update passport: $e')),
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
          'Yaalu Passport ✈️',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teleport Your Location',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connect with people locally or across the worldwide diaspora.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.separated(
                  itemCount: _popularDestinations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final dest = _popularDestinations[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: ListTile(
                        onTap: () => _teleport(dest),
                        leading: Text(dest['flag'], style: const TextStyle(fontSize: 28)),
                        title: Text(
                          '${dest['city']}, ${dest['country']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          'Lat: ${dest['lat']}, Lon: ${dest['lon']}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.flight_takeoff_rounded, color: AppColors.vipGold),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
