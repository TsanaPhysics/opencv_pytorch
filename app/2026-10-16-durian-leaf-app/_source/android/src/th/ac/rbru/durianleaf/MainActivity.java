package th.ac.rbru.durianleaf;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.Manifest;
import android.webkit.PermissionRequest;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.webkit.MimeTypeMap;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/** หน้าหลัก: แสดงเว็บแอป "หมอใบทุเรียน" จากไฟล์ในแอป (ทำงานออฟไลน์ทั้งหมด) */
public class MainActivity extends Activity {
    // โดเมนจำลองสำหรับเสิร์ฟไฟล์ในแอปแบบ https (ทำให้ fetch()/WebAssembly ทำงานได้เหมือนบนเว็บ)
    static final String HOST = "appassets.androidplatform.net";
    static final String BASE = "https://" + HOST + "/";
    static final int REQ_CAMERA = 11, REQ_GALLERY = 12, PERM_LIVE = 21, PERM_SHOT = 22;
    private PermissionRequest pendingWebPerm;

    private WebView web;
    private ValueCallback<Uri[]> pending;
    private Uri cameraUri;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        web = new WebView(this);
        setContentView(web);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);          // ใช้เก็บประวัติการตรวจ
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setMediaPlaybackRequiresUserGesture(false);   // วิดีโอจากกล้องในโหมดสดเล่นได้ทันที

        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (!HOST.equals(u.getHost())) return null;
                String path = u.getPath();
                if (path == null || path.equals("/") || path.isEmpty()) path = "/index.html";
                String asset = "www" + path;
                try {
                    InputStream in = getAssets().open(asset);
                    Map<String, String> h = new HashMap<>();
                    h.put("Cache-Control", "no-cache");
                    return new WebResourceResponse(mime(path), mime(path).startsWith("text/") ? "utf-8" : null, 200, "OK", h, in);
                } catch (IOException e) {
                    return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", new HashMap<String, String>(), null);
                }
            }
            @Override
            @SuppressWarnings("deprecation")
            public boolean shouldOverrideUrlLoading(WebView v, String url) {
                Uri u = Uri.parse(url);
                if (HOST.equals(u.getHost())) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (ActivityNotFoundException ignored) { }
                return true;   // ลิงก์ภายนอกเปิดในเบราว์เซอร์
            }
        });

        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams p) {
                if (pending != null) pending.onReceiveValue(null);
                pending = cb;
                if (p.isCaptureEnabled()) {
                    if (hasCamera()) { if (openCamera()) return true; }
                    else { requestPermissions(new String[]{Manifest.permission.CAMERA}, PERM_SHOT); return true; }
                }
                return openGallery();
            }
            // โหมดกล้องสด: หน้าเว็บขอใช้กล้อง (getUserMedia) → ขอสิทธิ์ CAMERA จากผู้ใช้ก่อน
            @Override
            public void onPermissionRequest(final PermissionRequest req) {
                runOnUiThread(new Runnable() { public void run() {
                    boolean wantsVideo = false;
                    for (String r : req.getResources()) if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(r)) wantsVideo = true;
                    if (!wantsVideo || !HOST.equals(req.getOrigin().getHost())) { req.deny(); return; }
                    if (hasCamera()) { req.grant(new String[]{PermissionRequest.RESOURCE_VIDEO_CAPTURE}); return; }
                    pendingWebPerm = req;
                    requestPermissions(new String[]{Manifest.permission.CAMERA}, PERM_LIVE);
                }});
            }
        });

        if (state != null) web.restoreState(state); else web.loadUrl(BASE + "index.html");
    }

    private boolean openCamera() {
        try {
            cameraUri = CaptureProvider.newCaptureUri(this);
            Intent i = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            i.putExtra(MediaStore.EXTRA_OUTPUT, cameraUri);
            i.setClipData(ClipData.newRawUri("", cameraUri));
            i.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivityForResult(i, REQ_CAMERA);
            return true;
        } catch (Exception e) {
            return false;   // ไม่มีแอปกล้อง → ใช้คลังรูปแทน
        }
    }

    private boolean openGallery() {
        try {
            Intent i = new Intent(Intent.ACTION_GET_CONTENT);
            i.addCategory(Intent.CATEGORY_OPENABLE);
            i.setType("image/*");
            startActivityForResult(Intent.createChooser(i, "เลือกรูปใบทุเรียน"), REQ_GALLERY);
            return true;
        } catch (Exception e) {
            if (pending != null) { pending.onReceiveValue(null); pending = null; }
            return false;
        }
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (pending == null) return;
        Uri[] result = null;
        if (res == RESULT_OK) {
            if (req == REQ_CAMERA && cameraUri != null) result = new Uri[]{cameraUri};
            else if (req == REQ_GALLERY && data != null && data.getData() != null) result = new Uri[]{data.getData()};
        }
        pending.onReceiveValue(result);
        pending = null;
    }

    private boolean hasCamera() {
        return checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public void onRequestPermissionsResult(int code, String[] perms, int[] results) {
        boolean ok = results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED;
        if (code == PERM_LIVE && pendingWebPerm != null) {
            if (ok) pendingWebPerm.grant(new String[]{PermissionRequest.RESOURCE_VIDEO_CAPTURE}); else pendingWebPerm.deny();
            pendingWebPerm = null;
        } else if (code == PERM_SHOT) {
            if (!(ok && openCamera())) openGallery();   // ไม่อนุญาตกล้อง → เปิดคลังรูปแทน
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) web.goBack(); else super.onBackPressed();
    }

    static String mime(String path) {
        String p = path.toLowerCase();
        if (p.endsWith(".html")) return "text/html";
        if (p.endsWith(".js") || p.endsWith(".mjs")) return "text/javascript";
        if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".wasm")) return "application/wasm";
        if (p.endsWith(".onnx")) return "application/octet-stream";
        if (p.endsWith(".ttf")) return "font/ttf";
        if (p.endsWith(".json")) return "application/json";
        String ext = MimeTypeMap.getFileExtensionFromUrl(p);
        String m = ext == null ? null : MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
        return m != null ? m : "application/octet-stream";
    }
}
