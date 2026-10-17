#!/bin/bash
# สร้าง APK โดยไม่ใช้ Gradle: aapt → javac → dx → aapt → zipalign → apksigner
set -e
SDK=/usr/lib/android-sdk/platforms/android-23/android.jar
rm -rf gen obj out assets && mkdir -p gen obj out assets/www
cp -r /home/claude/app/apk_assets/* assets/www/
aapt package -f -m -J gen -M AndroidManifest.xml -S res -I $SDK
javac --release 8 -nowarn -Xlint:-options -encoding UTF-8 -classpath $SDK -d obj $(find src gen -name "*.java")
dalvik-exchange --dex --output=out/classes.dex obj
aapt package -f -M AndroidManifest.xml -S res -A assets -I $SDK -F out/unsigned.apk -0 wasm -0 onnx -0 ttf
(cd out && aapt add unsigned.apk classes.dex >/dev/null)
zipalign -f -p 4 out/unsigned.apk out/aligned.apk
if [ ! -f signing/durianleaf-release.jks ]; then
  mkdir -p signing
  PASS=$(python3 -c "import secrets;print(secrets.token_urlsafe(18))")
  echo "$PASS" > signing/keystore-password.txt
  keytool -genkeypair -keystore signing/durianleaf-release.jks -alias durianleaf -keyalg RSA -keysize 3072 -validity 10000 \
    -storepass "$PASS" -keypass "$PASS" -dname "CN=Chewa Thassana, OU=Digital Agriculture and Environment, O=Rambhai Barni Rajabhat University, L=Chanthaburi, C=TH" 2>/dev/null
fi
PASS=$(cat signing/keystore-password.txt)
apksigner sign --ks signing/durianleaf-release.jks --ks-key-alias durianleaf --ks-pass pass:$PASS --key-pass pass:$PASS --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --out out/2026-10-16-durian-leaf-app.apk out/aligned.apk
apksigner verify -v --min-sdk-version 24 out/2026-10-16-durian-leaf-app.apk | head -6
ls -la out/2026-10-16-durian-leaf-app.apk
