package com.lemonmen.myrappelz.download;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.util.Log;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;

/**
 * Фоновая загрузка пакета ресурсов MyRappelz через системный DownloadManager (плагин Godot v2, singleton
 * «MyRappelzDownload»; в игре — Assets.download_plugin(), экран AssetLoader).
 * <p>
 * Качает сам Android: загрузка идёт, когда игра свёрнута или закрыта, ход — в уведомлении системы. Файл ложится
 * во внешнюю папку приложения (getExternalFilesDir — без разрешений на память), игра проверяет sha256 и переносит
 * его в user://packs.
 * <p>
 * Типы параметров и результатов — только String, boolean, Dictionary: JNI Godot 4.3 передаёт int-параметры
 * как jint и читает результат int-метода (long-метод вызвать нельзя), поэтому id загрузки — строкой.
 */
public class DownloadPlugin extends GodotPlugin {
	private static final String TAG = "MyRappelzDownload";
	private static final String POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS";
	private static final int PERMISSION_REQUEST = 7301;

	private String lastError = "";

	public DownloadPlugin(Godot godot) {
		super(godot);
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

	/** Текст последней ошибки (для журнала). */
	@UsedByGodot
	public String lastError() {
		return lastError;
	}
}
