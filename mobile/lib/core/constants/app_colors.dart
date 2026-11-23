import 'package:flutter/material.dart';

class AppColors {
  // Brand Identity Colors - Modern High-Energy & Premium
  static const Color coral = Color(0xFFFF1A53); // Signature Vibrant Electric Rose
  static const Color coralLight = Color(0xFFFFF0F4); // Soft Velvet Tint
  static const Color coralDark = Color(0xFFE0003A); // Deep Crimson Rose
  
  // Canvas & Surfaces (Modern Porcelain & Crystal)
  static const Color background = Color(0xFFF8F9FD); // Crisp cloud-porcelain background
  static const Color cardBg = Color(0xFFFFFFFF); // Pure crystal white
  static const Color surface = Color(0xFFF1F3F9); // Sleek surface fill
  static const Color surfaceInput = Color(0xFFF4F6FB); // Modern input background
  static const Color borderLight = Color(0xFFE6E9F2); // Subtle crisp borders
  static const Color dividerColor = Color(0xFFEDF0F7); // Soft dividers

  // Typography - High Contrast Editorial Readability
  static const Color textPrimary = Color(0xFF0C0D12); // Deep rich obsidian
  static const Color textSecondary = Color(0xFF505668); // Cool slate body
  static const Color textMuted = Color(0xFF8B92A5); // Elegant secondary grey
  static const Color pureWhite = Color(0xFFFFFFFF); // Pure white
  static const Color obsidianBlack = Color(0xFF090A0E); // Pure deep dark accent

  // Accents & Signals
  static const Color vipGold = Color(0xFFFFB300); // 24k Amber Gold
  static const Color vipGoldLight = Color(0xFFFFF8E1); // Soft Warm Gold
  static const Color superLikeBlue = Color(0xFF00A8FF); // Electric Cyan
  static const Color superLikeBlueLight = Color(0xFFE5F6FF);
  static const Color onlineGreen = Color(0xFF00D664); // Electric Mint Active
  static const Color passRed = Color(0xFFFF334B); // Modern Passion Red
  static const Color passRedLight = Color(0xFFFFEBEF);

  // Backward-compatibility aliases
  static const Color midnightNavy = background;
  static const Color cardNavy = cardBg;
  static const Color surfaceNavy = surface;

  // Modern Signature Gradients
  static const LinearGradient coralGradient = LinearGradient(
    colors: [Color(0xFFFF1A53), Color(0xFFFF5277)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF1A53), Color(0xFFFF7A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vipGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF0F1117), Color(0xFF1E222D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Modern Diffused Ambient Drop Shadows
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF0C0D12).withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: const Color(0xFF0C0D12).withValues(alpha: 0.08),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: coral.withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 7),
    ),
  ];

  static List<BoxShadow> get vipGlow => [
    BoxShadow(
      color: vipGold.withValues(alpha: 0.4),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
