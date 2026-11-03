package com.wc14.test;

import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;

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

    // ---------------------------------------------------------------- picker

    @Override
    protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request != PICK_ISO || result != RESULT_OK || data == null || data.getData() == null) {
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
