package com.stunna.manga_reader

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

class MangaDeckListFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val dataSet = ArrayList<Pair<String, String>>() // (mangaId, coverUrl)
    private val dbPath = context.getDatabasePath("manga_reader.db").absolutePath

    override fun onCreate() = Unit

    override fun getLoadingView(): RemoteViews? = null

    override fun getItemId(position: Int): Long {
        return dataSet.getOrNull(position)?.first?.hashCode()?.toLong() ?: 0L
    }

    override fun onDataSetChanged() {
        dataSet.clear()
        try {
            val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(
                "SELECT mangaId, coverUrl FROM manga WHERE lastReadChapter >= 0 ORDER BY lastReadAt DESC LIMIT 10",
                null
            )
            while (cursor.moveToNext()) {
                val mangaId = cursor.getString(0) ?: ""
                val coverUrl = cursor.getString(1) ?: ""
                if (mangaId.isNotEmpty()) {
                    dataSet.add(Pair(mangaId, coverUrl))
                }
            }
            cursor.close()
            db.close()
            Log.d("MangaDeckFactory", "Loaded ${dataSet.size} items")
        } catch (e: Exception) {
            Log.e("MangaDeckFactory", "Error loading data: ${e.message}")
        }
    }

    override fun hasStableIds(): Boolean = true

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.item_recent)
        val item = dataSet.getOrNull(position) ?: return views

        val coverUrl = item.second
        if (coverUrl.isNotEmpty()) {
            try {
                val bitmap = downloadBitmap(coverUrl)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.imageView_cover, bitmap)
                } else {
                    views.setImageViewResource(R.id.imageView_cover, android.R.drawable.ic_menu_gallery)
                }
            } catch (e: Exception) {
                Log.e("MangaDeckFactory", "Error loading cover: ${e.message}")
                views.setImageViewResource(R.id.imageView_cover, android.R.drawable.ic_menu_gallery)
            }
        } else {
            views.setImageViewResource(R.id.imageView_cover, android.R.drawable.ic_menu_gallery)
        }

        // Set click intent
        val fillInIntent = Intent()
        fillInIntent.putExtra("manga_id", item.first)
        views.setOnClickFillInIntent(R.id.imageView_cover, fillInIntent)

        return views
    }

    override fun getCount(): Int = dataSet.size

    override fun getViewTypeCount(): Int = 1

    override fun onDestroy() = Unit

    private fun downloadBitmap(url: String): Bitmap? {
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.doInput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.connect()
            val input = connection.inputStream
            val original = BitmapFactory.decodeStream(input) ?: return null
            // Apply rounded corners like Kotatsu-Redo
            val radius = (12 * context.resources.displayMetrics.density)
            roundBitmap(original, radius)
        } catch (e: Exception) {
            Log.e("MangaDeckFactory", "Download failed: ${e.message}")
            null
        }
    }

    private fun roundBitmap(source: Bitmap, radius: Float): Bitmap {
        val result = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(result)
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        val rect = android.graphics.RectF(0f, 0f, source.width.toFloat(), source.height.toFloat())
        canvas.drawRoundRect(rect, radius, radius, paint)
        paint.xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(source, 0f, 0f, paint)
        return result
    }
}
