#!/usr/bin/env python3
"""
Download and prepare Durian Leaf Disease Dataset.
Extracted and adapted from notebooks/2026-10-16-durian_leaf_colab_training.ipynb.
"""

import os
import sys
import shutil
import urllib.request
import zipfile
from pathlib import Path

DATASET_URL = "https://github.com/costalferz/Leaf-Disease-Classification-Augment/archive/refs/heads/main.zip"
TARGET_DIR = Path("dataset").resolve()
WORK_DIR = Path("work_data_download").resolve()
ZIP_PATH = WORK_DIR / "durian_dataset.zip"

IMG_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tif", ".tiff"}

def has_images(folder: Path) -> bool:
    try:
        return any(p.is_file() and p.suffix.lower() in IMG_EXT for p in folder.iterdir())
    except Exception:
        return False

def find_dataset_root(top: Path) -> Path | None:
    best_n, best_dir = 0, None
    for dp, dns, _ in os.walk(top):
        dns[:] = [d for d in dns if not d.startswith(".") and d != "__MACOSX"]
        n = sum(1 for d in dns if has_images(Path(dp) / d))
        if n > best_n:
            best_n, best_dir = n, Path(dp)
    return best_dir if best_n >= 2 else None

def safe_extract(zip_path: Path, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as z:
        for m in z.infolist():
            target = (out_dir / m.filename).resolve()
            if not str(target).startswith(str(out_dir.resolve())):
                raise RuntimeError(f"Unsafe path in zip: {m.filename}")
        z.extractall(out_dir)

def main():
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    TARGET_DIR.mkdir(parents=True, exist_ok=True)

    print(f"[*] Downloading Durian Leaf Dataset from: {DATASET_URL}")
    req = urllib.request.Request(DATASET_URL, headers={"User-Agent": "Mozilla/5.0"})
    
    with urllib.request.urlopen(req, timeout=180) as response, open(ZIP_PATH, "wb") as out_file:
        total_size = int(response.headers.get("Content-Length", 0))
        downloaded = 0
        block_size = 65536
        while True:
            buffer = response.read(block_size)
            if not buffer:
                break
            downloaded += len(buffer)
            out_file.write(buffer)
            if total_size > 0:
                percent = (downloaded / total_size) * 100
                sys.stdout.write(f"\r    Progress: {downloaded / 1024 / 1024:.2f} MB / {total_size / 1024 / 1024:.2f} MB ({percent:.1f}%)")
            else:
                sys.stdout.write(f"\r    Downloaded: {downloaded / 1024 / 1024:.2f} MB")
            sys.stdout.flush()

    print(f"\n[*] Download complete ({ZIP_PATH.stat().st_size / 1024 / 1024:.2f} MB).")
    print(f"[*] Extracting archive ...")
    extract_dir = WORK_DIR / "extracted"
    safe_extract(ZIP_PATH, extract_dir)

    print("[*] Locating leaf disease dataset root folder ...")
    root = find_dataset_root(extract_dir)
    if not root:
        print("[!] Error: Could not find disease image directories in extracted zip.")
        sys.exit(1)

    print(f"[*] Found dataset root at: {root}")
    classes = [d for d in root.iterdir() if d.is_dir() and has_images(d)]
    print(f"[*] Found {len(classes)} disease classes:")

    total_images = 0
    for cls_dir in sorted(classes, key=lambda x: x.name):
        dest_cls = TARGET_DIR / cls_dir.name
        dest_cls.mkdir(parents=True, exist_ok=True)
        img_files = [p for p in cls_dir.iterdir() if p.is_file() and p.suffix.lower() in IMG_EXT]
        for img in img_files:
            shutil.copy2(img, dest_cls / img.name)
        count = len(img_files)
        total_images += count
        print(f"    - {cls_dir.name:30s}: {count:5d} images -> {dest_cls}")

    print(f"\n[OK] Successfully populated '{TARGET_DIR}' with {total_images} images across {len(classes)} classes.")

    # Cleanup temporary files
    try:
        shutil.rmtree(WORK_DIR)
        print("[*] Cleaned up temporary download cache.")
    except Exception as e:
        print(f"[!] Note: Could not remove temporary work dir: {e}")

if __name__ == "__main__":
    main()
