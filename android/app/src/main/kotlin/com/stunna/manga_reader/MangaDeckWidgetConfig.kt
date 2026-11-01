package com.stunna.manga_reader

import android.content.Context

/**
 * Per widget-instance settings, stored under a key that includes the widget id
 * so two decks on the same home screen can look different.
 */
class MangaDeckWidgetConfig(context: Context, val widgetId: Int) {

    private val prefs = context.applicationContext
        .getSharedPreferences("manga_deck_widget_$widgetId", Context.MODE_PRIVATE)

    var hasBackground: Boolean
        get() = prefs.getBoolean(KEY_BACKGROUND, false)
        set(value) {
            prefs.edit().putBoolean(KEY_BACKGROUND, value).apply()
        }

    fun clear() {
        prefs.edit().clear().apply()
    }

    fun copyFrom(other: MangaDeckWidgetConfig) {
        prefs.edit().clear().putBoolean(KEY_BACKGROUND, other.hasBackground).apply()
    }

    private companion object {
        const val KEY_BACKGROUND = "background"
    }
}
