// ข้อมูลโรค (จาก configs/model_config.json ของโครงการ) และเกณฑ์ความมั่นใจ

/// ลำดับเดียวกับผลลัพธ์ของโมเดล (เรียงตามชื่อโฟลเดอร์ใน dataset/)
const List<String> kClasses = ['Algal Leaf Spot', 'Healthy', 'Leaf Blight', 'Leaf Spot'];

class EnvRisk {
  final String rh;
  final String temp;
  final String season;
  const EnvRisk(this.rh, this.temp, this.season);
}

class DiseaseInfo {
  final String th;
  final String pathogen;
  final String guide;
  final EnvRisk? env;
  const DiseaseInfo({required this.th, required this.pathogen, required this.guide, this.env});
}

const Map<String, DiseaseInfo> kInfo = {
  'Algal Leaf Spot': DiseaseInfo(
    th: 'โรคใบจุดสาหร่าย',
    pathogen: 'Cephaleuros virescens Kunze',
    guide: 'ตัดแต่งกิ่งให้โปร่งเพื่อระบายอากาศ พ่นด้วยสารประกอบทองแดง (Copper oxychloride 85% WP อัตรา 30-50 กรัม/น้ำ 20 ลิตร) ในช่วงที่มีการระบาด',
    env: EnvRisk('> 75%', '26–30 °C', 'ฤดูฝนต่อเนื่อง / ต้นขาดความสมบูรณ์'),
  ),
  'Healthy': DiseaseInfo(
    th: 'ใบปกติ สมบูรณ์แข็งแรง',
    pathogen: '',
    guide: 'บำรุงรักษาธาตุอาหารสม่ำเสมอ ตรวจเช็กระบบน้ำ และหมั่นตรวจแปลงเป็นประจำ',
  ),
  'Leaf Blight': DiseaseInfo(
    th: 'โรคใบติด (ราใบติด)',
    pathogen: 'Rhizoctonia solani Kühn',
    guide: 'ตัดส่วนที่เป็นโรคเผาทำลาย พ่นด้วยสารกำจัดเชื้อรากลุ่มไตรอะโซล เช่น เฮกซะโคนาโซล (Hexaconazole 5% SC) หรือไดฟีโนโคนาโซล (Difenoconazole 25% EC)',
    env: EnvRisk('> 85%', '28–32 °C', 'ฤดูฝน / ทรงพุ่มทึบอับลม'),
  ),
  'Leaf Spot': DiseaseInfo(
    th: 'โรคใบจุดสนิม/ใบจุดทั่วไป',
    pathogen: 'Colletotrichum gloeosporioides (Penz.) Penz. & Sacc.',
    guide: 'ควบคุมความชื้นในทรงพุ่ม กำจัดวัชพืชใต้โคนต้น และฉีดพ่นสารป้องกันกำจัดเชื้อราประเภทโพรคลอราซ (Prochloraz) หรืออะซอกซีสโตรบิน (Azoxystrobin)',
  ),
};

enum Confidence { high, medium, low }

/// เกณฑ์เดียวกับเว็บแอป: สูง ≥ 85% และห่างอันดับสอง ≥ 30 จุด, ปานกลาง ≥ 60%, ต่ำ < 60%
Confidence confidenceLevel(double conf, double gap) {
  if (conf >= 85 && gap >= 30) return Confidence.high;
  if (conf >= 60) return Confidence.medium;
  return Confidence.low;
}

const Map<Confidence, String> kLevelTitle = {
  Confidence.high: 'ความมั่นใจสูง',
  Confidence.medium: 'ความมั่นใจปานกลาง',
  Confidence.low: 'ยังไม่แน่ใจ',
};

const Map<Confidence, String> kLevelText = {
  Confidence.high: 'ผลนี้ค่อนข้างน่าเชื่อถือ ใช้ประกอบการตัดสินใจได้',
  Confidence.medium: 'ควรถ่ายรูปใหม่อีกมุม หรือให้ผู้เชี่ยวชาญช่วยยืนยัน',
  Confidence.low: 'ผลนี้ยังเชื่อถือไม่ได้ ลองถ่ายใกล้ขึ้นให้เห็นแผลชัด หรือรูปนี้อาจไม่ใช่ใบทุเรียน/ไม่ใช่โรคที่ระบบรู้จัก',
};

/// ผลการตรวจหนึ่งครั้ง
class Diagnosis {
  final List<double> probs; // ความน่าจะเป็น 4 กลุ่ม (0..1)
  final List<double> cam; // แผนที่ Grad-CAM 7x7 (0..1)
  final DateTime time;
  final double ms;
  final bool sample;
  final String? imagePath; // ไฟล์รูปในประวัติ (ถ้ามี)

  const Diagnosis({
    required this.probs,
    required this.cam,
    required this.time,
    required this.ms,
    this.sample = false,
    this.imagePath,
  });

  List<int> get order {
    final idx = List<int>.generate(probs.length, (i) => i);
    idx.sort((a, b) => probs[b].compareTo(probs[a]));
    return idx;
  }

  int get top => order.first;
  double get conf => probs[top] * 100;
  double get gap => (probs[order[0]] - probs[order[1]]) * 100;
  Confidence get level => confidenceLevel(conf, gap);
  String get className => kClasses[top];
  DiseaseInfo get info => kInfo[className]!;

  Map<String, dynamic> toJson() => {
        'probs': probs.map((p) => (p * 1000).round() / 1000).toList(),
        'cam': cam.map((v) => (v * 100).round() / 100).toList(),
        'time': time.millisecondsSinceEpoch,
        'ms': ms,
        'img': imagePath,
      };

  static Diagnosis fromJson(Map<String, dynamic> j) => Diagnosis(
        probs: (j['probs'] as List).map((e) => (e as num).toDouble()).toList(),
        cam: (j['cam'] as List).map((e) => (e as num).toDouble()).toList(),
        time: DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
        ms: (j['ms'] as num?)?.toDouble() ?? 0,
        imagePath: j['img'] as String?,
      );
}

const _thMonths = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

/// วันที่แบบไทย เช่น 16 ต.ค. 2569 15:33
String thaiDateTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.day} ${_thMonths[t.month - 1]} ${t.year + 543} ${two(t.hour)}:${two(t.minute)}';
}
