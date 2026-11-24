import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bảng màu và các hằng thiết kế dùng chung của D Task.
class Brand {
  static const blue = Color(0xFF1668DC);
  static const sky = Color(0xFF2F88FF);
  static const deep = Color(0xFF0B3F9E);
  static const ink = Color(0xFF0F1F33);
  static const mute = Color(0xFF6B7A90);
  static const line = Color(0xFFE3EBF5);
  static const bg = Color(0xFFF3F6FB);

  static const ok = Color(0xFF12A150);
  static const warn = Color(0xFFF08A00);
  static const bad = Color(0xFFD8383A);
  static const violet = Color(0xFF6C4DFF);
  static const teal = Color(0xFF0EA5A5);

  static const gradient = LinearGradient(colors: [sky, blue, deep], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gradientSoft = LinearGradient(colors: [sky, blue], begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Đổ bóng mềm cho thẻ nổi.
  static const softShadow = [BoxShadow(color: Color(0x140B3F9E), blurRadius: 22, offset: Offset(0, 8))];
  static const tinyShadow = [BoxShadow(color: Color(0x0F0B3F9E), blurRadius: 10, offset: Offset(0, 3))];
}

const _font = 'BeVietnamPro';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.blue, brightness: Brightness.light).copyWith(
    primary: Brand.blue,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDDEBFF),
    onPrimaryContainer: Brand.deep,
    secondary: Brand.sky,
    surface: Colors.white,
    onSurface: Brand.ink,
    onSurfaceVariant: Brand.mute,
    outline: Brand.mute,
    outlineVariant: Brand.line,
    error: Brand.bad,
    surfaceTint: Colors.transparent,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: _font);
  return base.copyWith(
    scaffoldBackgroundColor: Brand.bg,
    textTheme: base.textTheme.apply(bodyColor: Brand.ink, displayColor: Brand.ink),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.white,
      foregroundColor: Brand.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: _font, fontSize: 19, fontWeight: FontWeight.w700, color: Brand.ink),
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Brand.line)),
    ),
    dividerTheme: const DividerThemeData(color: Brand.line, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: const Color(0x330B3F9E),
      height: 68,
      indicatorColor: const Color(0xFFE2EEFF),
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 25, color: s.contains(WidgetState.selected) ? Brand.blue : Brand.mute)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: _font,
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? Brand.blue : Brand.mute,
          )),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(Brand.line),
      enabledBorder: border(const Color(0xFFD9E4F2)),
      focusedBorder: border(Brand.blue, 1.8),
      errorBorder: border(Brand.bad),
      focusedErrorBorder: border(Brand.bad, 1.8),
      labelStyle: const TextStyle(color: Brand.mute),
      prefixIconColor: Brand.mute,
      hintStyle: const TextStyle(color: Color(0xFF9AA8BC)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFFCFDDF0)),
        textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600))),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFDDEBFF),
      checkmarkColor: Brand.blue,
      showCheckmark: false,
      side: const BorderSide(color: Color(0xFFD5E1F1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w600, color: Brand.ink),
      secondaryLabelStyle: const TextStyle(fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w700, color: Brand.deep),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(fontFamily: _font, fontSize: 18, fontWeight: FontWeight.w700, color: Brand.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.ink,
      contentTextStyle: const TextStyle(fontFamily: _font, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Brand.mute),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.blue, linearTrackColor: Color(0xFFE6EEF9), circularTrackColor: Color(0xFFE6EEF9)),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
    popupMenuTheme: PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
  );
}
