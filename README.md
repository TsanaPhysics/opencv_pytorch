# ระบบตรวจจับโรคใบทุเรียนด้วยเทคโนโลยี Computer Vision & PyTorch
**โปรเจกต์:** Agri Microbiology SmartFarm — Computer Vision System  
**เป้าหมาย:** วินิจฉัยโรคใบไม้ทุเรียน 4 กลุ่มอาการด้วยโมเดล Deep Learning น้ำหนักเบา (MobileNetV3-Small)

---

## 📁 โครงสร้างโปรเจกต์ (Project Architecture)

```text
3.6_CV-pytorch/
├── configs/
│   └── model_config.json                 # การแมปคลาส, ภาษาไทย-อังกฤษ, คำแนะนำการรักษา, Normalization values
├── data/
│   └── durian_dataset/                   # ชุดข้อมูลภาพถ่ายใบพืช แบ่งตามโฟลเดอร์คลาส
│       ├── Algal Leaf Spot/              # โรคใบจุดสาหร่าย
│       ├── Leaf Blight/                  # โรคใบติด (ราใบติด)
│       ├── Leaf Spot/                    # โรคใบจุดสนิม/ใบจุดทั่วไป
│       └── Healthy/                      # ใบสมบูรณ์แข็งแรง
├── models/
│   └── durian_disease_model.pth          # Checkpoint ค่าน้ำหนักโมเดล PyTorch
├── notebooks/
│   └── durian_leaf_colab_training.ipynb  # Jupyter Notebook พร้อมรันบน Google Colab (T4 GPU)
├── src/
│   ├── train.py                          # สคริปต์การเทรน Transfer Learning และประเมินผล
│   └── predict.py                        # สคริปต์ Inference ตรวจสอบภาพใบพืชใหม่
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

### 3. รันการวินิจฉัยภาพใบพืช (Inference)
```bash
python src/predict.py path/to/leaf_image.jpg
```

---

## ☁️ การรันบน Google Colab
สามารถเปิดไฟล์ `notebooks/durian_leaf_colab_training.ipynb` บน **Google Colab** เพื่อรันบนการ์ดจอ T4 GPU ฟรี พร้อมระบบ Mount ไปยัง **Google Drive** เพื่อบันทึกโมเดลและ Config อัตโนมัติ ป้องกันข้อมูลสูญหายเมื่อตัดการเชื่อมต่อ
