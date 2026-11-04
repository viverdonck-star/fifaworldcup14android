package com.wc14.test;

import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

import org.libsdl.app.SDLActivity;

// The launcher (liblauncher.so, launcher/android/main_android.cpp): the game's
// menu, as on PC. The player's game is a document picked once with Android's
// file picker; reading it stays allowed (a persisted permission), and the
// native code reads it through /proc/self/fd/<n>. Play starts MainActivity,
// the game, in a process of its own.
public class LauncherActivity extends SDLActivity {
    static final String PREFS = "game";
    private static final int PICK_ISO = 1;

    private static LauncherActivity self;
    // Kept open while they're used: their descriptors are the native paths.
    private static ParcelFileDescriptor game, picked;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        self = this;
        super.onCreate(savedInstanceState);
        Immersive(this);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) Immersive(this);
    }

    // The whole screen: without this, Android's status and navigation bars stay
    // over the top and bottom 55 pixels, black (the game's activity, started
    // from here, kept them).
    static void Immersive(android.app.Activity activity) {
        android.view.Window window = activity.getWindow();
        window.setDecorFitsSystemWindows(false);
        // Phones with a camera notch: the picture goes beside it too, rather
        // than leaving a black band on that side.
        android.view.WindowManager.LayoutParams attributes = window.getAttributes();
        attributes.layoutInDisplayCutoutMode =
                android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        window.setAttributes(attributes);
        android.view.WindowInsetsController controller = window.getInsetsController();
        if (controller != null) {
            controller.hide(android.view.WindowInsets.Type.systemBars());
            controller.setSystemBarsBehavior(
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        }
    }

    @Override
    protected String[] getLibraries() {
        return new String[] {"c++_shared", "launcher"};
    }

    // ---------------------------------------------------------------- native

    // Settings, logs and saves: the app's own folder on shared storage.
    public static String dataFolder() {
        return DataFolder(self).getAbsolutePath();
    }

    static File DataFolder(android.content.Context context) {
        File folder = context.getExternalFilesDir(null);
        folder.mkdirs();
        return folder;
    }

    // The game picked before: "<path>\n<name>\n<uri>", or null.
    public static String openGame() {
        SharedPreferences prefs = self.getSharedPreferences(PREFS, MODE_PRIVATE);
        String uri = prefs.getString("uri", null);
        if (uri == null) return null;
        game = Open(self, Uri.parse(uri));
        if (game == null) return null;
        return "/proc/self/fd/" + game.getFd() + "\n" + prefs.getString("name", "") + "\n" + uri;
    }

    static ParcelFileDescriptor Open(android.content.Context context, Uri uri) {
        try {
            return context.getContentResolver().openFileDescriptor(uri, "r");
        } catch (Exception e) {
            return null;
        }
    }

    // The file picker; its answer goes to nativeIsoPicked.
    public static void pickIso() {
        self.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("*/*");
                self.startActivityForResult(intent, PICK_ISO);
            }
        });
    }

    // Continue on the setup screen: the picked document is the game from now on.
    public static void keepGame(String uri, String name) {
        self.getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                .putString("uri", uri).putString("name", name).commit();
        game = picked;
        picked = null;
    }

    public static void startGame() {
        self.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                self.startActivity(new Intent(self, MainActivity.class));
            }
        });
    }

    static native void nativeIsoPicked(String path, String name, String uri);

    // ------------------------------------------------------- logs and saves

    // Android 13 and later don't let the player open the app's folder, so the
    // launcher's Data settings work through the share menu and the file picker.

    private static final int EXPORT_SAVES = 2;
    private static final int IMPORT_SAVES = 3;

    // The logs and settings, zipped, to Android's share menu (to send them to
    // whoever helps with a problem).
    public static void shareLogs() {
        self.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                File folder = DataFolder(self);
                File zip = new File(ShareProvider.Folder(self), "wc14-logs.zip");
                String[] names = {"fifawc14.log", "launcher.log", "fifawc14.toml", "launcher.toml"};
                try (ZipOutputStream out = new ZipOutputStream(new FileOutputStream(zip))) {
                    for (String name : names) {
                        File file = new File(folder, name);
                        if (file.isFile()) AddToZip(out, file, name);
                    }
                } catch (IOException e) {
                    Toast(e.getMessage());
                    return;
                }
                Intent send = new Intent(Intent.ACTION_SEND);
                send.setType("application/zip");
                send.putExtra(Intent.EXTRA_STREAM, ShareProvider.UriFor(zip));
                send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                self.startActivity(Intent.createChooser(send, null));
            }
        });
    }

    // The saves, zipped, where the player chooses (Downloads, a cloud...).
    public static void exportSaves() {
        self.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("application/zip");
                intent.putExtra(Intent.EXTRA_TITLE, "wc14-saves-" + Today() + ".zip");
                self.startActivityForResult(intent, EXPORT_SAVES);
            }
        });
    }

    // Saves from an exported zip. The current ones are kept aside first
    // (saves-before-import-<date>), so nothing is lost.
    public static void importSaves() {
        self.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("*/*");
                self.startActivityForResult(intent, IMPORT_SAVES);
            }
        });
    }

    // ------------------------------------------------------------- drivers

    private static final int IMPORT_DRIVER = 4;

    // Imported drivers: in private storage, as a driver can't be loaded from
    // shared storage (MainActivity.SetGpuDriver reads them there).
    public static String driversFolder() {
        return DriversFolder(self).getAbsolutePath();
    }

    static File DriversFolder(android.content.Context context) {
        return new File(context.getFilesDir(), "drivers");
    }

    // Any Vulkan driver for Adreno: a .so, or a .zip as AdrenoTools takes them
    // (meta.json names the .so in it; without it, its first .so).
    public static void importDriver() {
        self.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("*/*");
                self.startActivityForResult(intent, IMPORT_DRIVER);
            }
        });
    }

    static native void nativeDriverImported(String text, boolean ok);

    private void ImportDriver(Uri uri) {
        String shown = uri.getLastPathSegment();
        try (Cursor cursor = getContentResolver().query(
                uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) shown = cursor.getString(0);
        } catch (Exception e) {
        }
        if (shown == null) shown = "driver";
        // Its name in GPU driver: the file's, without the extension, kept to
        // letters, digits, '.', '-' and '_'.
        String base = shown.replaceAll("(?i)\\.(zip|so)$", "").replaceAll("[^A-Za-z0-9._-]", "_");
        if (base.isEmpty() || base.startsWith(".")) base = "driver" + base;
        String name = base + ".so";
        File folder = DriversFolder(this);
        folder.mkdirs();
        File target = new File(folder, name);
        File part = new File(folder, name + ".part");
        try {
            byte[] head = new byte[4];
            try (java.io.InputStream in = getContentResolver().openInputStream(uri)) {
                if (in == null || in.read(head) != 4) throw new IOException("the file is empty");
            }
            if (head[0] == 'P' && head[1] == 'K') {
                ExtractDriver(uri, part);
            } else {
                try (java.io.InputStream in = getContentResolver().openInputStream(uri);
                     FileOutputStream out = new FileOutputStream(part)) {
                    Copy(in, out);
                }
            }
            String problem = CheckDriver(part);
            if (problem != null) throw new IOException(problem);
            if (target.exists()) target.delete();
            if (!part.renameTo(target)) throw new IOException("it couldn't be stored");
            nativeDriverImported(name, true);
        } catch (Exception e) {
            part.delete();
            nativeDriverImported(e.getMessage() != null ? e.getMessage() : e.toString(), false);
        }
    }

    // The driver in an AdrenoTools zip: meta.json's "libraryName", else the
    // first .so.
    private void ExtractDriver(Uri uri, File out) throws IOException {
        String wanted = null;
        try (ZipInputStream in = new ZipInputStream(getContentResolver().openInputStream(uri))) {
            for (ZipEntry entry; (entry = in.getNextEntry()) != null; ) {
                if (entry.getName().endsWith("meta.json")) {
                    java.io.ByteArrayOutputStream text = new java.io.ByteArrayOutputStream();
                    Copy(in, text);
                    try {
                        wanted = new org.json.JSONObject(text.toString("UTF-8")).optString("libraryName", null);
                    } catch (org.json.JSONException e) {
                        // A broken meta.json: the first .so then.
                    }
                    break;
                }
            }
        }
        try (ZipInputStream in = new ZipInputStream(getContentResolver().openInputStream(uri))) {
            for (ZipEntry entry; (entry = in.getNextEntry()) != null; ) {
                String entryName = new File(entry.getName()).getName();
                if (entry.isDirectory() || !entryName.endsWith(".so")) continue;
                if (wanted != null && !entryName.equals(wanted)) continue;
                try (FileOutputStream file = new FileOutputStream(out)) {
                    Copy(in, file);
                }
                return;
            }
        }
        throw new IOException("there's no driver (.so) in that zip");
    }

    // Null if `file` is a 64-bit ARM library, as the game needs; otherwise why not.
    private static String CheckDriver(File file) throws IOException {
        byte[] head = new byte[20];
        try (FileInputStream in = new FileInputStream(file)) {
            if (in.read(head) != head.length) return "it isn't a driver (.so)";
        }
        if (head[0] != 0x7F || head[1] != 'E' || head[2] != 'L' || head[3] != 'F') {
            return "it isn't a driver (.so)";
        }
        // ELFCLASS64, and e_machine EM_AARCH64 (183).
        if (head[4] != 2 || (head[18] & 0xFF) != 183 || head[19] != 0) {
            return "it isn't made for 64-bit ARM";
        }
        return null;
    }

    private static void Copy(java.io.InputStream in, java.io.OutputStream out) throws IOException {
        byte[] buffer = new byte[65536];
        for (int n; (n = in.read(buffer)) > 0; ) out.write(buffer, 0, n);
    }

    private void ExportSaves(Uri uri) {
        File saves = new File(DataFolder(this), "saves");
        try (ZipOutputStream out = new ZipOutputStream(getContentResolver().openOutputStream(uri))) {
            AddFolderToZip(out, saves, "");
            Toast("Saves exported");
        } catch (Exception e) {
            Toast("Export failed: " + e.getMessage());
        }
    }

    private void ImportSaves(Uri uri) {
        File folder = DataFolder(this);
        File incoming = new File(folder, "saves-importing");
        DeleteFolder(incoming);
        int files = 0;
        try (ZipInputStream in = new ZipInputStream(getContentResolver().openInputStream(uri))) {
            for (ZipEntry entry; (entry = in.getNextEntry()) != null; ) {
                File file = new File(incoming, entry.getName());
                // Nothing may land outside the saves folder.
                if (!file.getCanonicalPath().startsWith(incoming.getCanonicalPath() + File.separator)) {
                    throw new IOException("unexpected path " + entry.getName());
                }
                if (entry.isDirectory()) {
                    file.mkdirs();
                    continue;
                }
                file.getParentFile().mkdirs();
                try (FileOutputStream out = new FileOutputStream(file)) {
                    byte[] buffer = new byte[65536];
                    for (int n; (n = in.read(buffer)) > 0; ) out.write(buffer, 0, n);
                }
                ++files;
            }
        } catch (Exception e) {
            DeleteFolder(incoming);
            Toast("Import failed: " + e.getMessage());
            return;
        }
        if (files == 0) {
            DeleteFolder(incoming);
            Toast("Import failed: no saves in that file");
            return;
        }
        File saves = new File(folder, "saves");
        if (saves.exists()) saves.renameTo(new File(folder, "saves-before-import-" + Today()));
        incoming.renameTo(saves);
        Toast("Saves imported");
    }

    private static void AddFolderToZip(ZipOutputStream out, File folder, String prefix) throws IOException {
        File[] children = folder.listFiles();
        if (children == null) return;
        for (File child : children) {
            if (child.isDirectory()) AddFolderToZip(out, child, prefix + child.getName() + "/");
            else AddToZip(out, child, prefix + child.getName());
        }
    }

    private static void AddToZip(ZipOutputStream out, File file, String name) throws IOException {
        out.putNextEntry(new ZipEntry(name));
        try (FileInputStream in = new FileInputStream(file)) {
            byte[] buffer = new byte[65536];
            for (int n; (n = in.read(buffer)) > 0; ) out.write(buffer, 0, n);
        }
        out.closeEntry();
    }

    private static void DeleteFolder(File folder) {
        File[] children = folder.listFiles();
        if (children != null) for (File child : children) DeleteFolder(child);
        folder.delete();
    }

    private static String Today() {
        return new java.text.SimpleDateFormat("yyyy-MM-dd-HHmm", java.util.Locale.ROOT).format(new java.util.Date());
    }

    private static void Toast(final String text) {
        self.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                android.widget.Toast.makeText(self, text, android.widget.Toast.LENGTH_LONG).show();
            }
        });
    }

    // ---------------------------------------------------------------- picker

    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (result != RESULT_OK || data == null || data.getData() == null) {
            return;
        }
        if (request == EXPORT_SAVES) {
            ExportSaves(data.getData());
            return;
        }
        if (request == IMPORT_SAVES) {
            ImportSaves(data.getData());
            return;
        }
        if (request == IMPORT_DRIVER) {
            ImportDriver(data.getData());
            return;
        }
        if (request != PICK_ISO) {
            return;
        }
        Uri uri = data.getData();
        try {
            getContentResolver().takePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (SecurityException e) {
            // Readable for now, though not after a restart.
        }
        ParcelFileDescriptor opened = Open(this, uri);
        if (opened == null) return;
        if (picked != null && picked != game) {
            try { picked.close(); } catch (Exception e) { }
        }
        picked = opened;
        String name = uri.getLastPathSegment();
        try (Cursor cursor = getContentResolver().query(
                uri, new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) name = cursor.getString(0);
        } catch (Exception e) {
        }
        nativeIsoPicked("/proc/self/fd/" + picked.getFd(), name, uri.toString());
    }
}
