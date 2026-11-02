package com.lemonmen.myrappelz.download;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Прошлые завершения игры для отчёта тест-бота (раздел «Прошлые завершения игры», DownloadPlugin.exitHistory):
 * ActivityManager.getHistoricalProcessExitReasons (Android 11+) — причина, статус, описание, время, важность процесса,
 * память; у сбоев (crash, crash_native, anr, initialization_failure) — след ApplicationExitInfo.getTraceInputStream:
 * у ANR — текст (стеки потоков, Android 11+), у crash_native — tombstone (Android 12+, двоичный protobuf: из него
 * берутся читаемые строки — сообщение abort, имена функций и библиотек стека), у crash (Java) следа нет.
 * <p>
 * Результат — JSON-строкой (JNI Godot 4.3: только String/bool/int/Dictionary, long не передаётся; вложенные списки
 * в строке надёжнее): {"sdk": int, "exits": [{reason, code, status, description, time, importance, process, pid,
 * pss_mb, rss_mb, trace: [строки]}], "error": "…"}. Свежие — первыми; текущий процесс и процессы с «:» (:phoenix —
 * перезапуск игры) не берутся.
 */
final class ExitHistory {
	private static final String TAG = "MyRappelzDownload";
	/** Сколько байт следа читать, не больше. */
	static final int TRACE_BYTES = 512 * 1024;
	/** Строки следа crash_native: читаемые куски tombstone не короче стольких символов. */
	static final int MIN_RUN = 5;
	/** Строка следа — не длиннее. */
	static final int LINE_MAX = 240;

	private ExitHistory() {
	}

	/** Не больше maxCount записей, след — не больше traceLines строк. */
	static String json(Context c, int maxCount, int traceLines) {
		StringBuilder b = new StringBuilder(4096);
		b.append("{\"sdk\":").append(Build.VERSION.SDK_INT).append(",\"exits\":[");
		String error = "";
		if (Build.VERSION.SDK_INT >= 30 && c != null && maxCount > 0) {
			try {
				ActivityManager am = (ActivityManager)c.getSystemService(Context.ACTIVITY_SERVICE);
				List<ApplicationExitInfo> list = am == null ? null
					: am.getHistoricalProcessExitReasons(c.getPackageName(), 0, Math.min(maxCount * 2 + 2, 32));
				int me = Process.myPid();
				int n = 0;
				if (list != null) {
					for (ApplicationExitInfo e : list) {
						if (n >= maxCount) {
							break;
						}
						String proc = e.getProcessName();
						if (e.getPid() == me || (proc != null && proc.contains(":"))) {
							continue;
						}
						if (n > 0) {
							b.append(',');
						}
						entry(b, e, traceLines);
						n++;
					}
				}
			} catch (Throwable t) {
				Log.w(TAG, "exit history failed", t);
				error = t.toString();
			}
		}
		b.append("],\"error\":");
		quote(b, error);
		b.append('}');
		return b.toString();
	}

