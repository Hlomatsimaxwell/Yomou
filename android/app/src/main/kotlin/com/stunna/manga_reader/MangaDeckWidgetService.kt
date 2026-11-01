package com.stunna.manga_reader

import android.content.Intent
import android.widget.RemoteViewsService

class MangaDeckWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MangaDeckListFactory(applicationContext, intent)
    }
}
