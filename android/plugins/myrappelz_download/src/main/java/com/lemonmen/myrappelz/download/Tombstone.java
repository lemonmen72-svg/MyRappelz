package com.lemonmen.myrappelz.download;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Разбор tombstone Android 12+ (след crash_native у ApplicationExitInfo — двоичный protobuf debuggerd,
 * system/core/debuggerd/proto/tombstone.proto) для отчёта тест-бота. Раньше в отчёт шли первые 200 читаемых кусков
 * файла — потоки в нём идут в случайном порядке (map), и в 0.44.0 поток сбоя в эти 200 строк не попал. Теперь:
 * сигнал и адрес, причина («stack overflow» …), сообщение abort, поток сбоя первым — имя, tid, кадры (функция или
 * библиотека + смещение; группы кадров, повторяющиеся подряд, — одной строкой «×N»: так видна рекурсия при
 * переполнении стека), build-id библиотек игры (для расшифровки смещений), журнал процесса (если debuggerd положил
 * его в tombstone), остальные потоки — именем и верхними кадрами. Не похоже на tombstone — null (ExitHistory берёт
 * читаемые куски, как раньше). Без зависимостей Android — проверяется обычной JVM.
 */
final class Tombstone {
	/** Длина группы кадров, повтор которой ищется, не больше. */
	static final int MAX_PERIOD = 12;
	/** Группа — повтор, если идёт подряд не меньше стольких раз. */
	static final int MIN_REPEAT = 3;
	/** Строк журнала процесса, не больше. */
	static final int LOG_LINES = 40;
	/** Верхних кадров у остальных потоков. */
	static final int OTHER_FRAMES = 3;
	/** Имя функции в строке — не длиннее. */
	static final int FN_MAX = 150;

	private Tombstone() {
	}

	/** Кадр стека (BacktraceFrame). */
	static final class Frame {
		long relPc;
		String function = "";
		long functionOffset;
		String file = "";
		String buildId = "";

		String key() {
			return file + "+" + relPc;
		}

		String label() {
			String lib = base(file);
			if (lib.isEmpty()) {
				lib = "?";
			}
			if (!function.isEmpty()) {
				String fn = function.length() > FN_MAX ? function.substring(0, FN_MAX) + "…" : function;
				return fn + "+" + functionOffset + " (" + lib + ")";
			}
			return lib + "+0x" + Long.toHexString(relPc);
		}
	}

	/** Поток (Thread). */
	static final class Th {
		int id;
		String name = "";
		final List<Frame> frames = new ArrayList<>();
		final List<String> notes = new ArrayList<>();
	}

