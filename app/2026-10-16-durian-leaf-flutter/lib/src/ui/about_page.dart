// แท็บ "เกี่ยวกับ": วิธีทำงาน ผลทดสอบโมเดล ข้อควรรู้ และผู้จัดทำ
import 'package:flutter/material.dart';

import '../theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.leaf;
    final t = Theme.of(context).textTheme;
    Widget stat(String big, String small) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(big, style: t.titleLarge)),
              Text(small, style: t.bodySmall),
            ]),
          ),
        );
    Widget bullet(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  '),
            Expanded(child: Text(s)),
          ]),
        );
    const rows = [
      ['โรคใบจุดสาหร่าย', '100.0', '100.0', '7'],
      ['ใบปกติ', '80.0', '100.0', '8'],
      ['โรคใบติด', '100.0', '90.0', '10'],
      ['โรคใบจุดสนิม/ใบจุดทั่วไป', '100.0', '88.9', '9'],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('เกี่ยวกับ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('หมอใบทุเรียนทำงานอย่างไร', style: t.titleLarge),
                const SizedBox(height: 8),
                bullet('ย่อรูปใบเป็น 224×224 จุดภาพ'),
                bullet('โมเดล MobileNetV3-Small ประมวลผลในเครื่อง ไม่ส่งรูปขึ้นอินเทอร์เน็ต'),
                bullet('แสดงโรคที่น่าจะเป็น ความมั่นใจ และแผนที่ Grad-CAM บอกว่าโมเดลดูที่ส่วนไหนของรูป'),
                const SizedBox(height: 12),
                Text('ผลการทดสอบโมเดล', style: t.titleMedium),
                const SizedBox(height: 8),
                Row(children: [
                  stat('94.1%', 'ความแม่นยำชุดทดสอบ (ถูก 32 จาก 34 รูป)'),
                  const SizedBox(width: 10),
                  stat('97.0 ± 3.0%', 'ตรวจไขว้ 5 รอบ แบ่งตามใบต้นฉบับ'),
                ]),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 40,
                    horizontalMargin: 4,
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('กลุ่ม')),
                      DataColumn(label: Text('Precision'), numeric: true),
                      DataColumn(label: Text('Recall'), numeric: true),
                      DataColumn(label: Text('รูป'), numeric: true),
                    ],
                    rows: [for (final r in rows) DataRow(cells: [for (final v in r) DataCell(Text(v))])],
                  ),
                ),
                const SizedBox(height: 12),
                Text('ข้อควรรู้', style: t.titleMedium),
                const SizedBox(height: 8),
                bullet('ฝึกจากรูปใบทุเรียนจริง 225 ใบ (541 รูปรวมสำเนาที่แต่งภาพ) ชุดทดสอบยังเล็ก ตัวเลขจึงคลาดเคลื่อนได้'),
                bullet('ความผิดพลาดที่พบคือ ใบที่แผลเล็กหรือจางถูกทายเป็นใบปกติด้วยความมั่นใจต่ำ (ต่ำกว่า 60%) ระบบจึงแจ้งให้ถ่ายใหม่เมื่อไม่แน่ใจ'),
                bullet('ยังไม่ได้ทดสอบกับรูปจากสวนอื่นหรือกล้องอื่น ควรเก็บรูปเพิ่มเพื่อพัฒนาต่อ'),
                bullet('ข้อมูลเชื้อสาเหตุและแนวทางจัดการมาจากไฟล์ตั้งค่าโครงการ (configs/model_config.json)'),
                Divider(color: c.line, height: 28),
                Text(
                  'ผู้จัดทำ: ชีวะ ทัศนา · สาขาวิชาดิจิทัลการเกษตรและสิ่งแวดล้อม คณะวิทยาศาสตร์และเทคโนโลยี มหาวิทยาลัยราชภัฏรำไพพรรณี\n'
                  'โครงการ Agri-Microbiology SmartFarm · โมเดลรุ่น 2026-10-16 · แอป Flutter 1.0.0',
                  style: t.bodySmall,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
