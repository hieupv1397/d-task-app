import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Logo khiên có dấu tích, vẽ bằng code nên nét ở mọi kích thước.
class ShieldLogo extends StatelessWidget {
  const ShieldLogo({super.key, this.size = 64, this.shield = Colors.white, this.check = Brand.blue});
  final double size;
  final Color shield, check;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ShieldPainter(shield, check));
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter(this.shield, this.check);
  final Color shield, check;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final path = Path()
      ..moveTo(50 * s, 5 * s)
      ..lineTo(88 * s, 18 * s)
      ..lineTo(88 * s, 50 * s)
      ..cubicTo(88 * s, 73 * s, 70 * s, 87 * s, 50 * s, 96 * s)
      ..cubicTo(30 * s, 87 * s, 12 * s, 73 * s, 12 * s, 50 * s)
      ..lineTo(12 * s, 18 * s)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.25), 4 * s, false);
    canvas.drawPath(path, Paint()..color = shield);
    final tick = Path()
      ..moveTo(p(32, 50).dx, p(32, 50).dy)
      ..lineTo(p(45, 63).dx, p(45, 63).dy)
      ..lineTo(p(69, 36).dx, p(69, 36).dy);
    canvas.drawPath(
      tick,
      Paint()
        ..color = check
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.shield != shield || old.check != check;
}

/// Nền gradient xanh có các vòng tròn trang trí mờ; dùng cho đầu trang chủ, hồ sơ và đăng nhập.
class HeroBackground extends StatelessWidget {
  const HeroBackground({super.key, required this.child, this.bottomRadius = 32, this.padding = EdgeInsets.zero});
  final Widget child;
  final double bottomRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(bottomRadius)),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: Brand.gradient),
          child: Stack(fit: StackFit.passthrough, children: [
            Positioned(right: -70, top: -60, child: _circle(220, 0.10)),
            Positioned(left: -90, bottom: -110, child: _circle(250, 0.07)),
            Positioned(right: 40, bottom: 30, child: _circle(70, 0.08)),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    );
  }

  static Widget _circle(double d, double a) => Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));
}

/// Nút chính nền gradient, có trạng thái đang xử lý.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: onPressed == null && !busy ? 0.55 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: Brand.gradientSoft,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x551668DC), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                      Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

const _avatarPalettes = [
  [Color(0xFF2F88FF), Color(0xFF1668DC)],
  [Color(0xFF22C58B), Color(0xFF0F9D6C)],
  [Color(0xFF8A6BFF), Color(0xFF5B3FD9)],
  [Color(0xFFFFB020), Color(0xFFF08A00)],
  [Color(0xFFFF6B81), Color(0xFFD8383A)],
  [Color(0xFF3CC6E8), Color(0xFF1992B8)],
];

/// Ảnh đại diện chữ cái đầu, màu gradient cố định theo tên.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.size = 40, this.ring = false});
  final String name;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    // Tên Việt: lấy chữ cái đầu của tên gọi (từ cuối cùng), ví dụ "Phạm Văn Hiếu" -> H.
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final text = words.isEmpty ? '?' : words.last.characters.first.toUpperCase();
    final pal = _avatarPalettes[name.codeUnits.fold<int>(0, (a, b) => a + b) % _avatarPalettes.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: pal, begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: ring ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5) : null,
      ),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w800)),
    );
  }
}

/// Ô vuông bo tròn chứa biểu tượng, nền nhạt cùng màu.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44, this.solid = false});
  final IconData icon;
  final Color color;
  final double size;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        color: solid ? null : color.withValues(alpha: 0.12),
        gradient: solid ? LinearGradient(colors: [Color.lerp(color, Colors.white, 0.22)!, color], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
      ),
      child: Icon(icon, color: solid ? Colors.white : color, size: size * 0.52),
    );
  }
}

/// Vòng tiến độ có số phần trăm ở giữa.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 46, this.color = Brand.blue});
  final double value; // 0..100
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = (value / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(width: size, height: size, child: CircularProgressIndicator(value: v, strokeWidth: size * 0.115, strokeCap: StrokeCap.round, color: color, backgroundColor: color.withValues(alpha: 0.14))),
        Text('${value.round()}', style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: Brand.ink)),
      ]),
    );
  }
}

/// Tiêu đề từng khối trên màn hình, kèm liên kết "Xem tất cả".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(18, 22, 10, 8)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]),
    );
  }
}

/// Trạng thái rỗng có hình minh họa: vòng tròn mờ lồng nhau và biểu tượng giữa.
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({super.key, required this.icon, required this.title, this.text, this.color = Brand.blue});
  final IconData icon;
  final String title;
  final String? text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 150,
          height: 130,
          child: Stack(alignment: Alignment.center, children: [
            Container(width: 124, height: 124, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.07))),
            Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.11))),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: Brand.softShadow),
              child: Icon(icon, size: 30, color: color),
            ),
            Positioned(left: 14, top: 22, child: _dot(9, color.withValues(alpha: 0.35))),
            Positioned(right: 18, top: 14, child: _dot(6, Brand.warn.withValues(alpha: 0.55))),
            Positioned(right: 10, bottom: 26, child: _dot(11, color.withValues(alpha: 0.22))),
          ]),
        ),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (text != null) ...[const SizedBox(height: 6), Text(text!, textAlign: TextAlign.center, style: const TextStyle(color: Brand.mute, height: 1.45))],
      ]),
    );
  }

  static Widget _dot(double d, Color c) => Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: c));
}

/// Thẻ trắng bo góc có bóng nhẹ; có thể bấm.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6), this.accent});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding, margin;

  /// Dải màu mảnh bên trái thẻ, thể hiện mức độ (quá hạn, khẩn...).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: Brand.tinyShadow, border: Border.all(color: Brand.line)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: onTap,
              child: Stack(children: [
                if (accent != null) Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 5, color: accent)),
                Padding(padding: padding, child: child),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

double degToRad(double d) => d * math.pi / 180;
