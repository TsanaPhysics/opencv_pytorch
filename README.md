# การออกแบบและพัฒนาแอปพลิเคชันสมาร์ทโฟนวิเคราะห์โรคในทุเรียน
### สำหรับผู้เริ่มต้นไม่มีพื้นฐานการเขียนโค้ด (No-Code & Beginner-Friendly Edge AI Guide)

**ผู้แต่ง/ผู้พัฒนา:** ผู้ช่วยศาสตราจารย์ ดร.ชีวะ ทัศนา  
**สังกัด:** ศูนย์วิจัยฟิสิกส์ดิจิทัลและปัญญาประดิษฐ์ทางการเกษตร คณะวิทยาศาสตร์และเทคโนโลยี มหาวิทยาลัยราชภัฏรำไพพรรณี  
**เอกสารวิชาการฉบับเต็ม:** [เอกสารคำสอนและคู่มือฉบับสมบูรณ์ (PDF)](file:///Applications/XAMPP/xamppfiles/htdocs/G3_Agri_Microbiology_SmartFarm/3.6_CV-pytorch/docs/main.pdf)

<p align="center">
  <img src="docs/figures/cover_art.jpg" width="340" alt="หน้าปกคู่มือการออกแบบและพัฒนาแอปพลิเคชันสมาร์ทโฟนวิเคราะห์โรคในทุเรียน" />
</p>

---

## 🌟 จุดเด่นของระบบ (Key Highlights)

1. **สำหรับผู้เริ่มต้นโดยเฉพาะ (100% Beginner-Friendly & No-Code):** ไม่จำเป็นต้องมีพื้นฐานเขียนโปรแกรม สามารถคลิกรันผ่าน Google Colab (1-Click) ได้ทันที
2. **โมเดลน้ำหนักเบาประสิทธิภาพสูง (MobileNetV3):** ขนาดกะทัดรัด ประมวลผลรวดเร็ว รองรับการนำไปติดตั้งบนสมาร์ทโฟน iOS/Android (ผ่าน Flutter) และบอร์ดฝังตัว Edge AI
3. **ระบบอธิบายเหตุผลด้วยภาพ (Explainable AI - Grad-CAM):** สร้างแผนที่ความร้อน (Heatmap) ไฮไลต์ตำแหน่งแผลบนใบไม้ เพื่อยืนยันความถูกต้องทางพยาธิวิทยาพืช
4. **ส่งออกสู่มาตรฐานสากล ONNX:** แปลงโมเดล PyTorch สู่ ONNX รันบนอุปกรณ์พกพาในสวนทุเรียนได้แบบออฟไลน์ 100% ไม่ต้องต่อเน็ต
5. **คู่มือวิชาการมาตรฐาน RBRU 6x9 นิ้ว:** จัดทำด้วยระบบ XeLaTeX สวยงาม คมชัดระดับเวกเตอร์ 100%

---

## 📁 โครงสร้างโปรเจกต์ (Project Architecture)

```text
3.6_CV-pytorch/
├── configs/
│   └── model_config.json                 # การแมปคลาส, ภาษาไทย-อังกฤษ, คำแนะนำการรักษา, Normalization values
├── data/
│   └── durian_dataset/                   # ชุดข้อมูลภาพถ่ายใบพืช แบ่งตามโฟลเดอร์คลาส
│       ├── Algal Leaf Spot/              # โรคใบจุดสาหร่าย (Cephaleuros virescens)
│       ├── Leaf Blight/                  # โรคใบติด (Rhizoctonia solani)
│       ├── Leaf Spot/                    # โรคใบจุดสนิม/ใบจุดทั่วไป (Colletotrichum gloeosporioides)
│       └── Healthy/                      # ใบสมบูรณ์แข็งแรง
├── docs/                                 # เอกสารคำสอนและคู่มือวิชาการ XeLaTeX มาตรฐานสากล
│   ├── main.tex                          # ต้นฉบับเอกสารคู่มือ (หน้าปก 3D, หน้าปกในเวกเตอร์ Dark Mode)
│   ├── main.pdf                          # เอกสารคู่มือฉบับสมบูรณ์ความละเอียดสูง (23 หน้า)
│   ├── figures/                          # คลังภาพหน้าปกทุกเวอร์ชันและภาพถ่ายทางการ
│   │   ├── cover_art.jpg                 # ภาพปกปัจจุบัน (Active Final Cover Artwork)
│   │   ├── cover_full_typeset_rendered.png # หน้าปกรวมจัดหน้าและตัวหนังสือสมบูรณ์ความละเอียดสูง
│   │   ├── cover_v5_exact_authentic_final.jpg # ภาพปกเวอร์ชัน 5 (โครงหน้า ผศ.ดร.ชีวะ 100% ชุด LEQs xAI)
│   │   ├── cover_v4_leqs_xai_outfit.jpg   # ภาพปกเวอร์ชัน 4 (ชุดขาวสวนทุเรียน LEQs xAI)
│   │   ├── cover_v3_facial_adaptation.jpg # ภาพปกเวอร์ชัน 3 (ปรับรูปหน้าต้นฉบับ)
│   │   ├── cover_v2_smartphone_orchard.jpg# ภาพปกเวอร์ชัน 2 (แอปสมาร์ทโฟนส่องใบทุเรียน)
│   │   ├── cover_v1_concept_pixar.jpg     # ภาพปกเวอร์ชัน 1 (คอนเซปต์ 3D Pixar Durian)
│   │   └── chewa_official_portrait.png    # ภาพถ่ายทางการ ผศ.ดร.ชีวะ ทัศนา ต้นฉบับ
│   └── styles/rbruacademic.sty           # เทมเพลตฟอนต์และเลย์เอาต์มหาวิทยาลัยราชภัฏรำไพพรรณี
├── models/
│   └── durian_disease_model.pth          # Checkpoint ค่าน้ำหนักโมเดล PyTorch
├── notebooks/
│   └── durian_leaf_colab_training.ipynb  # Jupyter Notebook พร้อมรันบน Google Colab (T4 GPU)
├── src/
│   ├── train.py                          # สคริปต์การเทรน Transfer Learning และประเมินผล
│   ├── predict.py                        # สคริปต์ Inference พร้อมระบบ Explainable AI (Grad-CAM)
│   └── export_edge.py                    # สคริปต์แปลงโมเดลสู่มาตรฐาน ONNX สำหรับแอปพลิเคชันมือถือ
├── requirements.txt                      # รายการ Libraries และ Dependencies
└── README.md                             # คู่มือและเอกสารการใช้งาน
```

---

## 🚀 สถาปัตยกรรมและรายละเอียดทางเทคนิค

- **Model Backbone:** `MobileNetV3-Small` (Torchvision)
- **Pretrained Weights:** `ImageNet-1K` Transfer Learning
- **Classifier Head:** Custom `nn.Linear(in_features=1024, out_features=4)`
- **Data Augmentation:** 
  - Resize $224 \times 224$
  - Random Horizontal Flip
  - Random Rotation ($20^\circ$)
  - Normalization: Mean `[0.485, 0.456, 0.406]`, Std `[0.229, 0.224, 0.225]`
- **Loss Function:** `CrossEntropyLoss`
- **Optimizer:** `Adam` (Learning Rate = $0.0005$)
- **Data Splitting:** Train 80% / Validation 20% (Batch Size = 16)

---

## 🛠️ วิธีการติดตั้งและรันระบบ

### 1. ติดตั้ง Dependencies
```bash
pip install -r requirements.txt
```

### 2. รันการเทรนโมเดล (Local หรือ Server)
```bash
python src/train.py
```
โมเดลที่ดีที่สุดจะถูกบันทึกอัตโนมัติลงใน `models/durian_disease_model.pth`

### 3. รันการวินิจฉัยภาพใบพืช พร้อมระบบ Grad-CAM Heatmap
```bash
python src/predict.py path/to/leaf_image.jpg
```

### 4. ส่งออกโมเดลสู่มาตรฐาน ONNX เพื่อติดตั้งลงในแอปมือถือ
```bash
python src/export_edge.py
```

---

## ☁️ การรันบน Google Colab (No-Code Quick Start)
เกษตรกรและผู้เริ่มต้นสามารถเปิดไฟล์ `notebooks/durian_leaf_colab_training.ipynb` บน **Google Colab** เพื่อรันบนการ์ดจอ T4 GPU ฟรี เพียงกดปุ่ม **Runtime -> Run all** ระบบจะทำการดาวน์โหลดภาพใบทุเรียน เทรนโมเดล และสร้างรายงานการประเมินผลพร้อมภาพถ่ายความร้อนชี้จุดเกิดโรคให้โดยอัตโนมัติ!
