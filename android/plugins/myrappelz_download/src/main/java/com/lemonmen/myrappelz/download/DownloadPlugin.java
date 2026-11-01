package com.lemonmen.myrappelz.download;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.ClipData;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Build;
import android.os.PowerManager;
import android.provider.MediaStore;
import android.util.Log;
import android.view.View;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Фоновая загрузка пакета ресурсов MyRappelz через системный DownloadManager (плагин Godot v2, singleton
 * «MyRappelzDownload»; в игре — Assets.download_plugin(), экран AssetLoader).
 * <p>
 * Качает сам Android: загрузка идёт, когда игра свёрнута или закрыта, ход — в уведомлении системы. Файл ложится
 * во внешнюю папку приложения (getExternalFilesDir — без разрешений на память), игра проверяет sha256 и переносит
 * его в user://packs.
 * <p>
 * Типы параметров и результатов — только String, boolean, int, Dictionary: JNI Godot 4.3 передаёт int-параметры
 * как jint и читает результат int-метода (long-метод вызвать нельзя), поэтому id загрузки — строкой.
 * <p>
 * Заодно — температура телефона для бережения (ThermalGuard в игре): thermalStatus, thermalHeadroom; для отчёта
 * тест-бота (TestBot, BotReport): batteryTemp, deviceInfo, saveToDownloads (общая папка «Загрузки» через MediaStore,
 * без разрешений), share и openFile (файл отдаётся другим приложениям через свой ReportProvider — без androidx).
 */
public class DownloadPlugin extends GodotPlugin {
	private static final String TAG = "MyRappelzDownload";
	private static final String POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS";
	private static final int PERMISSION_REQUEST = 7301;

	private String lastError = "";

	public DownloadPlugin(Godot godot) {
		super(godot);
		// Рендерер: до чтения настроек движком (Main::setup) — страховка от вылета Vulkan (RendererPreflight)
		try {
			Context c = context();
			if (c != null) {
				RendererPreflight.beforeEngine(c);
			}
		} catch (Throwable t) {
			Log.w(TAG, "renderer preflight failed", t);
		}
	}

	/** Вид отрисовки создан, драйвер Vulkan ещё не поднят: неподтверждённый Vulkan — страховка заранее. */
	@Override
	public View onMainCreate(Activity activity) {
		try {
			if (activity != null) {
				RendererPreflight.armBeforeVulkan(activity.getApplicationContext());
			}
		} catch (Throwable t) {
			Log.w(TAG, "renderer arm failed", t);
		}
		return null;
	}

	/** Есть ли Vulkan, с которым Godot 4.3 запустится (RendererGuard.plugin_vulkan). */
	@UsedByGodot
	public boolean vulkanSupported() {
		Context c = context();
		return c != null && RendererPreflight.meetsVulkanRequirements(c.getPackageManager());
	}

	/** Полные пути файлов рендерера игры (RendererGuard.startup) — для проверки при следующем запуске до движка. */
	@UsedByGodot
	public boolean rememberRendererFiles(String statePath, String overridePath) {
		Context c = context();
		if (c == null) {
			return false;
		}
		RendererPreflight.remember(c, statePath, overridePath);
		return true;
	}

	@Override
	public String getPluginName() {
		return "MyRappelzDownload";
	}

	private Context context() {
		Activity a = getActivity();
		return a != null ? a.getApplicationContext() : null;
	}

	private DownloadManager manager() {
		Context c = context();
		if (c == null) {
			return null;
		}
		return (DownloadManager)c.getSystemService(Context.DOWNLOAD_SERVICE);
	}

	private static long parseId(String id) {
		try {
			return Long.parseLong(id.trim());
		} catch (Exception e) {
			return -1;
		}
	}

	/** Полный путь файла relPath во внешней папке приложения; "" — внешней памяти нет. */
	@UsedByGodot
	public String externalPath(String relPath) {
		Context c = context();
		if (c == null) {
			return "";
		}
		File dir = c.getExternalFilesDir(null);
		if (dir == null) {
			return "";
		}
		return new File(dir, relPath).getAbsolutePath();
	}

