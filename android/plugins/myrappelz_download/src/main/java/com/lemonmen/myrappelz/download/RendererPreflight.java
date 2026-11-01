package com.lemonmen.myrappelz.download;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

/**
 * Страховка от вылета Vulkan до запуска скриптов (RendererGuard в игре — CLAUDE.md, раздел «Рендерер»).
 * <p>
 * Файлы игры (формат ConfigFile / project.godot, текст): состояние user://renderer.cfg (секция [renderer]: armed,
 * confirmed, …) и рендерер следующего запуска user://renderer_override.cfg (application/config/
 * project_settings_override; Godot читает его в Main::setup — в GodotLib.setup из onInitNativeLayer, после
 * создания плагинов). Пути передаёт игра (rememberRendererFiles → SharedPreferences), без них — getFilesDir()
 * (это user:// Godot на Android).
 * <p>
 * beforeEngine (конструктор плагина: Godot.onCreate → GodotPluginRegistry, до Main::setup): файл говорит «Vulkan», а
 * <ul>
 * <li>в состоянии armed=true (прошлая проверка Vulkan не дошла до подтверждения, а файл почему-то остался на Vulkan)
 * — файл на Compatibility (игра при старте засчитает сбой);</li>
 * <li>или у телефона нет Vulkan 1.0.3 (meetsVulkanRequirements — Godot 4.3 бросил бы IllegalStateException
 * «нет Vulkan» и закрылся) — файл на Compatibility и armed=true.</li>
 * </ul>
 * armBeforeVulkan (onMainCreate: Godot.onInitRenderView — настройки этого запуска уже прочитаны, Vulkan-вид создан,
 * но драйвер Vulkan поднимается позже, на потоке отрисовки): этот запуск на Vulkan, а Vulkan на телефоне ещё не
 * подтверждён — файл заранее на Compatibility и armed=true (то же, что RendererGuard._arm, но до вылета драйвера,
 * который скрипты не застали бы). Запуск дошёл до скриптов — RendererGuard взводит заново и снимает при подтверждении.
 */
final class RendererPreflight {
	private static final String TAG = "MyRappelzRenderer";
	static final String PREFS = "myrappelz_renderer";
	static final String SECTION = "renderer";
	/** Признак «рендерер — Vulkan» в файле (как RendererGuard.override_method). */
	static final String MOBILE_MARK = "rendering_method.mobile=\"mobile\"";
	/** Тот же текст, что RendererGuard.override_text(COMPAT). */
	static final String COMPAT_TEXT = "; Рендерер следующего запуска — пишет игра (RendererGuard), читает Godot (project_settings_override).\n"
		+ "config_version=5\n\n[rendering]\n\n"
		+ "renderer/rendering_method=\"gl_compatibility\"\n"
		+ "renderer/rendering_method.mobile=\"gl_compatibility\"\n";

	private RendererPreflight() {
	}

	/** Та же проверка, что у Godot 4.3 перед созданием Vulkan-вида (Godot.kt meetsVulkanRequirements). */
	static boolean meetsVulkanRequirements(PackageManager pm) {
		if (pm == null || Build.VERSION.SDK_INT < 24) {
			return false;
		}
		// Уровень FEATURE_VULKAN_HARDWARE_LEVEL ≥ 1 Godot 4.3 только пишет предупреждением, требование — версия 1.0.3
		return pm.hasSystemFeature(PackageManager.FEATURE_VULKAN_HARDWARE_VERSION, 0x400003);
	}

	static void remember(Context c, String statePath, String overridePath) {
		c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
			.putString("state", statePath).putString("override", overridePath).apply();
	}

	static File stateFile(Context c) {
		SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
		String s = p.getString("state", "");
		return s != null && !s.isEmpty() ? new File(s) : new File(c.getFilesDir(), "renderer.cfg");
	}

	static File overrideFile(Context c) {
		SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
		String s = p.getString("override", "");
		return s != null && !s.isEmpty() ? new File(s) : new File(c.getFilesDir(), "renderer_override.cfg");
	}

