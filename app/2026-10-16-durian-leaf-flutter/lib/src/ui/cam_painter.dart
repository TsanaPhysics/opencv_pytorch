// วาดแผนที่ Grad-CAM (7x7) ทับบนภาพ: ขยายแบบ bilinear + สี jet (น้ำเงิน = สนใจน้อย → แดง = สนใจมาก)
import 'dart:math' as math;

import 'package:flutter/material.dart';

Color jetColor(double v, double alpha) {
  double c(double x) => x.clamp(0.0, 1.0);
  final r = c(1.5 - (4 * v - 3).abs());
  final g = c(1.5 - (4 * v - 2).abs());
  final b = c(1.5 - (4 * v - 1).abs());
  return Color.fromRGBO((r * 255).round(), (g * 255).round(), (b * 255).round(), alpha);
}

class CamPainter extends CustomPainter {
  final List<double>? cam; // 49 ค่า
  final double opacity; // 0..1
  final bool mirror; // กล้องหน้าแสดงภาพกลับซ้าย-ขวา
  final bool fadeLow; // โหมดสด: ส่วนที่สนใจน้อยให้โปร่งใสกว่า
  const CamPainter({required this.cam, required this.opacity, this.mirror = false, this.fadeLow = false});

  double _at(double x, double y) {
    // x,y ในหน่วยช่อง 0..7 (ศูนย์กลางช่องที่ +0.5)
    final fx = (x - 0.5).clamp(0.0, 6.0), fy = (y - 0.5).clamp(0.0, 6.0);
    final x0 = fx.floor(), y0 = fy.floor();
    final x1 = math.min(x0 + 1, 6), y1 = math.min(y0 + 1, 6);
    final tx = fx - x0, ty = fy - y0;
    double v(int xx, int yy) => cam![yy * 7 + xx];
    final top = v(x0, y0) * (1 - tx) + v(x1, y0) * tx;
    final bot = v(x0, y1) * (1 - tx) + v(x1, y1) * tx;
    return top * (1 - ty) + bot * ty;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cam == null || cam!.length != 49 || opacity <= 0) return;
    const grid = 42;
    final cw = size.width / grid, ch = size.height / grid;
    final paint = Paint()..isAntiAlias = false;
    for (var gy = 0; gy < grid; gy++) {
      for (var gx = 0; gx < grid; gx++) {
        final sx = mirror ? (grid - 1 - gx) : gx;
        final v = _at((sx + 0.5) * 7 / grid, (gy + 0.5) * 7 / grid);
        final a = fadeLow ? opacity * (0.25 + 0.75 * v) : opacity;
        paint.color = jetColor(v, a);
        canvas.drawRect(Rect.fromLTWH(gx * cw, gy * ch, cw + 0.6, ch + 0.6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(CamPainter old) => old.cam != cam || old.opacity != opacity || old.mirror != mirror;
}

/// แถบอธิบายสีของแผนที่
class CamLegend extends StatelessWidget {
  final Color textColor;
  const CamLegend({super.key, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, color: textColor);
    return Row(children: [
      Text('สนใจน้อย', style: style),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: [for (var i = 0; i <= 6; i++) jetColor(i / 6, 1)]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('สนใจมาก', style: style),
    ]);
  }
}
