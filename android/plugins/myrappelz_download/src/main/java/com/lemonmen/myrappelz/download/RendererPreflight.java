package com.lemonmen.myrappelz.download;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import org.godotengine.godot.GodotLib;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Рендерер следующего запуска и страховка от вылета Vulkan до запуска скриптов (RendererGuard в игре — CLAUDE.md,
 * раздел «Рендерер»).
 * <p>
 * Файлы игры (формат ConfigFile / project.godot, текст): состояние user://renderer.cfg (секция [renderer]: choice,
 * want — рендерер, который игра хочет со следующего запуска, armed, confirmed, failed, tries, last_exit) и рендерер
 * следующего запуска user://renderer_override.cfg (application/config/project_settings_override; Godot 4.3 читает его
 * в ProjectSettings::setup — Main::setup из GodotLib.setup в Godot.onInitNativeLayer, после создания плагинов; Java
 * решает «Vulkan или OpenGL» в onInitRenderView → usesVulkan() по GodotLib.getGlobal — уже с этим файлом). Пути
 * передаёт игра (rememberRendererFiles → SharedPreferences), без них — getFilesDir() (это user:// Godot на Android).
 * Журнал запусков — renderer_log.txt рядом (пишут и плагин, и игра; отчёт тест-бота показывает его).
 * <p>
 * beforeEngine (конструктор плагина: Godot.onCreate → GodotPluginRegistry, до Main::setup):
 * <ul>
 * <li>armed=true — прошлый запуск шёл на неподтверждённом Vulkan и не ушёл в фон: причина его конца (Android 11+,
 * ApplicationExitInfo) — сбой (crash, crash_native, anr, initialization_failure) или попыток без подтверждения
 * уже MAX_TRIES — файл на Compatibility, armed остаётся (игра засчитает сбой); закрыли не из-за Vulkan (смахнули из
 * недавних, система выгрузила, перезапуск игры) — снова Vulkan, armed=false; причина неизвестна (Android 10 и
 * ниже) — как сбой;</li>
 * <li>armed=false — файл приводится к want (страховка, если игра не смогла записать файл сама);</li>
 * <li>файл на Vulkan, а у телефона нет Vulkan 1.0.3 (meetsVulkanRequirements — Godot 4.3 бросил бы
 * IllegalStateException «нет Vulkan» и закрылся) — файл на Compatibility и armed=true.</li>
 * </ul>
 * afterSetup (onMainCreate: Godot.onInitRenderView — настройки этого запуска прочитаны, вид отрисовки создан, драйвер
 * Vulkan поднимается позже, на потоке отрисовки): что движок взял на самом деле — GodotLib.getGlobal, как usesVulkan()
 * Godot.kt; Vulkan и он ещё не подтверждён — файл заранее на Compatibility, armed=true, tries+1 (то же, что
 * RendererGuard._arm, но до вылета драйвера, который скрипты не застали бы). Файл говорил Vulkan, а движок взял
 * OpenGL — в журнал (файл не прочитан), страховка не взводится.
 */
final class RendererPreflight {
	private static final String TAG = "MyRappelzRenderer";
	static final String PREFS = "myrappelz_renderer";
	static final String SECTION = "renderer";
	static final String LOG_NAME = "renderer_log.txt";
	static final int LOG_MAX = 80;
	/** Столько запусков подряд на неподтверждённом Vulkan (без сбоя) — дальше считать сбоем. */
	static final int MAX_TRIES = 3;
	/** Признак «рендерер — Vulkan» в файле (как RendererGuard.override_method). */
	static final String MOBILE_MARK = "rendering_method.mobile=\"mobile\"";
	static final String HEAD = "; Рендерер следующего запуска — пишет игра (RendererGuard), читает Godot (project_settings_override).\n"
		+ "config_version=5\n\n[rendering]\n\n";
	/** Тот же текст, что RendererGuard.override_text(COMPAT). */
	static final String COMPAT_TEXT = HEAD
		+ "renderer/rendering_method=\"gl_compatibility\"\n"
		+ "renderer/rendering_method.mobile=\"gl_compatibility\"\n";
	/** Тот же текст, что RendererGuard.override_text(MOBILE). */
	static final String MOBILE_TEXT = HEAD
		+ "renderer/rendering_method=\"mobile\"\n"
		+ "renderer/rendering_method.mobile=\"mobile\"\n"
		+ "rendering_device/driver.android=\"vulkan\"\n";

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

	/** Журнал запусков — рядом с файлом состояния (user://renderer_log.txt). */
	static File logFile(Context c) {
		File dir = stateFile(c).getParentFile();
		return new File(dir != null ? dir : c.getFilesDir(), LOG_NAME);
	}

	/** «Vulkan» / «Совместимость» / «нет файла» — что говорит файл рендерера. */
	static String describe(String overrideText) {
		if (overrideText == null) {
			return "нет файла";
		}
		return overrideText.contains(MOBILE_MARK) ? "Vulkan" : "Совместимость";
	}

	/** Конструктор плагина — до чтения настроек движком. */
	static void beforeEngine(Context c) {
		File ov = overrideFile(c);
		File st = stateFile(c);
		String ovText = ov.isFile() ? read(ov) : null;
		boolean fileVulkan = ovText != null && ovText.contains(MOBILE_MARK);
		String state = st.isFile() ? read(st) : "";
		String original = state;
		boolean confirmed = "true".equals(value(state, "confirmed"));
		boolean armed = "true".equals(value(state, "armed"));
		String want = value(state, "want");
		int tries = parseInt(value(state, "tries"));
		ApplicationExitInfo last = lastExit(c);
		int kind = exitKind(last);
		String exitText = exitText(last);
		if (!exitText.isEmpty()) {
			state = withValue(state, "last_exit", "\"" + exitText + "\"");
		}
		log(c, "до движка: файл " + describe(ovText) + ", выбор " + value(state, "choice") + ", want " + want
			+ ", armed " + armed + ", confirmed " + confirmed + ", tries " + tries
			+ ", прошлый выход: " + (exitText.isEmpty() ? "неизвестно" : exitText));
		if (armed && !confirmed) {
			boolean wantsVulkan = want == null || "mobile".equals(want);
			if (kind == 0 && tries < MAX_TRIES && wantsVulkan) {
				// Прошлый запуск на Vulkan закончился не сбоем (смахнули, система выгрузила, перезапуск) — снова Vulkan
				state = withValue(state, "armed", "false");
				write(ov, MOBILE_TEXT);
				fileVulkan = true;
				log(c, "прошлый запуск на Vulkan закрыт не из-за сбоя — снова Vulkan (попытка " + (tries + 1) + " из "
					+ MAX_TRIES + ")");
			} else {
				if (fileVulkan || ovText == null) {
					write(ov, COMPAT_TEXT);
				}
				fileVulkan = false;
				log(c, "прошлый запуск на Vulkan не подтверждён (" + (kind == 1 ? "сбой" : kind == 0 ? "попыток "
					+ tries : "причина неизвестна") + ") — этот на Совместимости, игра засчитает сбой");
			}
		} else if (!armed && want != null && !want.isEmpty()) {
			// Файл должен совпадать с тем, что игра выбрала (want); не совпал — игра не смогла его записать
			boolean wantVulkan = "mobile".equals(want);
			if (wantVulkan != fileVulkan) {
				write(ov, wantVulkan ? MOBILE_TEXT : COMPAT_TEXT);
				fileVulkan = wantVulkan;
				log(c, "файл не совпадал с выбором игры (want " + want + ") — исправлен");
			}
		}
		if (fileVulkan && !confirmed && !meetsVulkanRequirements(c.getPackageManager())) {
			Log.w(TAG, "Нет Vulkan 1.0.3 — запуск на Compatibility");
			write(ov, COMPAT_TEXT);
			state = withValue(state, "armed", "true");
			log(c, "у телефона нет Vulkan 1.0.3 — этот запуск на Совместимости");
		}
		if (!state.equals(original)) {
			write(st, state);
		}
	}

	/** onMainCreate — настройки этого запуска прочитаны движком, драйвер Vulkan ещё не поднят. */
	static void afterSetup(Context c) {
		File ov = overrideFile(c);
		File st = stateFile(c);
		String ovText = ov.isFile() ? read(ov) : null;
		boolean fileVulkan = ovText != null && ovText.contains(MOBILE_MARK);
		String method = engineSetting("rendering/renderer/rendering_method");
		String driver = engineSetting("rendering/rendering_device/driver");
		boolean engineVulkan;
		if (method == null) {
			// Нет движка (не должно быть) — по файлу, как раньше
			engineVulkan = fileVulkan;
			log(c, "движок не ответил — по файлу: " + describe(ovText));
		} else {
			// Как Godot.kt usesVulkan()
			engineVulkan = ("forward_plus".equals(method) || "mobile".equals(method)) && "vulkan".equals(driver);
			String overridePath = engineSetting("application/config/project_settings_override");
			log(c, "движок взял: rendering_method " + method + ", driver " + driver + " → "
				+ (engineVulkan ? "Vulkan" : "OpenGL") + " (файл " + describe(ovText) + ", override " + overridePath + ")");
			if (fileVulkan && !engineVulkan) {
				log(c, "ВНИМАНИЕ: файл рендерера говорит Vulkan, а движок взял " + method
					+ " — файл не прочитан движком");
			}
		}
		if (!engineVulkan) {
			return;
		}
		String state = st.isFile() ? read(st) : "";
		if ("true".equals(value(state, "confirmed"))) {
			return;
		}
		int tries = parseInt(value(state, "tries")) + 1;
		write(ov, COMPAT_TEXT);
		state = withValue(state, "armed", "true");
		state = withValue(state, "tries", Integer.toString(tries));
		write(st, state);
		log(c, "Vulkan не подтверждён: страховка взведена до запуска драйвера (попытка " + tries + ")");
		Log.i(TAG, "Vulkan не подтверждён: страховка взведена до запуска драйвера");
	}

	/** Настройка проекта, как её видит движок (GodotLib.getGlobal — GLOBAL_GET); null — нет движка. */
	static String engineSetting(String key) {
		try {
			return GodotLib.getGlobal(key);
		} catch (Throwable t) {
			return null;
		}
	}

	/** Как закончился прошлый процесс игры (Android 11+; null — неизвестно). Процесс перезапуска :phoenix — мимо. */
	static ApplicationExitInfo lastExit(Context c) {
		if (Build.VERSION.SDK_INT < 30) {
			return null;
		}
		try {
			ActivityManager am = (ActivityManager)c.getSystemService(Context.ACTIVITY_SERVICE);
			if (am == null) {
				return null;
			}
			List<ApplicationExitInfo> list = am.getHistoricalProcessExitReasons(c.getPackageName(), 0, 8);
			if (list == null) {
				return null;
			}
			int me = Process.myPid();
			for (ApplicationExitInfo e : list) {
				String proc = e.getProcessName();
				if (e.getPid() == me || (proc != null && proc.contains(":"))) {
					continue;
				}
				return e;
			}
		} catch (Throwable t) {
			Log.w(TAG, "exit reasons failed", t);
		}
		return null;
	}

	/** 1 — сбой (crash, crash_native, anr, initialization_failure), 0 — не сбой, −1 — неизвестно. */
	static int exitKind(ApplicationExitInfo e) {
		if (e == null) {
			return -1;
		}
		switch (e.getReason()) {
			case ApplicationExitInfo.REASON_CRASH:
			case ApplicationExitInfo.REASON_CRASH_NATIVE:
			case ApplicationExitInfo.REASON_ANR:
			case ApplicationExitInfo.REASON_INITIALIZATION_FAILURE:
				return 1;
			case ApplicationExitInfo.REASON_UNKNOWN:
				return -1;
			default:
				return 0;
		}
	}

	static String reasonName(int r) {
		switch (r) {
			case ApplicationExitInfo.REASON_EXIT_SELF: return "exit_self";
			case ApplicationExitInfo.REASON_SIGNALED: return "signaled";
			case ApplicationExitInfo.REASON_LOW_MEMORY: return "low_memory";
			case ApplicationExitInfo.REASON_CRASH: return "crash";
			case ApplicationExitInfo.REASON_CRASH_NATIVE: return "crash_native";
			case ApplicationExitInfo.REASON_ANR: return "anr";
			case ApplicationExitInfo.REASON_INITIALIZATION_FAILURE: return "initialization_failure";
			case ApplicationExitInfo.REASON_PERMISSION_CHANGE: return "permission_change";
			case ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE: return "excessive_resource_usage";
			case ApplicationExitInfo.REASON_USER_REQUESTED: return "user_requested";
			case ApplicationExitInfo.REASON_USER_STOPPED: return "user_stopped";
			case ApplicationExitInfo.REASON_DEPENDENCY_DIED: return "dependency_died";
			case ApplicationExitInfo.REASON_OTHER: return "other";
			default: return "reason " + r;
		}
	}

	/** «crash_native, статус 11 (описание), 2026-11-01 18:40:12» — без кавычек и переводов строк (ConfigFile). */
	static String exitText(ApplicationExitInfo e) {
		if (e == null) {
			return "";
		}
		StringBuilder b = new StringBuilder(reasonName(e.getReason()));
		b.append(", статус ").append(e.getStatus());
		String d = e.getDescription();
		if (d != null && !d.isEmpty()) {
			b.append(" (").append(d.length() > 160 ? d.substring(0, 160) : d).append(')');
		}
		b.append(", ").append(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT).format(new Date(e.getTimestamp())));
		return clean(b.toString());
	}

	static String clean(String s) {
		return s.replace("\\", "/").replace("\"", "'").replace("\r", " ").replace("\n", " ");
	}

	static int parseInt(String s) {
		try {
			return s == null ? 0 : Integer.parseInt(s.trim());
		} catch (Exception e) {
			return 0;
		}
	}

	/** Строка в журнал запусков (последние LOG_MAX строк). */
	static void log(Context c, String text) {
		Log.i(TAG, text);
		try {
			File f = logFile(c);
			String old = f.isFile() ? read(f) : "";
			String line = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT).format(new Date()) + " · плагин · "
				+ clean(text) + "\n";
			String[] lines = (old + line).split("\n");
			StringBuilder out = new StringBuilder();
			for (int i = Math.max(0, lines.length - LOG_MAX); i < lines.length; i++) {
				if (!lines[i].isEmpty()) {
					out.append(lines[i]).append('\n');
				}
			}
			write(f, out.toString());
		} catch (Throwable t) {
			Log.w(TAG, "log failed", t);
		}
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
