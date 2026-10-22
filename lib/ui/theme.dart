import 'package:flutter/material.dart';

class AppColors {
  static const Color bg = Color(0xFFEEF1F8);
  static const Color card = Colors.white;
  static const Color primary = Color(0xFF5B5FEF);
  static const Color ink = Color(0xFF1B2140);
  static const Color muted = Color(0xFF6B7393);
  static const Color line = Color(0xFFE6E9F2);
  static const Color red = Color(0xFFE5395B);
  static const Color redBg = Color(0xFFFDE7EC);
  static const Color green = Color(0xFF1E9E63);
  static const Color greenBg = Color(0xFFE3F6EC);
}

const Map<String, IconData> categoryIcons = {
  'home': Icons.home_rounded,
  'cart': Icons.shopping_cart_rounded,
  'restaurant': Icons.restaurant_rounded,
  'car': Icons.directions_car_rounded,
  'subscriptions': Icons.subscriptions_rounded,
  'bag': Icons.shopping_bag_rounded,
  'health': Icons.local_hospital_rounded,
  'leisure': Icons.sports_esports_rounded,
  'bank': Icons.account_balance_rounded,
  'gov': Icons.gavel_rounded,
  'cash': Icons.payments_rounded,
  'transfer': Icons.swap_horiz_rounded,
  'other': Icons.more_horiz_rounded,
  'work': Icons.work_rounded,
  'refund': Icons.replay_rounded,
  'income': Icons.savings_rounded,
  'pets': Icons.pets_rounded,
  'school': Icons.school_rounded,
  'gift': Icons.card_giftcard_rounded,
  'travel': Icons.flight_rounded,
  'sport': Icons.fitness_center_rounded,
  'phone': Icons.smartphone_rounded,
  'kids': Icons.child_friendly_rounded,
  'beauty': Icons.spa_rounded,
};

const List<int> categoryColors = [
  0xFF5B7FEF, 0xFFF03E5E, 0xFFFFB300, 0xFF26A69A, 0xFF8E5BD8, 0xFFEC6FB3,
  0xFF00B8D4, 0xFFFF7043, 0xFFB78763, 0xFF7286C2, 0xFF20C05C, 0xFF90A4AE,
];

IconData iconFor(String key) => categoryIcons[key] ?? Icons.label_rounded;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
    ),
  );
}
