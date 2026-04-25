package com.sjsu.boreas.ui.chat;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;

public final class FileUtils {
    private FileUtils() {}

    public static File copyUriToCache(Context ctx, Uri uri, String prefix) throws Exception {
        ContentResolver cr = ctx.getContentResolver();
        String name = getDisplayName(cr, uri);
        if (name == null) name = prefix;

        File out = new File(ctx.getCacheDir(), System.currentTimeMillis() + "_" + name);
        try (InputStream in = cr.openInputStream(uri); FileOutputStream fos = new FileOutputStream(out)) {
            if (in == null) throw new Exception("Can't open file");
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) fos.write(buf, 0, n);
        }
        return out;
    }

    private static String getDisplayName(ContentResolver cr, Uri uri) {
        Cursor c = null;
        try {
            c = cr.query(uri, null, null, null, null);
            if (c != null && c.moveToFirst()) {
                int idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (idx >= 0) return c.getString(idx);
            }
        } catch (Exception ignored) {
        } finally {
            if (c != null) c.close();
        }
        return null;
    }
}
