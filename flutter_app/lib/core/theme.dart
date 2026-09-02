import 'package:flutter/material.dart';

/// 主题: 与 iOS 版 ThemeManager 对齐的品牌色 + 双主题
class AppColors {
  static const brandGreen = Color(0xFF34D399);
  static const brandGreenDark = Color(0xFF059669);
  static const brandBlue = Color(0xFF60A5FA);
  static const brandOrange = Color(0xFFFB923C);
  static const brandRed = Color(0xFFF87171);
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandGreen,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: AppColors.brandGreen,
      secondary: AppColors.brandBlue,
      error: AppColors.brandRed,
    ),
    scaffoldBackgroundColor: isDark ? const Color(0xFF161B26) : const Color(0xFFF2F4F8),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF1D2433) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20)),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF161B26) : const Color(0xFFF2F4F8),
      surfaceTintColor: Colors.transparent,
      foregroundColor: isDark ? Colors.white : Colors.black87,
    ),
    dividerTheme: DividerThemeData(color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

/// 卡片容器 (对齐 iOS cardStyle)
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: padding, child: child));
  }
}
