#!/usr/bin/env python3
"""
Extract and consolidate Durian Leaf Disease Dataset into ./dataset
Mapping classes to standard:
- AlgalLeafSpot -> Algal Leaf Spot
- LeafBlight    -> Leaf Blight
- LeafSpot      -> Leaf Spot
- NoDisease     -> Healthy
"""

import os
import shutil
import zipfile
from pathlib import Path
from PIL import Image

TARGET_DIR = Path("dataset").resolve()
TEMP_EXTRACT = Path("temp_rf_extract").resolve()

CLASS_MAP = {
    "AlgalLeafSpot": "Algal Leaf Spot",
    "LeafBlight": "Leaf Blight",
    "LeafSpot": "Leaf Spot",
    "NoDisease": "Healthy"
}

IMG_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"}

def process_zip(zip_path: Path):
    if not zip_path.exists():
        return
    print(f"[*] Processing archive: {zip_path.name} ...")
    if TEMP_EXTRACT.exists():
        shutil.rmtree(TEMP_EXTRACT)
    TEMP_EXTRACT.mkdir(parents=True, exist_ok=True)
    
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(TEMP_EXTRACT)

    for target_name in CLASS_MAP.values():
        (TARGET_DIR / target_name).mkdir(parents=True, exist_ok=True)

    copied = 0
    for split in ["train", "valid", "test"]:
        split_dir = TEMP_EXTRACT / split
        if not split_dir.exists():
            continue
        for src_cls, dst_cls in CLASS_MAP.items():
            folder = split_dir / src_cls
            if not folder.exists():
                continue
            for img_path in folder.iterdir():
                if img_path.is_file() and img_path.suffix.lower() in IMG_EXT:
                    dest_file = TARGET_DIR / dst_cls / f"{split}_{img_path.name}"
                    if not dest_file.exists():
                        try:
                            with Image.open(img_path) as im:
                                im.verify()
                            shutil.copy2(img_path, dest_file)
                            copied += 1
                        except Exception as e:
                            print(f"[!] Skipping corrupt image {img_path.name}: {e}")
    print(f"    Copied and validated {copied} new images.")
    if TEMP_EXTRACT.exists():
        shutil.rmtree(TEMP_EXTRACT)
    zip_path.unlink(missing_ok=True)

def main():
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    for target_name in CLASS_MAP.values():
        (TARGET_DIR / target_name).mkdir(parents=True, exist_ok=True)

    for zf in [Path("test_rf_aug.zip"), Path("test_rf.zip")]:
        if zf.exists():
            process_zip(zf)

    # Count final images
    print("\n" + "="*55)
    print("🌿 Durian Leaf Disease Dataset (./dataset)")
    print("="*55)
    total_imgs = 0
    for dst_cls in sorted(CLASS_MAP.values()):
        folder = TARGET_DIR / dst_cls
        imgs = [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXT]
        total_imgs += len(imgs)
        print(f"  • {dst_cls:20s}: {len(imgs):4d} images ({folder})")
    print("-" * 55)
    print(f"  Total Valid Images : {total_imgs:4d} images")
    print("="*55)
    print("[OK] Dataset is fully prepared and ready for model training in PyTorch & Colab.")

if __name__ == "__main__":
    main()
