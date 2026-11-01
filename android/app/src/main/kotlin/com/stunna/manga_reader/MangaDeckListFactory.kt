package com.stunna.manga_reader

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.max
import kotlin.math.roundToInt

class MangaDeckListFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private class Item(val mangaId: String, val title: String, val coverUrl: String)

    private val dataSet = ArrayList<Item>()
    private val dbPath = context.getDatabasePath("manga_reader.db").absolutePath

    private val res = context.resources
    private val coverWidthPx = res.getDimensionPixelSize(R.dimen.widget_cover_width)
    private val coverHeightPx = res.getDimensionPixelSize(R.dimen.widget_cover_height)
    private val cornerRadiusPx = res.getDimension(R.dimen.appwidget_corner_radius_inner)

    override fun onCreate() = Unit

    override fun getLoadingView(): RemoteViews? = null

    override fun getItemId(position: Int): Long {
        return dataSet.getOrNull(position)?.mangaId?.hashCode()?.toLong() ?: 0L
    }

    override fun onDataSetChanged() {
        dataSet.clear()
        try {
            val db = SQLiteDatabase.openDatabase(dbPath, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(
                "SELECT mangaId, title, coverUrl FROM manga " +
                    "WHERE lastReadChapter >= 0 ORDER BY lastReadAt DESC LIMIT 10",
                null
            )
            while (cursor.moveToNext()) {
                val mangaId = cursor.getString(0) ?: ""
                if (mangaId.isNotEmpty()) {
                    dataSet.add(
                        Item(
                            mangaId = mangaId,
                            title = cursor.getString(1) ?: "",
                            coverUrl = cursor.getString(2) ?: "",
                        )
                    )
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

        val cover = if (item.coverUrl.isNotEmpty()) loadCover(item.coverUrl) else null
        if (cover != null) {
            views.setImageViewBitmap(R.id.imageView_cover, cover)
        } else {
            // Rounded placeholder, so every card in the deck keeps its corners.
            views.setImageViewResource(R.id.imageView_cover, R.drawable.widget_cover_placeholder)
        }
        if (item.title.isNotEmpty()) {
            views.setContentDescription(R.id.imageView_cover, item.title)
        }

        val fillInIntent = Intent()
        fillInIntent.putExtra("manga_id", item.mangaId)
        views.setOnClickFillInIntent(R.id.imageView_cover, fillInIntent)

        return views
    }

    override fun getCount(): Int = dataSet.size

    override fun getViewTypeCount(): Int = 1

    override fun onDestroy() = Unit

    /**
     * Downloads, centre-crops to the exact cover size and rounds the corners.
     *
     * Rounding has to happen *after* scaling: the radius is 20dp, which is only
     * meaningful relative to an 84dp-wide bitmap. Rounding a full resolution
     * cover (e.g. 800px wide) with a 20dp radius would be invisible once the
     * ImageView scales it down.
     */
    private fun loadCover(url: String): Bitmap? {
        return try {
            val bytes = fetch(url) ?: return null
            val source = decodeSampled(bytes, coverWidthPx, coverHeightPx) ?: return null
            val cropped = centerCrop(source, coverWidthPx, coverHeightPx)
            roundCorners(cropped, cornerRadiusPx)
        } catch (e: Exception) {
            Log.e("MangaDeckFactory", "Cover failed: ${e.message}")
            null
        }
    }

    private fun fetch(url: String): ByteArray? {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.doInput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
                    "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36",
            )
            connection.setRequestProperty("Referer", originOf(url))
            connection.connect()
            return connection.inputStream.use { it.readBytes() }
        } finally {
            connection.disconnect()
        }
    }

    private fun originOf(url: String): String {
        return try {
            val uri = URL(url)
            "${uri.protocol}://${uri.host}/"
        } catch (_: Exception) {
            url
        }
    }

    private fun decodeSampled(bytes: ByteArray, width: Int, height: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (
            bounds.outWidth / (sample * 2) >= width &&
            bounds.outHeight / (sample * 2) >= height
        ) {
            sample *= 2
        }

        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    private fun centerCrop(source: Bitmap, width: Int, height: Int): Bitmap {
        val scale = max(width.toFloat() / source.width, height.toFloat() / source.height)
        val scaledWidth = (source.width * scale).roundToInt().coerceAtLeast(width)
        val scaledHeight = (source.height * scale).roundToInt().coerceAtLeast(height)
        val scaled = if (scaledWidth == source.width && scaledHeight == source.height) {
            source
        } else {
            Bitmap.createScaledBitmap(source, scaledWidth, scaledHeight, true)
        }
        val left = (scaledWidth - width) / 2
        val top = (scaledHeight - height) / 2
        val cropped = if (left == 0 && top == 0 && scaled.width == width && scaled.height == height) {
            scaled
        } else {
            Bitmap.createBitmap(scaled, left, top, width, height)
        }
        if (scaled !== source && scaled !== cropped) scaled.recycle()
        if (source !== cropped) source.recycle()
        return cropped
    }

    private fun roundCorners(source: Bitmap, radius: Float): Bitmap {
        val result = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawRoundRect(
            RectF(0f, 0f, source.width.toFloat(), source.height.toFloat()),
            radius,
            radius,
            paint,
        )
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(source, 0f, 0f, paint)
        source.recycle()
        return result
    }
}