	private static void entry(StringBuilder b, ApplicationExitInfo e, int traceLines) {
		int r = e.getReason();
		b.append("{\"reason\":");
		quote(b, RendererPreflight.reasonName(r));
		b.append(",\"code\":").append(r);
		b.append(",\"status\":").append(e.getStatus());
		b.append(",\"description\":");
		quote(b, e.getDescription() != null ? e.getDescription() : "");
		b.append(",\"time\":");
		quote(b, new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT).format(new Date(e.getTimestamp())));
		b.append(",\"importance\":");
		quote(b, importanceName(e.getImportance()));
		b.append(",\"process\":");
		quote(b, e.getProcessName() != null ? e.getProcessName() : "");
		b.append(",\"pid\":").append(e.getPid());
		// Память — МБ целым (long в JSON тоже можно, но игре хватает МБ)
		b.append(",\"pss_mb\":").append((int)(e.getPss() / 1024L));
		b.append(",\"rss_mb\":").append((int)(e.getRss() / 1024L));
		b.append(",\"trace\":[");
		List<String> lines = isFailure(r) && traceLines > 0 ? trace(e, traceLines) : new ArrayList<>();
		for (int i = 0; i < lines.size(); i++) {
			if (i > 0) {
				b.append(',');
			}
			quote(b, lines.get(i));
		}
		b.append("]}");
	}

	static boolean isFailure(int r) {
		return r == ApplicationExitInfo.REASON_CRASH || r == ApplicationExitInfo.REASON_CRASH_NATIVE
			|| r == ApplicationExitInfo.REASON_ANR || r == ApplicationExitInfo.REASON_INITIALIZATION_FAILURE;
	}

	/** Первые traceLines строк следа (нет следа — пусто; ошибка чтения — одна строка с ней). */
	static List<String> trace(ApplicationExitInfo e, int traceLines) {
		List<String> out = new ArrayList<>();
		byte[] data;
		try (InputStream in = e.getTraceInputStream()) {
			if (in == null) {
				return out;
			}
			ByteArrayOutputStream buf = new ByteArrayOutputStream();
			byte[] chunk = new byte[16384];
			int got;
			while (buf.size() < TRACE_BYTES && (got = in.read(chunk, 0, Math.min(chunk.length, TRACE_BYTES - buf.size()))) > 0) {
				buf.write(chunk, 0, got);
			}
			data = buf.toByteArray();
		} catch (Throwable t) {
			out.add("(след не прочитан: " + t + ")");
			return out;
		}
		if (e.getReason() == ApplicationExitInfo.REASON_CRASH_NATIVE) {
			return printableRuns(data, traceLines);
		}
		String text = new String(data, StandardCharsets.UTF_8);
		for (String line : text.split("\n")) {
			if (out.size() >= traceLines) {
				break;
			}
			String s = line.replace("\r", "");
			out.add(s.length() > LINE_MAX ? s.substring(0, LINE_MAX) : s);
		}
		return out;
	}

	/** Читаемые куски двоичного tombstone (как утилита strings): ASCII от пробела до «~» и табуляция, ≥ MIN_RUN. */
	static List<String> printableRuns(byte[] data, int maxLines) {
		List<String> out = new ArrayList<>();
		StringBuilder cur = new StringBuilder();
		for (int i = 0; i <= data.length && out.size() < maxLines; i++) {
			int ch = i < data.length ? (data[i] & 0xff) : -1;
			if (ch == '\t' || (ch >= 0x20 && ch <= 0x7e)) {
				if (cur.length() < LINE_MAX) {
					cur.append((char)ch);
				}
				continue;
			}
			String s = cur.toString().trim();
			if (s.length() >= MIN_RUN) {
				out.add(s);
			}
			cur.setLength(0);
		}
		return out;
	}

	/** Важность процесса в момент завершения (ActivityManager.RunningAppProcessInfo.IMPORTANCE_*). */
	static String importanceName(int v) {
		switch (v) {
			case 100: return "на экране";
			case 125: return "служба на переднем плане";
			case 150: return "на экране, экран выключен";
			case 200: return "видна";
			case 230: return "заметна";
			case 300: return "служба";
			case 325: return "на экране, экран выключен";
			case 350: return "не может сохранить состояние";
			case 400: return "в фоне";
			case 1000: return "процесса нет";
			default: return "важность " + v;
		}
	}

	/** Строка JSON в кавычках (управляющие символы — \\uXXXX). */
	static void quote(StringBuilder b, String s) {
		b.append('"');
		for (int i = 0; i < s.length(); i++) {
			char ch = s.charAt(i);
			switch (ch) {
				case '"': b.append("\\\""); break;
				case '\\': b.append("\\\\"); break;
				case '\n': b.append("\\n"); break;
				case '\r': b.append("\\r"); break;
				case '\t': b.append("\\t"); break;
				default:
					if (ch < 0x20) {
						b.append(String.format(Locale.ROOT, "\\u%04x", (int)ch));
					} else {
						b.append(ch);
					}
			}
		}
		b.append('"');
	}
}
