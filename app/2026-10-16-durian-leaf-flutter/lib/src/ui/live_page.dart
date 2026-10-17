// โหมด "ตรวจแบบสด": วิเคราะห์ภาพจากกล้องต่อเนื่อง (~4 ครั้ง/วินาที) เฉพาะกรอบสี่เหลี่ยมกลางจอ
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../classifier.dart';
import '../disease.dart';
import '../image_prep.dart';
import 'cam_painter.dart';

// หน้าจอนี้ใช้ธีมเข้มเสมอ (เหมือนช่องมองภาพกล้อง)
const _bg = Color(0xFF0B0F0C);
const _panel = Color(0xFF152019);
const _text = Color(0xFFEEF3EE);
const _sub = Color(0xFFA9BCAE);
const _gold = Color(0xFFD9A656);

class LivePage extends StatefulWidget {
  final Classifier classifier;
  const LivePage({super.key, required this.classifier});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with WidgetsBindingObserver {
  List<CameraDescription> _cams = [];
  int _camIdx = 0;
  CameraController? _ctl;
  String? _msg = 'กำลังเปิดกล้อง…';

  bool _busy = false;
  bool _shooting = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  List<double>? _ema; // ค่าเฉลี่ยถ่วงน้ำหนัก กันตัวเลขกระพริบ
  List<double>? _cam;
  int _streak = 0, _lastTop = -1;
  bool _showCam = true;
  double _bright = 128, _ms = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stop();
    } else if (state == AppLifecycleState.resumed && _ctl == null && _cams.isNotEmpty) {
      _start();
    }
  }

  Future<void> _init() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() => _msg = 'ไม่พบกล้องบนอุปกรณ์นี้');
        return;
      }
      final back = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camIdx = back >= 0 ? back : 0;
      await _start();
    } on CameraException catch (e) {
      if (mounted) setState(() => _msg = _cameraError(e));
    }
  }

  String _cameraError(CameraException e) {
    if (e.code.contains('Access') || e.code.contains('ermission')) {
      return 'ไม่ได้รับอนุญาตให้ใช้กล้อง\nเปิดสิทธิ์กล้องให้แอปในการตั้งค่าของเครื่อง แล้วลองใหม่';
    }
    return 'เปิดกล้องไม่สำเร็จ (${e.code})';
  }

  Future<void> _start() async {
    final desc = _cams[_camIdx];
    final ctl = CameraController(
      desc,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    _ctl = ctl;
    try {
      await ctl.initialize();
      if (!mounted || _ctl != ctl) return;
      await ctl.startImageStream(_onFrame);
      setState(() {
        _msg = null;
        _ema = null;
        _cam = null;
        _streak = 0;
      });
    } on CameraException catch (e) {
      if (mounted) setState(() => _msg = _cameraError(e));
    }
  }

  Future<void> _stop() async {
    final ctl = _ctl;
    _ctl = null;
    if (ctl == null) return;
    try {
      if (ctl.value.isStreamingImages) await ctl.stopImageStream();
    } catch (_) {}
    await ctl.dispose();
  }

  void _onFrame(CameraImage image) {
    if (_busy || _shooting) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 250) return;
    _busy = true;
    _last = now;
    _process(FrameData.fromCameraImage(image, _cams[_camIdx].sensorOrientation));
  }

  Future<void> _process(FrameData f) async {
    try {
      final r = await compute(frameToTensor, f);
      final out = await widget.classifier.run(r.tensor);
      if (!mounted) return;
      final p = out.probs;
      final ema = _ema == null ? p : [for (var i = 0; i < p.length; i++) 0.6 * _ema![i] + 0.4 * p[i]];
      var top = 0;
      for (var i = 1; i < p.length; i++) {
        if (p[i] > p[top]) top = i;
      }
      setState(() {
        _ema = ema;
        _cam = out.cam;
        _streak = top == _lastTop ? _streak + 1 : 1;
        _lastTop = top;
        _bright = r.brightness;
        _ms = out.ms;
      });
    } catch (e) {
      debugPrint('live frame error: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _flip() async {
    if (_cams.length < 2) return;
    await _stop();
    _camIdx = (_camIdx + 1) % _cams.length;
    setState(() => _msg = 'กำลังสลับกล้อง…');
    await _start();
  }

  Future<void> _shoot() async {
    final ctl = _ctl;
    if (ctl == null || _shooting) return;
    setState(() => _shooting = true);
    try {
      if (ctl.value.isStreamingImages) await ctl.stopImageStream();
      final file = await ctl.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _shooting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ถ่ายภาพไม่สำเร็จ (${e.code})')));
        await ctl.startImageStream(_onFrame);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ema = _ema;
    String name = 'เล็งใบทุเรียนให้อยู่ในกรอบ', conf = '–', hint = 'ถือมือถือนิ่ง ๆ ให้ใบเต็มกรอบ';
    double confV = 0;
    var level = Confidence.medium;
    var stable = false;
    if (ema != null) {
      final order = List<int>.generate(ema.length, (i) => i)..sort((a, b) => ema[b].compareTo(ema[a]));
      confV = ema[order[0]] * 100;
      level = confidenceLevel(confV, (ema[order[0]] - ema[order[1]]) * 100);
      stable = _streak >= 5;
      name = level == Confidence.low ? 'ยังไม่แน่ใจ' : kInfo[kClasses[order[0]]]!.th;
      conf = '${confV.round()}%';
      hint = _bright < 45
          ? 'แสงน้อยเกินไป หันเข้าหาแสง'
          : _bright > 225
              ? 'สว่างเกินไป หลบแสงแดดจ้า'
              : level == Confidence.low
                  ? 'ขยับเข้าใกล้ ให้ใบเต็มกรอบและเห็นแผลชัด'
                  : (stable && level == Confidence.high)
                      ? 'กด "บันทึกผลภาพนี้" ได้เลย'
                      : 'ถือมือถือนิ่ง ๆ';
    }
    final (stateText, stateBg, stateFg) = ema == null
        ? ('กำลังดู', const Color(0xFF3D2D12), const Color(0xFFF0B45A))
        : (level == Confidence.high && stable)
            ? ('ผลคงที่', const Color(0xFF183A27), const Color(0xFF6FD39A))
            : level == Confidence.low
                ? ('ไม่แน่ใจ', const Color(0xFF43201D), const Color(0xFFFF8A80))
                : ('กำลังดู', const Color(0xFF3D2D12), const Color(0xFFF0B45A));
    final ctl = _ctl;
    final front = _cams.isNotEmpty && _cams[_camIdx].lensDirection == CameraLensDirection.front;

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'IBMPlexSansThai')),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(children: [
                  Row(children: [
                    _RoundButton(icon: Icons.close, tooltip: 'ปิดโหมดกล้องสด', onTap: () => Navigator.of(context).pop()),
                    const SizedBox(width: 10),
                    const Icon(Icons.fiber_manual_record, color: Color(0xFFD93025), size: 12),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('ตรวจแบบสด', style: TextStyle(fontFamily: 'Mitr', fontSize: 18, fontWeight: FontWeight.w600, color: _text)),
                    ),
                    _RoundButton(
                      icon: Icons.blur_on,
                      tooltip: 'แสดง/ซ่อนแผนที่จุดที่ใช้ตัดสิน',
                      active: _showCam,
                      onTap: () => setState(() => _showCam = !_showCam),
                    ),
                    const SizedBox(width: 8),
                    _RoundButton(icon: Icons.cameraswitch_outlined, tooltip: 'สลับกล้องหน้า/หลัง', onTap: _flip),
                  ]),
                  const SizedBox(height: 10),
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(fit: StackFit.expand, children: [
                          Container(color: Colors.black),
                          if (ctl != null && ctl.value.isInitialized && ctl.value.previewSize != null)
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: ctl.value.previewSize!.height,
                                height: ctl.value.previewSize!.width,
                                child: CameraPreview(ctl),
                              ),
                            ),
                          if (_showCam && level != Confidence.low)
                            CustomPaint(painter: CamPainter(cam: _cam, opacity: 0.6, mirror: front, fadeLow: true)),
                          const _Corners(),
                          if (_msg != null)
                            Container(
                              color: const Color(0x8C000000),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(24),
                              child: Text(_msg!, textAlign: TextAlign.center, style: const TextStyle(color: _text, fontSize: 15)),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                          child: Text(name, style: const TextStyle(fontFamily: 'Mitr', fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                        Text(conf, style: const TextStyle(fontFamily: 'Mitr', fontSize: 20, color: Colors.white)),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 10,
                          child: Stack(fit: StackFit.expand, children: [
                            const Row(children: [
                              Expanded(flex: 60, child: ColoredBox(color: Color(0xFF43201D))),
                              Expanded(flex: 25, child: ColoredBox(color: Color(0xFF3D2D12))),
                              Expanded(flex: 15, child: ColoredBox(color: Color(0xFF183A27))),
                            ]),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (confV / 100).clamp(0.0, 1.0),
                              child: const ColoredBox(color: _text),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(color: stateBg, borderRadius: BorderRadius.circular(999)),
                          child: Text(stateText, style: TextStyle(color: stateFg, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        Text(hint, style: const TextStyle(color: _sub, fontSize: 13)),
                        if (_ms > 0) Text('${_ms.round()} มิลลิวินาที/ภาพ', style: const TextStyle(color: _sub, fontSize: 13)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: (ctl != null && _msg == null && !_shooting) ? _shoot : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: _shooting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: _bg))
                          : const Icon(Icons.radio_button_checked),
                      label: const Text('บันทึกผลภาพนี้', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _gold : const Color(0x14FFFFFF),
        shape: const CircleBorder(side: BorderSide(color: Color(0x38FFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, color: active ? _bg : _text, size: 22)),
        ),
      ),
    );
  }
}

/// มุมกรอบเล็ง
class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) => const IgnorePointer(child: CustomPaint(painter: _CornerPainter()));
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xD9FFFFFF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const m = 14.0, l = 32.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [(m, m, 1.0, 1.0), (w - m, m, -1.0, 1.0), (m, h - m, 1.0, -1.0), (w - m, h - m, -1.0, -1.0)]) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * l, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * l), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
