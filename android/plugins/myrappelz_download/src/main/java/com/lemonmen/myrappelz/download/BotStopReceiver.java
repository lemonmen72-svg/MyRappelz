package com.lemonmen.myrappelz.download;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Кнопка «Остановить тест» в уведомлении тест-бота (BotNotice): только флаг — игра свёрнута и не работает, тест
 * остановится, когда игра откроется (или при следующем запуске, если процесс выгрузили). Приёмник не экспортирован:
 * его зовёт только PendingIntent этого же приложения.
 */
public class BotStopReceiver extends BroadcastReceiver {
	@Override
	public void onReceive(Context context, Intent intent) {
		if (intent != null && BotNotice.ACTION_STOP.equals(intent.getAction())) {
			BotNotice.requestStop(context);
		}
	}
}
