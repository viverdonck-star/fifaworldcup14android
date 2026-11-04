package com.wc14.test;

import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.system.ErrnoException;
import android.system.Os;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

import org.libsdl.app.SDLActivity;

// The game, started by the launcher's Play in a process of its own (":game"
// in the manifest), as fifawc14.exe on PC. It reads its settings from the
// app's folder (REX_APP_DIR) and the game from the document the player picked
// in the launcher, opened again here: game_data_root is set to its descriptor.
public class MainActivity extends SDLActivity {
    // Open for as long as the game runs.
    private static ParcelFileDescriptor game;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        File folder = LauncherActivity.DataFolder(this);
        SharedPreferences prefs = getSharedPreferences(LauncherActivity.PREFS, MODE_PRIVATE);
        String uri = prefs.getString("uri", null);
        if (uri != null) game = LauncherActivity.Open(this, Uri.parse(uri));
        if (game != null) SetGameDataRoot(new File(folder, "fifawc14.toml"), "/proc/self/fd/" + game.getFd());
        try {
            Os.setenv("REX_APP_DIR", folder.getAbsolutePath(), true);
            Os.setenv("REX_GPU_BACKEND", "vulkan", true);
            SetGpuDriver(new File(folder, "fifawc14.toml"));
        } catch (ErrnoException e) {
            throw new RuntimeException(e);
        }
        super.onCreate(savedInstanceState);
        LauncherActivity.Immersive(this);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) LauncherActivity.Immersive(this);
    }

    // The game's own process ends with it: the next Play starts afresh.
    @Override
    protected void onDestroy() {
        super.onDestroy();
        android.os.Process.killProcess(android.os.Process.myPid());
    }

    @Override
    protected String[] getLibraries() {
        return new String[] {"c++_shared", "rexruntime", "fifawc14"};
    }

    // The GPU driver the player chose in the launcher (gpu_driver in
    // fifawc14.toml): "builtin:<file>" is a driver in the APK (Turnip),
    // "imported:<file>" one they added, kept in the app's private storage
    // (drivers can't be loaded from shared storage). Missing or "system":
    // Qualcomm's own. The engine loads it through libadrenotools
    // (REX_VULKAN_DRIVER_*).
    private void SetGpuDriver(File toml) throws ErrnoException {
        String line = "";
        try {
            if (!toml.exists()) return;
            for (String setting : Files.readAllLines(toml.toPath(), StandardCharsets.UTF_8)) {
                String[] parts = setting.split("=", 2);
                if (parts.length == 2 && parts[0].trim().equals("gpu_driver")) {
                    line = parts[1].trim().replace("\"", "");
                }
            }
        } catch (Exception e) {
            return;
        }
        String nativeDir = getApplicationInfo().nativeLibraryDir;
        String dir = null;
        if (line.startsWith("builtin:")) dir = nativeDir;
        if (line.startsWith("imported:")) dir = new File(getFilesDir(), "drivers").getAbsolutePath();
        if (dir == null) return;
        String name = line.substring(line.indexOf(':') + 1);
        if (!new File(dir, name).exists()) return;
        // libadrenotools appends the name to the folder as it is.
        Os.setenv("REX_VULKAN_DRIVER_DIR", dir + "/", true);
        Os.setenv("REX_VULKAN_DRIVER_NAME", name, true);
        Os.setenv("REX_VULKAN_DRIVER_HOOK_DIR", nativeDir, true);
    }

    // fifawc14.toml's game_data_root line replaced (or added), the rest kept.
    private static void SetGameDataRoot(File toml, String path) {
        try {
            List<String> lines = toml.exists()
                    ? Files.readAllLines(toml.toPath(), StandardCharsets.UTF_8) : new ArrayList<>();
            String line = "game_data_root = \"" + path + "\"";
            boolean found = false;
            for (int i = 0; i < lines.size(); ++i) {
                if (lines.get(i).trim().startsWith("game_data_root")) {
                    lines.set(i, line);
                    found = true;
                }
            }
            if (!found) lines.add(0, line);
            Files.write(toml.toPath(), lines, StandardCharsets.UTF_8);
        } catch (Exception e) {
            // The game then says it can't find its files.
        }
    }
}
