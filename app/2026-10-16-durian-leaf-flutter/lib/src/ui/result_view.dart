// การ์ดแสดงผลการตรวจ: ชื่อโรค ความมั่นใจ แผนที่ Grad-CAM ความน่าจะเป็น และแนวทางจัดการ
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../disease.dart';
import '../theme.dart';
import 'cam_painter.dart';

class ResultView extends StatefulWidget {
  final Diagnosis d;
  final ImageProvider image;
  final VoidCallback onAgain;
  const ResultView({super.key, required this.d, required this.image, required this.onAgain});

  static ImageProvider memory(Uint8List bytes) => MemoryImage(bytes);

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  double _alpha = 0.45;

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    final t = Theme.of(context).textTheme;
    final d = widget.d;
    final lv = d.level;
    final (vBg, vFg) = switch (lv) {
      Confidence.high => (c.goodBg, c.good),
      Confidence.medium => (c.warnBg, c.warn),
      Confidence.low => (c.badBg, c.bad),
    };
    final showEnv = d.info.env != null && lv != Confidence.low;

    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // แถบสองสี: ผิวใบด้านบน (เขียว) และเกล็ดใต้ใบ (ทองแดง)
        Row(children: [
          Expanded(flex: 62, child: Container(height: 6, color: c.leaf)),
          Expanded(flex: 38, child: Container(height: 6, color: c.bronze)),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: c.bronzeSoft, borderRadius: BorderRadius.circular(6)),
                child: Text(d.sample ? 'ผลตัวอย่าง (รูปจากชุดทดสอบ)' : 'ผลตรวจ · ${thaiDateTime(d.time)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.bronze)),
              ),
            ),
            const SizedBox(height: 6),
            Text(lv == Confidence.low ? 'ยังระบุไม่ได้ชัดเจน (ใกล้เคียง: ${d.info.th})' : d.info.th, style: t.headlineSmall),
            Text('${d.className} · ประมวลผล ${d.ms.round()} มิลลิวินาที', style: t.bodySmall),
            if (d.info.pathogen.isNotEmpty)
              Text.rich(TextSpan(text: 'เชื้อสาเหตุ: ', style: t.bodySmall, children: [
                TextSpan(text: d.info.pathogen, style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface)),
              ]))
            else
              Text('ไม่พบอาการของโรคที่ระบบรู้จัก', style: t.bodySmall),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: vBg, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(kLevelTitle[lv]!, style: TextStyle(fontFamily: 'Mitr', fontWeight: FontWeight.w500, fontSize: 17, color: vFg)),
                Text(kLevelText[lv]!, style: t.bodyMedium),
              ]),
            ),
            const SizedBox(height: 14),
            _Gauge(conf: d.conf),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  Image(image: widget.image, fit: BoxFit.cover, gaplessPlayback: true),
                  CustomPaint(painter: CamPainter(cam: d.cam, opacity: _alpha)),
                ]),
              ),
            ),
            Row(children: [
              Text('แผนที่จุดที่ใช้ตัดสิน', style: t.bodySmall),
              Expanded(
                child: Slider(
                  value: _alpha,
                  min: 0,
                  max: 0.8,
                  activeColor: c.bronze,
                  onChanged: (v) => setState(() => _alpha = v),
                ),
              ),
            ]),
            CamLegend(textColor: c.muted),
            const SizedBox(height: 14),
            for (final i in d.order) _ProbRow(label: kInfo[kClasses[i]]!.th, p: d.probs[i], top: i == d.top),
            const SizedBox(height: 10),
            Text('แนวทางจัดการ', style: t.titleMedium),
            const SizedBox(height: 6),
            Panel(
              color: c.bg,
              padding: const EdgeInsets.all(12),
              child: Text(lv == Confidence.low ? 'ยังไม่ควรใช้สารเคมีจากผลนี้ ให้ถ่ายรูปใหม่หรือปรึกษาเจ้าหน้าที่เกษตร' : d.info.guide),
            ),
            if (showEnv) ...[
              const SizedBox(height: 12),
              Text('สภาพอากาศที่ส่งเสริมให้โรคระบาด', style: t.titleMedium),
              const SizedBox(height: 6),
              Panel(
                color: c.bg,
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _EnvCell(label: 'ความชื้นสัมพัทธ์', value: d.info.env!.rh),
                  _EnvCell(label: 'อุณหภูมิ', value: d.info.env!.temp),
                  _EnvCell(label: 'ช่วงเสี่ยง', value: d.info.env!.season, small: true),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'ผลนี้เป็นการคัดกรองเบื้องต้น ก่อนใช้สารเคมีควรยืนยันกับเจ้าหน้าที่เกษตรหรือผู้เชี่ยวชาญโรคพืช และอ่านฉลากทุกครั้ง '
              'โมเดลรู้จักเพียง 4 กลุ่ม อาการอื่น เช่น ขาดธาตุอาหารหรือแมลงทำลาย อาจถูกทายผิด',
              style: t.bodySmall,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: widget.onAgain,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              child: const Text('ตรวจใบใหม่', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Gauge extends StatelessWidget {
  final double conf;
  const _Gauge({required this.conf});

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    final fg = Theme.of(context).colorScheme.onSurface;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('ความมั่นใจของผลตรวจ')),
        Text('${conf.toStringAsFixed(1)}%',
            style: const TextStyle(fontFamily: 'Mitr', fontSize: 24, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
      ]),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: 32,
          child: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Row(children: [
                  Expanded(flex: 60, child: Container(color: c.badBg)),
                  Expanded(flex: 25, child: Container(color: c.warnBg)),
                  Expanded(flex: 15, child: Container(color: c.goodBg)),
                ]),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              height: 14,
              width: w * (conf / 100).clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: fg.withAlpha(217), borderRadius: BorderRadius.circular(7))),
            ),
            for (final (v, label) in [(0.0, '0'), (0.6, '60'), (0.85, '85'), (1.0, '100%')])
              Positioned(
                top: 16,
                left: v == 1.0 ? null : (v == 0 ? 0.0 : w * v - 10),
                right: v == 1.0 ? 0 : null,
                child: Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
              ),
          ]),
        );
      }),
    ]);
  }
}

class _ProbRow extends StatelessWidget {
  final String label;
  final double p;
  final bool top;
  const _ProbRow({required this.label, required this.p, required this.top});

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text('${(p * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: p, minHeight: 8, backgroundColor: c.surface2, color: top ? c.leaf : c.muted),
        ),
      ]),
    );
  }
}

class _EnvCell extends StatelessWidget {
  final String label, value;
  final bool small;
  const _EnvCell({required this.label, required this.value, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: small ? 13 : 16)),
        ]),
      ),
    );
  }
}