	/** Конструктор плагина — до чтения настроек движком. */
	static void beforeEngine(Context c) {
		File ov = overrideFile(c);
		if (!ov.isFile() || !read(ov).contains(MOBILE_MARK)) {
			return;
		}
		File st = stateFile(c);
		String state = st.isFile() ? read(st) : "";
		if ("true".equals(value(state, "confirmed"))) {
			return;
		}
		if ("true".equals(value(state, "armed"))) {
			Log.w(TAG, "Vulkan не подтверждён в прошлый раз — запуск на Compatibility");
			write(ov, COMPAT_TEXT);
			return;
		}
		if (!meetsVulkanRequirements(c.getPackageManager())) {
			Log.w(TAG, "Нет Vulkan 1.0.3 — запуск на Compatibility");
			write(ov, COMPAT_TEXT);
			write(st, withValue(state, "armed", "true"));
		}
	}

	/** onMainCreate — этот запуск уже на Vulkan (если файл так говорит), драйвер ещё не поднят. */
	static void armBeforeVulkan(Context c) {
		File ov = overrideFile(c);
		if (!ov.isFile() || !read(ov).contains(MOBILE_MARK)) {
			return;
		}
		File st = stateFile(c);
		String state = st.isFile() ? read(st) : "";
		if ("true".equals(value(state, "confirmed"))) {
			return;
		}
		write(ov, COMPAT_TEXT);
		write(st, withValue(state, "armed", "true"));
		Log.i(TAG, "Vulkan не подтверждён: страховка взведена до запуска драйвера");
	}

	/** Значение ключа секции [renderer] (без кавычек; null — нет). */
	static String value(String text, String key) {
		boolean in = false;
		for (String raw : text.split("\n")) {
			String line = raw.trim();
			if (line.startsWith("[")) {
				in = line.equals("[" + SECTION + "]");
				continue;
			}
			if (!in) {
				continue;
			}
			int eq = line.indexOf('=');
			if (eq > 0 && line.substring(0, eq).trim().equals(key)) {
				String v = line.substring(eq + 1).trim();
				if (v.length() >= 2 && v.startsWith("\"") && v.endsWith("\"")) {
					v = v.substring(1, v.length() - 1);
				}
				return v;
			}
		}
		return null;
	}

	/** Текст ConfigFile с key=v в секции [renderer] (остальное как было). */
	static String withValue(String text, String key, String v) {
		StringBuilder out = new StringBuilder();
		boolean in = false;
		boolean seen = false;
		boolean done = false;
		String[] lines = text.isEmpty() ? new String[0] : text.split("\n", -1);
		for (String raw : lines) {
			String line = raw.trim();
			if (line.startsWith("[")) {
				if (in && !done) {
					out.append(key).append('=').append(v).append('\n');
					done = true;
				}
				in = line.equals("[" + SECTION + "]");
				seen |= in;
				if (in) {
					out.append(raw).append('\n').append(key).append('=').append(v).append('\n');
					done = true;
					continue;
				}
			} else if (in) {
				int eq = line.indexOf('=');
				if (eq > 0 && line.substring(0, eq).trim().equals(key)) {
					continue;
				}
			}
			out.append(raw).append('\n');
		}
		if (!seen) {
			out.append("\n[").append(SECTION).append("]\n\n").append(key).append('=').append(v).append('\n');
		}
		String s = out.toString();
		while (s.endsWith("\n\n")) {
			s = s.substring(0, s.length() - 1);
		}
		return s;
	}

	static String read(File f) {
		try (InputStream in = new FileInputStream(f)) {
			ByteArrayOutputStream b = new ByteArrayOutputStream();
			DownloadPlugin.copy(in, b);
			return new String(b.toByteArray(), StandardCharsets.UTF_8).replace("\r", "");
		} catch (Exception e) {
			return "";
		}
	}

	/** Записать через временный файл (оборванная запись не оставит полфайла). */
	static void write(File f, String text) {
		try {
			File parent = f.getParentFile();
			if (parent != null && !parent.exists()) {
				parent.mkdirs();
			}
			File tmp = new File(f.getPath() + ".tmp");
			try (OutputStream out = new FileOutputStream(tmp)) {
				out.write(text.getBytes(StandardCharsets.UTF_8));
				out.flush();
			}
			if (!tmp.renameTo(f)) {
				f.delete();
				if (!tmp.renameTo(f)) {
					Log.w(TAG, "не удалось записать " + f);
				}
			}
		} catch (Exception e) {
			Log.w(TAG, "не удалось записать " + f, e);
		}
	}
}
