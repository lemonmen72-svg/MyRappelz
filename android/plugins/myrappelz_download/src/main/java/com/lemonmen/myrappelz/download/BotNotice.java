package com.lemonmen.myrappelz.download;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.util.Log;

/**
 * Уведомление тест-бота (TestBot в игре), пока игра свёрнута: «Тест-бот на паузе». Игра на Android свёрнутой не
 * работает — главный цикл Godot 4.3 стоит, пока активность на паузе (GodotGLRenderView.onActivityPaused ставит поток
 * отрисовки на паузу), поэтому тест не идёт в фоне: он ждёт возвращения, время в фоне в его лимиты не входит, долгие
 * режимы продолжаются с контрольной точки. Фоновой службы нет — честно, без обхода правил Android.
 * <p>
 * Игра сообщает, идёт ли тест и что он делает (DownloadPlugin.botState — с потока отрисовки); плагин показывает
 * уведомление в onMainPause и убирает в onMainResume (поток интерфейса). Касание уведомления — открыть игру
 * (тест продолжится); кнопка «Остановить тест» — BotStopReceiver: флаг в SharedPreferences, игра читает его при
 * возвращении (DownloadPlugin.botStopRequested) — тест останавливается, отчёт пишется, герой игрока возвращается.
 * Процесс выгрузили — флаг читается при следующем запуске (TestBot.recover_after_crash).
 * <p>
 * Android 12+ запрещает открывать активность из приёмника, запущенного кнопкой уведомления («трамплин»), поэтому
 * кнопка только ставит флаг, а открыть игру — касанием самого уведомления (PendingIntent прямо на активность).
 */
final class BotNotice {
	static final String TAG = "MyRappelzDownload";
	static final String PREFS = "darkpact_bot";
	static final String KEY_STOP = "stop";
	static final String KEY_STOP_TIME = "stop_time";
	static final String ACTION_STOP = "com.lemonmen.myrappelz.BOT_STOP";
	static final String CHANNEL = "darkpact_bot";
	static final int NOTIFY_ID = 7302;

	private static volatile boolean running = false;
	private static volatile String title = "";
	private static volatile String text = "";
	private static volatile boolean shown = false;

	private BotNotice() {
	}

	/**
	 * Игра: тест идёт (running) и что он делает. Тест кончился — уведомление убирается. Уведомление уже показано
	 * (onMainPause пришёл раньше, чем поток игры отдал свежий шаг при сворачивании) — текст обновляется.
	 */
	static void setState(Context c, boolean isRunning, String t, String body) {
		running = isRunning;
		title = t != null ? t : "";
		text = body != null ? body : "";
		if (c == null) {
			return;
		}
		if (!isRunning) {
			cancel(c);
		} else if (shown) {
			show(c, false);
		}
	}

	static boolean isRunning() {
		return running;
	}

	/** Активность ушла на паузу (свернули, заблокировали экран, открыли другое приложение). */
	static void onPause(Context c) {
		if (!running || c == null) {
			return;
		}
		show(c, false);
	}

	/** Активность снова на экране: тест продолжается сам — уведомление не нужно. */
	static void onResume(Context c) {
		if (c != null && shown) {
			cancel(c);
		}
	}

	/** Кнопка «Остановить тест» (BotStopReceiver): флаг для игры и уведомление «откройте игру». */
	static void requestStop(Context c) {
		if (c == null) {
			return;
		}
		SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
		p.edit().putBoolean(KEY_STOP, true).putLong(KEY_STOP_TIME, System.currentTimeMillis()).apply();
		show(c, true);
	}

	static boolean stopRequested(Context c) {
		return c != null && c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_STOP, false);
	}

	static void clearStop(Context c) {
		if (c != null) {
			c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY_STOP).remove(KEY_STOP_TIME).apply();
		}
	}

	static void cancel(Context c) {
		try {
			NotificationManager nm = (NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);
			if (nm != null) {
				nm.cancel(NOTIFY_ID);
			}
		} catch (Throwable e) {
			Log.w(TAG, "bot notice cancel failed", e);
		}
		shown = false;
	}

	private static int piFlags() {
		return PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
	}

	/** stopping — после «Остановить тест»: без кнопки, текст «откройте игру». */
	@SuppressWarnings("deprecation")
	private static void show(Context c, boolean stopping) {
		try {
			NotificationManager nm = (NotificationManager)c.getSystemService(Context.NOTIFICATION_SERVICE);
			if (nm == null) {
				return;
			}
			Notification.Builder b;
			if (Build.VERSION.SDK_INT >= 26) {
				NotificationChannel ch = new NotificationChannel(CHANNEL, "Тест-бот", NotificationManager.IMPORTANCE_LOW);
				ch.setDescription("Тест-бот Dark Pact на паузе, пока игра свёрнута");
				nm.createNotificationChannel(ch);
				b = new Notification.Builder(c, CHANNEL);
			} else {
				b = new Notification.Builder(c);
				b.setPriority(Notification.PRIORITY_LOW);
			}
			String head = title.isEmpty() ? "Dark Pact — тест-бот" : title;
			String body;
			if (stopping) {
				body = "Тест будет остановлен — откройте игру: отчёт запишется, ваш герой вернётся.";
			} else {
				body = "На паузе: игра свёрнута, а свёрнутой она не работает. Откройте игру — тест продолжится."
					+ (text.isEmpty() ? "" : "\n" + text);
			}
			b.setSmallIcon(android.R.drawable.ic_media_pause);
			b.setContentTitle(stopping ? head + " — остановка" : head + " — пауза");
			b.setContentText(body);
			b.setStyle(new Notification.BigTextStyle().bigText(body));
			b.setOnlyAlertOnce(true);
			b.setShowWhen(true);
			b.setCategory(Notification.CATEGORY_STATUS);
			b.setAutoCancel(stopping);
			Intent launch = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
			if (launch != null) {
				launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				b.setContentIntent(PendingIntent.getActivity(c, 1, launch, piFlags()));
			}
			if (!stopping) {
				Intent stop = new Intent(c, BotStopReceiver.class);
				stop.setAction(ACTION_STOP);
				PendingIntent pi = PendingIntent.getBroadcast(c, 2, stop, piFlags());
				if (Build.VERSION.SDK_INT >= 23) {
					b.addAction(new Notification.Action.Builder(
						Icon.createWithResource(c, android.R.drawable.ic_menu_close_clear_cancel), "Остановить тест", pi).build());
				} else {
					b.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Остановить тест", pi);
				}
			}
			nm.notify(NOTIFY_ID, b.build());
			shown = true;
		} catch (Throwable e) {
			// Android 13+ без разрешения на уведомления — система молча не покажет; прочие ошибки — в лог
			Log.w(TAG, "bot notice failed", e);
		}
	}
}
