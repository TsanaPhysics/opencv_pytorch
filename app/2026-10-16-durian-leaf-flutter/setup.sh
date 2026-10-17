#!/usr/bin/env bash
# ตั้งค่าโปรเจกต์ครั้งแรก (macOS / Linux): สร้างโฟลเดอร์ android/ios แล้วปรับค่าให้หมอใบทุเรียน
set -e
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "ไม่พบคำสั่ง flutter — ติดตั้ง Flutter ก่อน: https://docs.flutter.dev/get-started/install"; exit 1; }
flutter create --org th.ac.rbru --project-name durian_leaf_doctor --platforms android,ios .
dart run tool/setup_platforms.dart
flutter pub get
echo ""
echo "พร้อมแล้ว ✔"
echo "  ต่อมือถือ Android (เปิด USB debugging) แล้วรัน:   flutter run --release"
echo "  สร้างไฟล์ติดตั้ง APK:                              flutter build apk --release --split-per-abi"
