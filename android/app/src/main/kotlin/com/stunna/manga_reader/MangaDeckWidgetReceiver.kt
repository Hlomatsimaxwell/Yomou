package com.stunna.manga_reader

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews

class MangaDeckWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_recent)

            if (MangaDeckWidgetConfig(context, appWidgetId).hasBackground) {
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.bg_appwidget_root)
            } else {
                views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
            }

            val adapter = Intent(context, MangaDeckWidgetService::class.java)
            adapter.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            adapter.data = Uri.parse(adapter.toUri(Intent.URI_INTENT_SCHEME))
            views.setRemoteAdapter(R.id.stackView, adapter)

            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.stackView, pendingIntent)

            views.setEmptyView(R.id.stackView, R.id.textView_holder)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.stackView)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        for (appWidgetId in appWidgetIds) {
            MangaDeckWidgetConfig(context, appWidgetId).clear()
        }
    }

    override fun onRestored(context: Context, oldWidgetIds: IntArray, newWidgetIds: IntArray) {
        super.onRestored(context, oldWidgetIds, newWidgetIds)
        if (oldWidgetIds.size != newWidgetIds.size) return
        for (i in oldWidgetIds.indices) {
            MangaDeckWidgetConfig(context, newWidgetIds[i])
                .copyFrom(MangaDeckWidgetConfig(context, oldWidgetIds[i]))
        }
    }
}