	/** Строки разбора (не больше maxLines) или null, если это не tombstone. */
	static List<String> lines(byte[] data, int maxLines) {
		int pid = 0;
		int tid = 0;
		int sigNum = 0;
		String sigName = "";
		String codeName = "";
		boolean hasFault = false;
		long fault = 0;
		String abort = "";
		List<String> causes = new ArrayList<>();
		Map<Integer, Th> threads = new LinkedHashMap<>();
		List<String> log = new ArrayList<>();
		boolean cut = false;
		Pb t = new Pb(data, 0, data.length);
		// Обрезанное поле (след длиннее ExitHistory.TRACE_BYTES) разбирается до конца данных: поток сбоя — хоть частью
		t.lenient = true;
		try {
			while (t.next()) {
				switch (t.field) {
					case 5:
						if (t.wire == 0) {
							pid = (int)t.num;
						}
						break;
					case 6:
						if (t.wire == 0) {
							tid = (int)t.num;
						}
						break;
					case 10:
						if (t.wire == 2) {
							Pb s = t.sub();
							while (s.next()) {
								if (s.field == 1 && s.wire == 0) {
									sigNum = (int)s.num;
								} else if (s.field == 2 && s.wire == 2) {
									sigName = s.str();
								} else if (s.field == 4 && s.wire == 2) {
									codeName = s.str();
								} else if (s.field == 8 && s.wire == 0) {
									hasFault = s.num != 0;
								} else if (s.field == 9 && s.wire == 0) {
									fault = s.num;
								}
							}
						}
						break;
					case 14:
						if (t.wire == 2) {
							abort = t.str();
						}
						break;
					case 15:
						if (t.wire == 2) {
							Pb c = t.sub();
							while (c.next()) {
								if (c.field == 1 && c.wire == 2) {
									causes.add(c.str());
								}
							}
						}
						break;
					case 16:
						if (t.wire == 2) {
							thread(t.sub(), threads);
						}
						break;
					case 18:
						if (t.wire == 2) {
							logBuffer(t.sub(), log);
						}
						break;
					default:
						break;
				}
			}
		} catch (RuntimeException ex) {
			// След обрезан (ExitHistory.TRACE_BYTES) или повреждён: что разобрали — то и показываем
			cut = true;
		}
		if (threads.isEmpty() && sigName.isEmpty() && causes.isEmpty()) {
			return null;
		}
		List<String> out = new ArrayList<>();
		StringBuilder sig = new StringBuilder("Сигнал: ");
		sig.append(sigName.isEmpty() ? "№" + sigNum : sigName);
		if (!codeName.isEmpty()) {
			sig.append(" (").append(codeName).append(')');
		}
		if (hasFault) {
			sig.append(", адрес 0x").append(Long.toHexString(fault));
		}
		sig.append(" · процесс ").append(pid).append(", поток ").append(tid);
		out.add(sig.toString());
		for (String c : causes) {
			out.add("Причина: " + c);
		}
		if (!abort.isEmpty()) {
			for (String a : abort.split("\n")) {
				if (!a.trim().isEmpty()) {
					out.add("Abort: " + a.trim());
				}
			}
		}
		Th crash = threads.get(tid);
		if (crash != null) {
			out.add("Поток сбоя: «" + crash.name + "» (tid " + tid + "), кадров " + crash.frames.size() + ":");
			for (String n : crash.notes) {
				out.add("  " + n);
			}
			addFrames(out, crash.frames);
		} else {
			out.add("Поток сбоя (tid " + tid + ") в следе не найден");
		}
		// build-id библиотек самой игры (/data/app/…: libgodot_android.so и др.) — по ним смещения расшифровываются
		Map<String, String> ids = new LinkedHashMap<>();
		for (Th th : threads.values()) {
			for (Frame f : th.frames) {
				if (f.file.contains("/data/app/") && !f.buildId.isEmpty() && !ids.containsKey(base(f.file))) {
					ids.put(base(f.file), f.buildId);
				}
			}
		}
		for (Map.Entry<String, String> e : ids.entrySet()) {
			out.add("build-id " + e.getKey() + ": " + e.getValue());
		}
		if (!log.isEmpty()) {
			int from = Math.max(0, log.size() - LOG_LINES);
			out.add("Журнал процесса (последние " + (log.size() - from) + " из " + log.size() + "):");
			for (int i = from; i < log.size(); i++) {
				out.add("  " + log.get(i));
			}
		}
		int others = threads.size() - (crash != null ? 1 : 0);
		if (others > 0) {
			out.add("Другие потоки (" + others + "):");
			for (Th th : threads.values()) {
				if (th == crash) {
					continue;
				}
				StringBuilder b = new StringBuilder("  «").append(th.name).append("» ").append(th.id);
				for (int i = 0; i < Math.min(OTHER_FRAMES, th.frames.size()); i++) {
					b.append(i == 0 ? ": " : " ← ").append(th.frames.get(i).label());
				}
				out.add(b.toString());
			}
		}
		if (cut || t.cut) {
			out.add("(след обрезан или повреждён — дальше не разобран)");
		}
		if (out.size() > maxLines) {
			int more = out.size() - maxLines + 1;
			List<String> head = new ArrayList<>(out.subList(0, maxLines - 1));
			head.add("… ещё строк: " + more);
			return head;
		}
		return out;
	}

	/** Запись map<uint32, Thread>: ключ — tid. Ошибка внутри потока — поток с тем, что успели разобрать. */
	private static void thread(Pb e, Map<Integer, Th> threads) {
		int key = 0;
		Th th = null;
		try {
			while (e.next()) {
				if (e.field == 1 && e.wire == 0) {
					key = (int)e.num;
				} else if (e.field == 2 && e.wire == 2) {
					th = new Th();
					Pb p = e.sub();
					while (p.next()) {
						if (p.field == 1 && p.wire == 0) {
							th.id = (int)p.num;
						} else if (p.field == 2 && p.wire == 2) {
							th.name = p.str();
						} else if (p.field == 4 && p.wire == 2) {
							th.frames.add(frame(p.sub()));
						} else if (p.field == 7 && p.wire == 2) {
							th.notes.add(p.str());
						}
					}
				}
			}
		} catch (RuntimeException ex) {
			// оставляем разобранное
		}
		if (th != null) {
			if (th.id == 0) {
				th.id = key;
			}
			threads.put(key != 0 ? key : th.id, th);
		}
	}

	private static Frame frame(Pb p) {
		Frame f = new Frame();
		while (p.next()) {
			if (p.field == 1 && p.wire == 0) {
				f.relPc = p.num;
			} else if (p.field == 4 && p.wire == 2) {
				f.function = p.str();
			} else if (p.field == 5 && p.wire == 0) {
				f.functionOffset = p.num;
			} else if (p.field == 6 && p.wire == 2) {
				f.file = p.str();
			} else if (p.field == 8 && p.wire == 2) {
				f.buildId = p.str();
			}
		}
		return f;
	}

