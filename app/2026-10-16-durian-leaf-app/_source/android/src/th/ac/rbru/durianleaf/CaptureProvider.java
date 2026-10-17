package th.ac.rbru.durianleaf;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileNotFoundException;

/** ที่เก็บรูปจากกล้องชั่วคราว (แทน FileProvider) ให้แอปกล้องเขียนรูปลงพื้นที่ส่วนตัวของแอป */
public class CaptureProvider extends ContentProvider {
    static final String AUTH = "th.ac.rbru.durianleaf.capture";

    static Uri newCaptureUri(Context c) {
        String name = "leaf_" + System.currentTimeMillis() + ".jpg";
        File dir = new File(c.getCacheDir(), "captures");
        if (!dir.exists()) dir.mkdirs();
        File[] old = dir.listFiles();          // ลบรูปเก่าที่ค้าง เก็บไว้ไม่เกิน 5 รูป
        if (old != null && old.length > 5) for (File f : old) f.delete();
        return Uri.parse("content://" + AUTH + "/" + name);
    }

    private File fileFor(Uri uri) throws FileNotFoundException {
        String name = uri.getLastPathSegment();
        if (name == null || name.contains("/") || name.contains("..")) throw new FileNotFoundException("bad name");
        return new File(new File(getContext().getCacheDir(), "captures"), name);
    }

    @Override public boolean onCreate() { return true; }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        File f = fileFor(uri);
        int m = mode.contains("w")
                ? ParcelFileDescriptor.MODE_READ_WRITE | ParcelFileDescriptor.MODE_CREATE | (mode.contains("t") || "w".equals(mode) ? ParcelFileDescriptor.MODE_TRUNCATE : 0)
                : ParcelFileDescriptor.MODE_READ_ONLY;
        if (mode.contains("w")) f.getParentFile().mkdirs();
        return ParcelFileDescriptor.open(f, m);
    }

    @Override
    public Cursor query(Uri uri, String[] proj, String sel, String[] args, String sort) {
        MatrixCursor c = new MatrixCursor(new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE});
        try { File f = fileFor(uri); c.addRow(new Object[]{f.getName(), f.length()}); } catch (FileNotFoundException ignored) { }
        return c;
    }

    @Override public String getType(Uri uri) { return "image/jpeg"; }
    @Override public Uri insert(Uri uri, ContentValues v) { return null; }
    @Override public int delete(Uri uri, String s, String[] a) { return 0; }
    @Override public int update(Uri uri, ContentValues v, String s, String[] a) { return 0; }
}