	/**
	 * Начать загрузку url в файл relPath внешней папки приложения (прежний файл удаляется). Уведомление с ходом
	 * загрузки и итогом показывает система. Результат — id загрузки строкой, "" — не удалось (lastError).
	 */
	@UsedByGodot
	public String start(String url, String relPath, String title, String description) {
		lastError = "";
		try {
			Context c = context();
			DownloadManager dm = manager();
			if (c == null || dm == null) {
				lastError = "DownloadManager is not available";
				return "";
			}
			File dir = c.getExternalFilesDir(null);
			if (dir == null) {
				lastError = "external files dir is not available";
				return "";
			}
			File file = new File(dir, relPath);
			File parent = file.getParentFile();
			if (parent != null && !parent.exists()) {
				parent.mkdirs();
			}
			if (file.exists()) {
				file.delete();
			}
			DownloadManager.Request r = new DownloadManager.Request(Uri.parse(url));
			r.setTitle(title);
			r.setDescription(description);
			r.setMimeType("application/octet-stream");
			r.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
			r.setDestinationInExternalFilesDir(c, null, relPath);
			r.setAllowedOverMetered(true);
			r.setAllowedOverRoaming(true);
			long id = dm.enqueue(r);
			return Long.toString(id);
		} catch (Exception e) {
			lastError = e.toString();
			Log.w(TAG, "start failed", e);
			return "";
		}
	}

