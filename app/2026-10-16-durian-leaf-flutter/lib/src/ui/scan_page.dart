// แท็บ "ตรวจใบ": ถ่ายรูป / คลังรูป / ตรวจแบบสด / รูปตัวอย่าง และแสดงผลการตรวจ
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../classifier.dart';
import '../disease.dart';
import '../history_store.dart';
import '../image_prep.dart';
import '../theme.dart';
import 'live_page.dart';
import 'result_view.dart';

const kSamples = ['assets/samples/sample1.jpg', 'assets/samples/sample2.jpg', 'assets/samples/sample3.jpg', 'assets/samples/sample4.jpg'];

class ScanPage extends StatefulWidget {
  final Classifier classifier;
  final HistoryStore store;
  final VoidCallback onSaved;
  const ScanPage({super.key, required this.classifier, required this.store, required this.onSaved});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _picker = ImagePicker();
  final _resultKey = GlobalKey();
  final _scroll = ScrollController();
  bool _ready = false;
  bool _busy = false;
  String? _error;
  Diagnosis? _d;
  ImageProvider? _img;
  int _sample = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await widget.classifier.load();
      if (!mounted) return;
      setState(() => _ready = true);
      await _analyzeSample(0, scroll: false);
    } catch (e) {
      if (mounted) setState(() => _error = 'เตรียมโมเดลไม่สำเร็จ: $e');
    }
  }

  Future<void> _analyze(Uint8List bytes, {bool sample = false, bool crop = false, bool scroll = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final prep = await compute(prepareImage, PrepRequest(bytes, cropSquare: crop));
      final out = await widget.classifier.run(prep.tensor);
      var d = Diagnosis(probs: out.probs, cam: out.cam, time: DateTime.now(), ms: out.ms, sample: sample);
      if (!sample) {
        d = await widget.store.add(d, prep.previewJpg);
        widget.onSaved();
      }
      if (!mounted) return;
      setState(() {
        _d = d;
        _img = MemoryImage(prep.previewJpg);
      });
      if (scroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _resultKey.currentContext;
          if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350));
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is FormatException ? e.message : 'วิเคราะห์รูปไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyzeSample(int i, {bool scroll = true}) async {
    setState(() => _sample = i);
    final data = await rootBundle.load(kSamples[i]);
    await _analyze(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), sample: true, scroll: scroll);
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await _picker.pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 92);
      if (x == null) return;
      setState(() => _sample = -1);
      await _analyze(await x.readAsBytes());
    } on PlatformException catch (e) {
      setState(() => _error = e.code.contains('denied') || e.code.contains('access')
          ? 'ไม่ได้รับอนุญาตให้ใช้กล้อง/คลังรูป — เปิดสิทธิ์ในการตั้งค่าของเครื่อง แล้วลองใหม่'
          : 'เปิดกล้องหรือคลังรูปไม่สำเร็จ (${e.code})');
    }
  }

  Future<void> _live() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => LivePage(classifier: widget.classifier), fullscreenDialog: true),
    );
    if (bytes != null && mounted) {
      setState(() => _sample = -1);
      await _analyze(bytes, crop: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    final t = Theme.of(context).textTheme;
    final enabled = _ready && !_busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('หมอใบทุเรียน'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(Icons.circle, size: 10, color: _ready ? const Color(0xFF8FE0AE) : c.bronzeSoft),
              label: Text(_busy ? 'กำลังวิเคราะห์' : _ready ? 'พร้อมตรวจ' : 'กำลังเตรียม', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('ถ่ายรูปใบทุเรียนที่สงสัย', style: t.titleLarge),
                  const SizedBox(height: 4),
                  Text('ถ่ายใบเดียวให้เต็มกรอบ ระบบจะบอกโรคที่น่าจะเป็น พร้อมแนวทางจัดการ รูปไม่ถูกส่งออกจากเครื่อง', style: t.bodySmall),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: enabled ? () => _pick(ImageSource.camera) : null,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('ถ่ายรูป'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: enabled ? () => _pick(ImageSource.gallery) : null,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('คลังรูป'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: enabled ? _live : null,
                    icon: const Icon(Icons.fiber_manual_record, color: Color(0xFFD93025), size: 16),
                    label: const Text('ตรวจแบบสดผ่านกล้อง'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: c.bronzeSoft,
                      foregroundColor: c.bronze,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Expanded(child: Text('หรือลองกับรูปตัวอย่าง', style: TextStyle(fontWeight: FontWeight.w600))),
                    Text('รูปจริงจากชุดทดสอบ', style: t.bodySmall),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (var i = 0; i < kSamples.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: InkWell(
                            onTap: enabled ? () => _analyzeSample(i) : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _sample == i ? c.bronze : Colors.transparent, width: 2.5),
                                image: DecorationImage(image: AssetImage(kSamples[i]), fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('ถ่ายอย่างไรให้ได้ผลแม่น', style: TextStyle(fontWeight: FontWeight.w600)),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tip in const [
                          'ถ่ายใบเดียว ให้ใบเต็มกรอบประมาณ 2 ใน 3 ของรูป',
                          'ใช้แสงธรรมชาติ ไม่ย้อนแสง ไม่เบลอ',
                          'ให้เห็นแผลหรือจุดผิดปกติชัดเจน ถ้าแผลเล็กให้ถ่ายใกล้ขึ้น',
                          'ถ้าผลขึ้นว่า "ยังไม่แน่ใจ" ให้ถ่ายใหม่อีกมุมหนึ่ง',
                        ])
                          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('•  $tip', style: t.bodySmall)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (!_ready && _error == null)
                Panel(
                  child: Column(children: [
                    const Text('กำลังเตรียมโมเดลตรวจโรค', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(color: c.bronze, backgroundColor: c.surface2),
                  ]),
                ),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.badBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: TextStyle(color: c.bad)),
                ),
              if (_busy) Padding(padding: const EdgeInsets.only(bottom: 12), child: LinearProgressIndicator(color: c.bronze)),
              if (_d != null && _img != null)
                KeyedSubtree(
                  key: _resultKey,
                  child: ResultView(
                    d: _d!,
                    image: _img!,
                    onAgain: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
