// สีและตัวอักษรของแอป: เขียวผิวใบทุเรียน + ทองแดงของเกล็ดใต้ใบทุเรียน
import 'package:flutter/material.dart';

@immutable
class LeafColors extends ThemeExtension<LeafColors> {
  final Color bg, surface, surface2, line, muted, leaf, bronze, bronzeSoft;
  final Color good, goodBg, warn, warnBg, bad, badBg;
  const LeafColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.muted,
    required this.leaf,
    required this.bronze,
    required this.bronzeSoft,
    required this.good,
    required this.goodBg,
    required this.warn,
    required this.warnBg,
    required this.bad,
    required this.badBg,
  });

  static const light = LeafColors(
    bg: Color(0xFFEEF2EC), surface: Color(0xFFFFFFFF), surface2: Color(0xFFE3EADE), line: Color(0xFFCDD8C8),
    muted: Color(0xFF566457), leaf: Color(0xFF1F4D33), bronze: Color(0xFF9A6A1F), bronzeSoft: Color(0xFFF1E3C7),
    good: Color(0xFF1D7A45), goodBg: Color(0xFFDFF1E5), warn: Color(0xFFA36200), warnBg: Color(0xFFFBEDD2),
    bad: Color(0xFFB3261E), badBg: Color(0xFFF9DEDB),
  );
  static const dark = LeafColors(
    bg: Color(0xFF0D1611), surface: Color(0xFF15221A), surface2: Color(0xFF1C2C22), line: Color(0xFF2A3D31),
    muted: Color(0xFF9DB0A2), leaf: Color(0xFF7FC49A), bronze: Color(0xFFD9A656), bronzeSoft: Color(0xFF3A2D17),
    good: Color(0xFF6FD39A), goodBg: Color(0xFF183A27), warn: Color(0xFFF0B45A), warnBg: Color(0xFF3D2D12),
    bad: Color(0xFFFF8A80), badBg: Color(0xFF43201D),
  );

  @override
  LeafColors copyWith() => this;

  @override
  LeafColors lerp(ThemeExtension<LeafColors>? other, double t) => t < 0.5 ? this : (other as LeafColors? ?? this);
}

extension LeafTheme on BuildContext {
  LeafColors get leaf => Theme.of(this).extension<LeafColors>()!;
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? LeafColors.light : LeafColors.dark;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F4D33), brightness: b).copyWith(
    primary: c.leaf,
    onPrimary: b == Brightness.light ? Colors.white : const Color(0xFF0D1611),
    secondary: c.bronze,
    surface: c.surface,
    error: c.bad,
  );
  const display = TextStyle(fontFamily: 'Mitr', fontWeight: FontWeight.w600, height: 1.3);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    fontFamily: 'IBMPlexSansThai',
    extensions: [c],
    textTheme: TextTheme(
      headlineSmall: display.copyWith(fontSize: 24),
      titleLarge: display.copyWith(fontSize: 20),
      titleMedium: display.copyWith(fontSize: 17),
      bodyLarge: const TextStyle(fontSize: 16, height: 1.6),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.6),
      bodySmall: TextStyle(fontSize: 13, height: 1.5, color: c.muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: b == Brightness.light ? c.leaf : c.surface,
      foregroundColor: b == Brightness.light ? Colors.white : c.leaf,
      titleTextStyle: display.copyWith(fontSize: 20, color: b == Brightness.light ? Colors.white : c.leaf),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.bronzeSoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    ),
  );
}

/// กล่องเนื้อหาพื้นขาวขอบบาง ใช้แทน Card เพื่อคุมหน้าตาให้เหมือนกันทุกเวอร์ชันของ Flutter
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}