	/**
	 * Состояние загрузки: found (false — загрузки нет: отменена в уведомлении или «Загрузках»), status
	 * (DownloadManager.STATUS_*: 1 ждёт, 2 идёт, 4 пауза, 8 готово, 16 ошибка), reason (причина паузы или ошибки),
	 * bytes, total (-1 — сервер не сообщил), uri; error — запрос не удался (спросить позже).
	 */
	@UsedByGodot
	public Dictionary query(String id) {
		Dictionary d = new Dictionary();
		d.put("found", false);
		DownloadManager dm = manager();
		long n = parseId(id);
		if (dm == null || n < 0) {
			return d;
		}
		Cursor cur = null;
		try {
			cur = dm.query(new DownloadManager.Query().setFilterById(n));
			if (cur != null && cur.moveToFirst()) {
				d.put("found", true);
				d.put("status", cur.getInt(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)));
				d.put("reason", cur.getInt(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)));
				d.put("bytes", cur.getLong(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)));
				d.put("total", cur.getLong(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)));
				String uri = cur.getString(cur.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI));
				d.put("uri", uri != null ? uri : "");
			}
		} catch (Exception e) {
			lastError = e.toString();
			d.put("error", lastError);
			Log.w(TAG, "query failed", e);
		} finally {
			if (cur != null) {
				cur.close();
			}
		}
		return d;
	}

	/** Убрать загрузку (идущая останавливается, файл и уведомление удаляются). */
	@UsedByGodot
	public boolean remove(String id) {
		DownloadManager dm = manager();
		long n = parseId(id);
		if (dm == null || n < 0) {
			return false;
		}
		try {
			return dm.remove(n) > 0;
		} catch (Exception e) {
			lastError = e.toString();
			return false;
		}
	}

	/** Можно ли показывать уведомления (Android 13+ — разрешение POST_NOTIFICATIONS). */
	@UsedByGodot
	public boolean notificationsAllowed() {
		if (Build.VERSION.SDK_INT < 33) {
			return true;
		}
		Context c = context();
		return c != null && c.checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
	}

	/** Android 13+: спросить разрешение на уведомления (если ещё не дано). Загрузка идёт и без него. */
	@UsedByGodot
	public void requestNotifications() {
		if (Build.VERSION.SDK_INT < 33 || notificationsAllowed()) {
			return;
		}
		final Activity a = getActivity();
		if (a == null) {
			return;
		}
		a.runOnUiThread(() -> {
			try {
				a.requestPermissions(new String[] { POST_NOTIFICATIONS }, PERMISSION_REQUEST);
			} catch (Exception e) {
				Log.w(TAG, "requestPermissions failed", e);
			}
		});
	}

	/**
	 * Статус температуры телефона (PowerManager.getCurrentThermalStatus, Android 10+): 0 нет, 1 лёгкий, 2 умеренный,
	 * 3 сильный, 4 критический, 5 аварийный, 6 отключение; -1 — неизвестно (старый Android, ошибка).
	 */
	@UsedByGodot
	public int thermalStatus() {
		if (Build.VERSION.SDK_INT < 29) {
			return -1;
		}
		try {
			PowerManager pm = powerManager();
			return pm != null ? pm.getCurrentThermalStatus() : -1;
		} catch (Exception e) {
			lastError = e.toString();
			return -1;
		}
	}

	/**
	 * Прогноз запаса до троттлинга через 10 с (PowerManager.getThermalHeadroom, Android 11+), в тысячных:
	 * 1000 — телефон начнёт снижать частоты. -1 — неизвестно (старый Android, нет данных, чаще раза в секунду).
	 * Целым: JNI Godot 4.3 надёжно читает только int-результат.
	 */
	@UsedByGodot
	public int thermalHeadroom() {
		if (Build.VERSION.SDK_INT < 30) {
			return -1;
		}
		try {
			PowerManager pm = powerManager();
			if (pm == null) {
				return -1;
			}
			float h = pm.getThermalHeadroom(10);
			if (Float.isNaN(h) || h < 0.0f) {
				return -1;
			}
			return Math.round(h * 1000.0f);
		} catch (Exception e) {
			lastError = e.toString();
			return -1;
		}
	}

	/** Температура батареи в десятых °C (ACTION_BATTERY_CHANGED); -1 — неизвестно. */
	@UsedByGodot
	public int batteryTemp() {
		try {
			Context c = context();
			if (c == null) {
				return -1;
			}
			Intent b = c.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
			if (b == null) {
				return -1;
			}
			return b.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1);
		} catch (Exception e) {
			lastError = e.toString();
			return -1;
		}
	}

	/**
	 * Устройство для отчёта тест-бота: manufacturer, model, device, release (версия Android), sdk (int), soc (Android
	 * 12+: производитель и модель чипа), hardware.
	 */
	@UsedByGodot
	public Dictionary deviceInfo() {
		Dictionary d = new Dictionary();
		d.put("manufacturer", Build.MANUFACTURER != null ? Build.MANUFACTURER : "");
		d.put("model", Build.MODEL != null ? Build.MODEL : "");
		d.put("device", Build.DEVICE != null ? Build.DEVICE : "");
		d.put("hardware", Build.HARDWARE != null ? Build.HARDWARE : "");
		d.put("release", Build.VERSION.RELEASE != null ? Build.VERSION.RELEASE : "");
		d.put("sdk", Build.VERSION.SDK_INT);
		String soc = "";
		if (Build.VERSION.SDK_INT >= 31) {
			soc = (Build.SOC_MANUFACTURER + " " + Build.SOC_MODEL).trim();
		}
		d.put("soc", soc);
		d.put("vulkan", vulkanText(c()));
		return d;
	}

	/**
	 * Скопировать файл srcPath (внутренняя память игры) в общую папку: Android 10+ — MediaStore.Downloads с
	 * RELATIVE_PATH relDir (например «Download/DarkPact_test/»), без разрешений; результат — content://-адрес.
	 * Android 9 и ниже (общая папка требует разрешения на память) — внешняя папка приложения
	 * (getExternalFilesDir/<последняя часть relDir>/name), результат — полный путь файла. "" — не удалось (lastError).
	 */
	@UsedByGodot
	public String saveToDownloads(String srcPath, String relDir, String name, String mime) {
		lastError = "";
		try {
			Context c = context();
			File src = new File(srcPath);
			if (c == null || !src.isFile()) {
				lastError = c == null ? "no context" : "no file " + srcPath;
				return "";
			}
			if (Build.VERSION.SDK_INT >= 29) {
				ContentResolver cr = c.getContentResolver();
				ContentValues v = new ContentValues();
				v.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
				v.put(MediaStore.MediaColumns.MIME_TYPE, mime);
				v.put(MediaStore.MediaColumns.RELATIVE_PATH, relDir);
				v.put(MediaStore.MediaColumns.IS_PENDING, 1);
				Uri uri = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v);
				if (uri == null) {
					lastError = "MediaStore insert failed";
					return "";
				}
				try (InputStream in = new FileInputStream(src); OutputStream out = cr.openOutputStream(uri)) {
					if (out == null) {
						throw new java.io.IOException("openOutputStream failed");
					}
					copy(in, out);
				} catch (Exception e) {
					cr.delete(uri, null, null);
					throw e;
				}
				v.clear();
				v.put(MediaStore.MediaColumns.IS_PENDING, 0);
				cr.update(uri, v, null, null);
				return uri.toString();
			}
			File base = c.getExternalFilesDir(null);
			if (base == null) {
				lastError = "external files dir is not available";
				return "";
			}
			String sub = relDir.replace("\\", "/");
			while (sub.endsWith("/")) {
				sub = sub.substring(0, sub.length() - 1);
			}
			int slash = sub.lastIndexOf('/');
			if (slash >= 0) {
				sub = sub.substring(slash + 1);
			}
			File dir = sub.isEmpty() ? base : new File(base, sub);
			if (!dir.exists()) {
				dir.mkdirs();
			}
			File dst = new File(dir, name);
			try (InputStream in = new FileInputStream(src); OutputStream out = new java.io.FileOutputStream(dst)) {
				copy(in, out);
			}
			return dst.getAbsolutePath();
		} catch (Exception e) {
			lastError = e.toString();
			Log.w(TAG, "saveToDownloads failed", e);
			return "";
		}
	}

	/** Отправить файл path (внутренняя память игры) через «Поделиться» системы. false — не удалось (lastError). */
	@UsedByGodot
	public boolean share(String path, String mime, String title) {
		return sendFile(Intent.ACTION_SEND, path, mime, title);
	}

	/** Открыть файл path в другом приложении (выбор приложения). false — не удалось (lastError). */
	@UsedByGodot
	public boolean openFile(String path, String mime) {
		return sendFile(Intent.ACTION_VIEW, path, mime, "");
	}

	private boolean sendFile(String action, String path, String mime, String title) {
		lastError = "";
		try {
			final Activity a = getActivity();
			if (a == null) {
				lastError = "no activity";
				return false;
			}
			Uri uri = ReportProvider.publish(a.getApplicationContext(), new File(path));
			Intent it = new Intent(action);
			if (Intent.ACTION_SEND.equals(action)) {
				it.setType(mime);
				it.putExtra(Intent.EXTRA_STREAM, uri);
				if (!title.isEmpty()) {
					it.putExtra(Intent.EXTRA_SUBJECT, title);
				}
			} else {
				it.setDataAndType(uri, mime);
			}
			it.setClipData(ClipData.newRawUri(title.isEmpty() ? "report" : title, uri));
			it.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			final Intent chooser = Intent.createChooser(it, title.isEmpty() ? null : title);
			chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			a.runOnUiThread(() -> {
				try {
					a.startActivity(chooser);
				} catch (Exception e) {
					lastError = e.toString();
					Log.w(TAG, "startActivity failed", e);
				}
			});
			return true;
		} catch (Exception e) {
			lastError = e.toString();
			Log.w(TAG, "sendFile failed", e);
			return false;
		}
	}

	static void copy(InputStream in, OutputStream out) throws java.io.IOException {
		byte[] buf = new byte[65536];
		int n;
		while ((n = in.read(buf)) > 0) {
			out.write(buf, 0, n);
		}
		out.flush();
	}

	private Context c() {
		return context();
	}

	/** «1.1.0, уровень 1» — версия и уровень Vulkan из возможностей системы; "" — нет. */
	private static String vulkanText(Context c) {
		if (c == null || Build.VERSION.SDK_INT < 24) {
			return "";
		}
		try {
			int ver = -1;
			int lvl = -1;
			android.content.pm.FeatureInfo[] fs = c.getPackageManager().getSystemAvailableFeatures();
			if (fs != null) {
				for (android.content.pm.FeatureInfo f : fs) {
					if (PackageManager.FEATURE_VULKAN_HARDWARE_VERSION.equals(f.name)) {
						ver = f.version;
					} else if (PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL.equals(f.name)) {
						lvl = f.version;
					}
				}
			}
			if (ver < 0) {
				return "";
			}
			return String.format(java.util.Locale.ROOT, "%d.%d.%d, уровень %d", ver >> 22, (ver >> 12) & 0x3ff, ver & 0xfff,
				lvl);
		} catch (Exception e) {
			return "";
		}
	}

	private PowerManager powerManager() {
		Context c = context();
		if (c == null) {
			return null;
		}
		return (PowerManager)c.getSystemService(Context.POWER_SERVICE);
	}

	/** Текст последней ошибки (для журнала). */
	@UsedByGodot
	public String lastError() {
		return lastError;
	}
}