	/** LogBuffer {name = 1, logs = 2: LogMessage {timestamp 1, pid 2, tid 3, priority 4, tag 5, message 6}}. */
	private static void logBuffer(Pb p, List<String> out) {
		while (p.next()) {
			if (p.field != 2 || p.wire != 2) {
				continue;
			}
			Pb m = p.sub();
			String ts = "";
			String tag = "";
			String msg = "";
			int prio = 0;
			int mtid = 0;
			while (m.next()) {
				if (m.field == 1 && m.wire == 2) {
					ts = m.str();
				} else if (m.field == 3 && m.wire == 0) {
					mtid = (int)m.num;
				} else if (m.field == 4 && m.wire == 0) {
					prio = (int)m.num;
				} else if (m.field == 5 && m.wire == 2) {
					tag = m.str();
				} else if (m.field == 6 && m.wire == 2) {
					msg = m.str();
				}
			}
			String line = ts + " " + mtid + " " + prioChar(prio) + " " + tag + ": " + msg.trim().replace('\n', ' ');
			out.add(line.length() > ExitHistory.LINE_MAX ? line.substring(0, ExitHistory.LINE_MAX) : line);
		}
	}

	/** Кадры: группа из p кадров, идущая подряд r ≥ MIN_REPEAT раз, — одной строкой (самое длинное покрытие). */
	static void addFrames(List<String> out, List<Frame> fr) {
		int n = fr.size();
		int i = 0;
		while (i < n) {
			int bestP = 0;
			int bestR = 1;
			for (int p = 1; p <= MAX_PERIOD && i + p * MIN_REPEAT <= n; p++) {
				int r = 1;
				while (i + (r + 1) * p <= n && same(fr, i, i + r * p, p)) {
					r++;
				}
				if (r >= MIN_REPEAT && r * p > bestR * Math.max(bestP, 1)) {
					bestP = p;
					bestR = r;
				}
			}
			if (bestP == 1) {
				out.add(String.format(Locale.ROOT, "  #%d–#%d ×%d подряд: %s", i, i + bestR - 1, bestR, fr.get(i).label()));
				i += bestR;
			} else if (bestP > 1) {
				out.add(String.format(Locale.ROOT, "  #%d–#%d: группа из %d кадров ×%d подряд:", i, i + bestR * bestP - 1,
					bestP, bestR));
				for (int k = 0; k < bestP; k++) {
					out.add("      " + fr.get(i + k).label());
				}
				i += bestR * bestP;
			} else {
				out.add(String.format(Locale.ROOT, "  #%d %s", i, fr.get(i).label()));
				i++;
			}
		}
	}

	private static boolean same(List<Frame> fr, int a, int b, int p) {
		for (int k = 0; k < p; k++) {
			if (!fr.get(a + k).key().equals(fr.get(b + k).key())) {
				return false;
			}
		}
		return true;
	}

	static String base(String path) {
		int s = path.lastIndexOf('/');
		return s >= 0 ? path.substring(s + 1) : path;
	}

	static String prioChar(int p) {
		switch (p) {
			case 2: return "V";
			case 3: return "D";
			case 4: return "I";
			case 5: return "W";
			case 6: return "E";
			case 7: return "F";
			default: return "?";
		}
	}

	/** Минимальный разбор protobuf: поле, тип провода, число или кусок байт. */
	static final class Pb {
		private final byte[] d;
		private int p;
		private final int end;
		int field;
		int wire;
		long num;
		private int off;
		private int len;
		/** Поле длиннее оставшихся данных — взять, сколько есть (cut — так было), а не ошибка. */
		boolean lenient;
		boolean cut;

		Pb(byte[] d, int off, int len) {
			this.d = d;
			this.p = off;
			this.end = Math.min(d.length, off + len);
		}

		boolean next() {
			if (p >= end) {
				return false;
			}
			long tag = varint();
			field = (int)(tag >>> 3);
			wire = (int)(tag & 7);
			switch (wire) {
				case 0:
					num = varint();
					break;
				case 1:
					num = fixed(8);
					break;
				case 2: {
					long n = varint();
					if (n < 0 || n > end - p) {
						if (!lenient || n < 0) {
							throw new IllegalStateException("длина за концом");
						}
						cut = true;
						n = end - p;
					}
					off = p;
					len = (int)n;
					p += len;
					break;
				}
				case 5:
					num = fixed(4);
					break;
				default:
					throw new IllegalStateException("тип " + wire);
			}
			if (field == 0) {
				throw new IllegalStateException("поле 0");
			}
			return true;
		}

		private long varint() {
			long r = 0;
			int s = 0;
			while (true) {
				if (p >= end) {
					throw new IllegalStateException("конец данных");
				}
				int b = d[p++] & 0xff;
				r |= (long)(b & 0x7f) << s;
				if ((b & 0x80) == 0) {
					return r;
				}
				s += 7;
				if (s > 63) {
					throw new IllegalStateException("varint");
				}
			}
		}

		private long fixed(int n) {
			if (end - p < n) {
				throw new IllegalStateException("конец данных");
			}
			long r = 0;
			for (int i = 0; i < n; i++) {
				r |= (long)(d[p++] & 0xff) << (8 * i);
			}
			return r;
		}

		String str() {
			return new String(d, off, len, StandardCharsets.UTF_8);
		}

		Pb sub() {
			Pb s = new Pb(d, off, len);
			s.lenient = lenient;
			return s;
		}
	}
}
