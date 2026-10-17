// แท็บ "ประวัติ": รายการผลตรวจที่เก็บในเครื่อง แตะเพื่อดูผลเต็ม
import 'dart:io';

import 'package:flutter/material.dart';

import '../disease.dart';
import '../history_store.dart';
import '../theme.dart';
import 'result_view.dart';

class HistoryPage extends StatefulWidget {
  final HistoryStore store;
  final ValueNotifier<int> revision;
  const HistoryPage({super.key, required this.store, required this.revision});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Diagnosis> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final items = await widget.store.load();
    if (mounted) {
      setState(() {
        _items = items;
        _loaded = true;
      });
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ล้างประวัติทั้งหมด?'),
        content: const Text('รูปและผลการตรวจทั้งหมดในเครื่องนี้จะถูกลบ และกู้คืนไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('ลบ', style: TextStyle(color: context.leaf.bad))),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.clear();
      await _reload();
    }
  }

  void _open(Diagnosis d) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('ผลการตรวจ')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          ResultView(d: d, image: FileImage(File(d.imagePath!)), onAgain: () => Navigator.pop(ctx)),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการตรวจ'),
        actions: [
          if (_items.isNotEmpty) IconButton(tooltip: 'ล้างประวัติ', onPressed: _clear, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.history, size: 48, color: c.muted),
                      const SizedBox(height: 8),
                      Text('ยังไม่มีประวัติการตรวจ', style: t.titleMedium),
                      const SizedBox(height: 4),
                      Text('ถ่ายหรือเลือกรูปใบทุเรียนในแท็บ "ตรวจใบ" ผลจะถูกบันทึกไว้ที่นี่อัตโนมัติ', textAlign: TextAlign.center, style: t.bodySmall),
                    ]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == _items.length) {
                      return Text('${_items.length} รายการ · เก็บไว้ในเครื่องนี้เท่านั้น (สูงสุด ${HistoryStore.maxItems} รายการ)',
                          textAlign: TextAlign.center, style: t.bodySmall);
                    }
                    final d = _items[i];
                    final (bg, fg) = switch (d.level) {
                      Confidence.high => (c.goodBg, c.good),
                      Confidence.medium => (c.warnBg, c.warn),
                      Confidence.low => (c.badBg, c.bad),
                    };
                    return Material(
                      color: c.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.line)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: d.imagePath == null ? null : () => _open(d),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: d.imagePath == null
                                    ? ColoredBox(color: c.surface2)
                                    : Image.file(File(d.imagePath!), fit: BoxFit.cover, cacheWidth: 192,
                                        errorBuilder: (_, __, ___) => ColoredBox(color: c.surface2)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d.level == Confidence.low ? 'ไม่แน่ใจ (${d.info.th})' : d.info.th,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(thaiDateTime(d.time), style: t.bodySmall),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                              child: Text('${d.conf.round()}%', style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
