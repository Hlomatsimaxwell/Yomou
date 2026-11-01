package com.stunna.manga_reader

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.widget.Button
import android.widget.ImageButton
import android.widget.Switch

/**
 * Shown by the launcher right after the Manga Deck widget is dropped, matching
 * Kotatsu-Redo's setup screen: a title, a Done button and a background switch.
 *
 * It is a plain platform Activity on purpose -- spinning up the Flutter engine
 * just to toggle one boolean would take seconds.
 */
class MangaDeckWidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The launcher drops the widget unless we finish with RESULT_OK.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_widget_config)
        applySystemBarInsets(findViewById(R.id.config_root))

        val config = MangaDeckWidgetConfig(this, appWidgetId)
        val backgroundSwitch = findViewById<Switch>(R.id.switch_background)
        backgroundSwitch.isChecked = config.hasBackground

        findViewById<ImageButton>(R.id.button_close).setOnClickListener { finish() }
        findViewById<Button>(R.id.button_done).setOnClickListener {
            config.hasBackground = backgroundSwitch.isChecked
            requestWidgetUpdate()
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
            )
            finish()
        }
    }

    /** The app targets API 36, where the system draws edge to edge. */
    private fun applySystemBarInsets(root: View) {
        root.setOnApplyWindowInsetsListener { view, insets ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(
                    insets.systemWindowInsetLeft,
                    insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight,
                    insets.systemWindowInsetBottom,
                )
            }
            insets
        }
        root.requestApplyInsets()
    }

    private fun requestWidgetUpdate() {
        sendBroadcast(
            Intent(this, MangaDeckWidgetReceiver::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            }
        )
    }
}
