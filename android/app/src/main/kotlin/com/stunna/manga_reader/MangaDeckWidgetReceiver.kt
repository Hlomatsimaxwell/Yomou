package com.stunna.manga_reader

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import android.content.ComponentName

class MangaDeckWidgetReceiver : AppWidgetProvider() {

    companion object {
        const val PREFS_NAME = "HomeWidgetPreferences"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.manga_deck_widget)
            val coverViews = arrayOf(R.id.cover_0, R.id.cover_1, R.id.cover_2, R.id.cover_3)

            for (i in coverViews.indices) {
                val imagePath = prefs.getString("cover_path_$i", null)
                val mangaId = prefs.getString("manga_id_$i", null)

                if (!imagePath.isNullOrEmpty()) {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(coverViews[i], bitmap)
                        views.setViewVisibility(coverViews[i], View.VISIBLE)

                        val intent = Intent(context, MainActivity::class.java).apply {
                            action = Intent.ACTION_VIEW
                            putExtra("manga_id", mangaId)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }

                        val pendingIntent = PendingIntent.getActivity(
                            context,
                            i,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(coverViews[i], pendingIntent)
                    } else {
                        views.setViewVisibility(coverViews[i], View.GONE)
                    }
                } else {
                    views.setViewVisibility(coverViews[i], View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
