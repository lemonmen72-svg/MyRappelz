package com.lemonmen.myrappelz.download;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Отдаёт файлы отчёта тест-бота (DownloadPlugin.share / openFile) другим приложениям: content://<пакет>.darkpact_reports/<имя>.
 * Свой маленький провайдер вместо androidx FileProvider — у плагина нет зависимостей, а провайдер из манифеста
 * создаётся при запуске приложения (класса нет — приложение падает). Файл перед отправкой копируется в
 * getCacheDir()/shared_reports (publish); провайдер читает только оттуда и только на чтение, доступ — по разовому
 * разрешению Intent.FLAG_GRANT_READ_URI_PERMISSION (exported="false", grantUriPermissions="true").
 */
public class ReportProvider extends ContentProvider {
	private static final String DIR = "shared_reports";
	private static final String SUFFIX = ".darkpact_reports";

	static String authority(Context c) {
		return c.getPackageName() + SUFFIX;
	}

	static File dir(Context c) {
		return new File(c.getCacheDir(), DIR);
	}

	/** Скопировать src в папку провайдера (прежние файлы там удаляются) и вернуть его content://-адрес. */
	static Uri publish(Context c, File src) throws IOException {
		File d = dir(c);
		if (!d.exists() && !d.mkdirs()) {
			throw new IOException("cannot create " + d);
		}
		File[] old = d.listFiles();
		if (old != null) {
			for (File f : old) {
				if (!f.getName().equals(src.getName())) {
					f.delete();
				}
			}
		}
		File dst = new File(d, src.getName());
		try (InputStream in = new FileInputStream(src); OutputStream out = new FileOutputStream(dst)) {
			DownloadPlugin.copy(in, out);
		}
		return new Uri.Builder().scheme("content").authority(authority(c)).appendPath(src.getName()).build();
	}

	private File fileFor(Uri uri) throws FileNotFoundException {
		Context c = getContext();
		String name = uri.getLastPathSegment();
		if (c == null || name == null || name.isEmpty() || name.contains("/") || name.contains("..")) {
			throw new FileNotFoundException("bad uri " + uri);
		}
		File d = dir(c);
		File f = new File(d, name);
		try {
			if (!f.getCanonicalPath().startsWith(d.getCanonicalPath() + File.separator)) {
				throw new FileNotFoundException("outside " + uri);
			}
		} catch (IOException e) {
			throw new FileNotFoundException(e.toString());
		}
		if (!f.isFile()) {
			throw new FileNotFoundException("no file " + uri);
		}
		return f;
	}

	@Override
	public boolean onCreate() {
		return true;
	}

	@Override
	public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
		if (mode != null && !mode.equals("r")) {
			throw new SecurityException("read only");
		}
		return ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY);
	}

	@Override
	public String getType(Uri uri) {
		String n = uri.getLastPathSegment();
		if (n == null) {
			return "application/octet-stream";
		}
		n = n.toLowerCase();
		if (n.endsWith(".zip")) {
			return "application/zip";
		}
		if (n.endsWith(".txt")) {
			return "text/plain";
		}
		if (n.endsWith(".jpg") || n.endsWith(".jpeg")) {
			return "image/jpeg";
		}
		return "application/octet-stream";
	}

	/** Имя и размер файла (OpenableColumns) — их спрашивают почта и мессенджеры. */
	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
		File f;
		try {
			f = fileFor(uri);
		} catch (FileNotFoundException e) {
			return null;
		}
		String[] cols = projection != null ? projection : new String[] { OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE };
		Object[] row = new Object[cols.length];
		int n = 0;
		String[] used = new String[cols.length];
		for (String col : cols) {
			if (OpenableColumns.DISPLAY_NAME.equals(col)) {
				used[n] = col;
				row[n++] = f.getName();
			} else if (OpenableColumns.SIZE.equals(col)) {
				used[n] = col;
				row[n++] = f.length();
			}
		}
		String[] outCols = new String[n];
		Object[] outRow = new Object[n];
		System.arraycopy(used, 0, outCols, 0, n);
		System.arraycopy(row, 0, outRow, 0, n);
		MatrixCursor cur = new MatrixCursor(outCols, 1);
		cur.addRow(outRow);
		return cur;
	}

	@Override
	public Uri insert(Uri uri, ContentValues values) {
		throw new UnsupportedOperationException("read only");
	}

	@Override
	public int delete(Uri uri, String selection, String[] selectionArgs) {
		return 0;
	}

	@Override
	public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
		return 0;
	}
}
