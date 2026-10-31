package com.stunna.manga_reader

import android.app.Activity
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.Settings
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val dirPickerRequestCode = 0xDA1
    private var dirPickerResult: MethodChannel.Result? = null

    /** Set by the reader while a chapter is open; see [dispatchKeyEvent]. */
    private lateinit var volumeChannel: MethodChannel
    private var volumeKeysEnabled = false

    /** Request code for the storage permission a pre-Q gallery save needs. */
    private val galleryPermissionCode = 0x6A11

    /** A save waiting on that permission; invoked with whether it was granted. */
    private var pendingSave: ((Boolean) -> Unit)? = null

    /** Lets Dart receive yomou:// links; see [onNewIntent]. */
    private var linksChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/battery"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openBatterySettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("battery", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/secure"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenshotBlocked" -> {
                    val block = call.arguments as? Boolean ?: false
                    runOnUiThread {
                        if (block) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/saf"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDirectoryPicker" -> {
                    dirPickerResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    intent.addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                    )
                    startActivityForResult(intent, dirPickerRequestCode)
                }
                "resolveTreeUri" -> {
                    val uriString = call.arguments as? String
                    if (uriString.isNullOrEmpty()) {
                        result.error("uri", "no uri given", null)
                        return@setMethodCallHandler
                    }
                    result.success(treeUriToPath(Uri.parse(uriString)))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStats" -> {
                    val path = call.arguments as? String
                    if (path.isNullOrEmpty()) {
                        result.error("path", "no path given", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val stat = StatFs(path)
                        result.success(
                            mapOf(
                                "total" to stat.totalBytes,
                                "free" to stat.availableBytes
                            )
                        )
                    } catch (e: Exception) {
                        result.error("statfs", e.message, null)
                    }
                }
                // The real shared Downloads folder. `path_provider`'s
                // getDownloadsDirectory() falls back to the app-scoped external
                // dir on API 29+, which is neither shared nor visible to the
                // user, so settings would label a private folder "Public
                // downloads". Resolving it natively keeps the label honest.
                "getPublicDownloadsPath" -> {
                    result.success(
                        Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS
                        )?.absolutePath
                    )
                }
                // Whether the active network is metered (mobile data), so the
                // "ask about cellular downloads" setting only interrupts the
                // user on mobile data and never on Wi-Fi.
                "isMetered" -> {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE)
                        as? ConnectivityManager
                    result.success(
                        cm?.activeNetwork?.let {
                            cm.getNetworkCapabilities(it)
                                ?.hasCapability(
                                    NetworkCapabilities.NET_CAPABILITY_NOT_METERED
                                ) == false
                        } ?: false
                    )
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/display"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // "Keep screen on": the reader arms this while a chapter is
                // open and disarms it on exit, so the display never sleeps
                // mid-page without leaving the flag set for the whole app.
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                // "Only on Wi-Fi" preloading. Reports unmetered, not Wi-Fi by
                // name: an unmetered connection is the thing that actually
                // matters, and Ethernet should behave like Wi-Fi.
                "isUnmetered" -> {
                    try {
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE)
                            as? ConnectivityManager
                        val net = cm?.activeNetwork
                        result.success(
                            net == null ||
                                cm.getNetworkCapabilities(net)
                                    ?.hasCapability(
                                        NetworkCapabilities.NET_CAPABILITY_NOT_METERED
                                    ) == true
                        )
                    } catch (e: Exception) {
                        result.error("connectivity", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/volume"
        ).also { volumeChannel = it }.setMethodCallHandler { call, result ->
            when (call.method) {
                // Armed by the reader only while a chapter is open and the
                // setting asks for it, so volume keys keep working normally
                // everywhere else in the app.
                "setEnabled" -> {
                    volumeKeysEnabled = call.argument<Boolean>("enabled") ?: false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/gallery"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // A cover was expanded and the reader asked to keep it. The
                // bytes arrive from Dart, which already fetched them through
                // the cache with the source's referer, so this only has to
                // land them in the system gallery.
                "saveImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name") ?: "cover.jpg"
                    val mime = call.argument<String>("mime") ?: "image/jpeg"
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("bytes", "no image data", null)
                        return@setMethodCallHandler
                    }
                    saveImageToGallery(bytes, name, mime, result)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/links"
        ).also { linksChannel = it }.setMethodCallHandler { call, result ->
            when (call.method) {
                // A yomou:// link shared from the manga share sheet launched
                // the app: hand back the launch intent's data so Dart can open
                // the manga it names.
                "getInitialUri" -> result.success(intent?.data?.toString())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/widget"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveWidgetData" -> {
                    try {
                        val coverPaths = call.argument<List<String?>>("coverPaths")
                        val mangaIds = call.argument<List<String?>>("mangaIds")
                        android.util.Log.d("YomouWidget", "saveWidgetData called: $coverPaths")
                        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        val editor = prefs.edit()
                        for (i in 0..3) {
                            val cp = coverPaths?.getOrNull(i)
                            val mi = mangaIds?.getOrNull(i)
                            if (!cp.isNullOrEmpty()) editor.putString("cover_path_$i", cp) else editor.remove("cover_path_$i")
                            if (!mi.isNullOrEmpty()) editor.putString("manga_id_$i", mi) else editor.remove("manga_id_$i")
                        }
                        editor.apply()
                        android.util.Log.d("YomouWidget", "saved to prefs")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("YomouWidget", "error: ${e.message}")
                        result.error("widget", e.message, null)
                    }
                }
                "updateWidget" -> {
                    try {
                        val manager = android.appwidget.AppWidgetManager.getInstance(this)
                        val component = android.content.ComponentName(this, MangaDeckWidgetReceiver::class.java)
                        val ids = manager.getAppWidgetIds(component)
                        val intent = Intent(this, MangaDeckWidgetReceiver::class.java).apply {
                            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        }
                        sendBroadcast(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("widget", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/share"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // A share row was tapped: hand the chosen link to the system
                // share sheet (ACTION_SEND) so the user can send it to
                // WhatsApp, email, or anywhere else in one tap.
                "shareText" -> {
                    val text = call.argument<String>("text")
                    if (text.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(send, null))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("share", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hlomatsi.yomou/app_icon"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Toggle the launcher icon between dark (default, MAIN
                // activity) and light (AliasLight alias). Some launchers
                // cache the old icon for a while after the toggle, so the
                // UI may take a few seconds or a launcher restart to catch
                // up — that is an OS limitation, not a bug here.
                "setAlias" -> {
                    val alias = call.argument<String>("alias")
                    val pkg = packageName
                    val mainName = "$pkg.MainActivity"
                        .replace(pkg + ".", "com.stunna.manga_reader.")
                    val aliasName = "$pkg.AliasLight"
                        .replace(
                            pkg + ".",
                            "com.stunna.manga_reader."
                        )
                    try {
                        val pm = packageManager
                        val mainComp = ComponentName(
                            pkg,
                            "com.stunna.manga_reader.MainActivity"
                        )
                        val lightComp = ComponentName(
                            pkg,
                            "com.stunna.manga_reader.AliasLight"
                        )
                        val wantLight = (alias == "light")
                        pm.setComponentEnabledSetting(
                            mainComp,
                            if (wantLight) PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                            else PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        pm.setComponentEnabledSetting(
                            lightComp,
                            if (wantLight) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("app_icon", e.message, null)
                    }
                }
                "getAlias" -> {
                    try {
                        val pkg = packageName
                        val lightComp = ComponentName(
                            pkg,
                            "com.stunna.manga_reader.AliasLight"
                        )
                        val state = packageManager
                            .getComponentEnabledSetting(lightComp)
                        val isLight =
                            state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        result.success(if (isLight) "light" else "dark")
                    } catch (e: Exception) {
                        result.error("app_icon", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Lands [bytes] in the shared gallery. Android 10 and up go through
     * MediaStore, which needs no permission; older releases (this app still
     * targets 9) write to the public Pictures folder and ask for
     * WRITE_EXTERNAL_STORAGE first, resuming here once the reader answers.
     */
    private fun saveImageToGallery(
        bytes: ByteArray,
        name: String,
        mime: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            pendingSave = { granted ->
                if (granted) {
                    performSave(bytes, name, mime, result)
                } else {
                    result.error("permission", "storage permission denied", null)
                }
            }
            requestPermissions(
                arrayOf(android.Manifest.permission.WRITE_EXTERNAL_STORAGE),
                galleryPermissionCode
            )
            return
        }
        performSave(bytes, name, mime, result)
    }

    private fun performSave(
        bytes: ByteArray,
        name: String,
        mime: String,
        result: MethodChannel.Result
    ) {
        try {
            result.success(writeImage(bytes, name, mime)?.toString())
        } catch (e: Exception) {
            result.error("save", e.message, null)
        }
    }

    private fun writeImage(bytes: ByteArray, name: String, mime: String): Uri? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/Yomou"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values
            ) ?: return null
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return uri
        }
        val dir = File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES
            ),
            "Yomou"
        )
        if (!dir.exists()) dir.mkdirs()
        val file = uniqueFile(dir, name)
        file.writeBytes(bytes)
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf(mime),
            null
        )
        return Uri.fromFile(file)
    }

    /** `<name>.jpg`, then `<name> (1).jpg`, ... so a repeat never clobbers. */
    private fun uniqueFile(dir: File, name: String): File {
        var file = File(dir, name)
        if (!file.exists()) return file
        val dot = name.lastIndexOf('.')
        val base = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var i = 1
        while (file.exists()) {
            file = File(dir, "$base ($i)$ext")
            i++
        }
        return file
    }

    @Deprecated("Deprecated in Java")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != galleryPermissionCode) return
        val pending = pendingSave
        pendingSave = null
        pending?.invoke(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
        )
    }

    /**
     * Routes volume presses to the reader instead of the system volume panel.
     * Returns true to swallow the event once the reader is handling it; when
     * the reader is closed or the setting is off the key travels on untouched.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (volumeKeysEnabled && event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeChannel.invokeMethod("volumeKey", mapOf("up" to true))
                    return true
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeChannel.invokeMethod("volumeKey", mapOf("up" to false))
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    /**
     * A yomou:// link tapped while the app is already open lands here: the
     * activity is singleTop, so a second launch becomes a new intent instead
     * of a fresh activity. Forward it to Dart, which is already listening.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        linksChannel?.let { channel ->
            try {
                channel.invokeMethod("onNewIntent", intent.data?.toString())
            } catch (_: Exception) {
                // Dart wasn't registered yet (shouldn't happen with singleTop);
                // the cold-start launch-intent path covers that case.
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != dirPickerRequestCode) return
        val pending = dirPickerResult ?: return
        dirPickerResult = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri != null) {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            } catch (_: Exception) {
                // Grant may only cover this session; the picked URI is still useful.
            }
            pending.success(uri.toString())
        } else {
            pending.success(null)
        }
    }

    /**
     * Turns a `content://…/tree/<docId>` URI picked through
     * ACTION_OPEN_DOCUMENT_TREE into a real file-system path (for example
     * `/storage/emulated/0/Download`) so settings can show a readable location
     * instead of the raw URI. Returns null when the volume can't be matched,
     * e.g. an unmounted SD card.
     */
    private fun treeUriToPath(uri: Uri): String? {
        val docId = try {
            DocumentsContract.getTreeDocumentId(uri)
        } catch (_: Exception) {
            return null
        }
        // Some providers (Downloads, MediaStore) encode an absolute path in
        // the document id itself, e.g. "raw:/storage/emulated/0/Download/saves".
        if (docId.startsWith("/")) return docId
        if (docId.startsWith("raw:/", ignoreCase = true)) return docId.substring(4)
        val volumeId = docId.substringBefore(":").removePrefix("uuid:")
        val relative = docId.substringAfter(":", "")
        val base = if (volumeId.equals("primary", ignoreCase = true)) {
            Environment.getExternalStorageDirectory()?.absolutePath
        } else {
            volumeRoots().firstOrNull {
                it.substringAfterLast("/").equals(volumeId, ignoreCase = true)
            }
        } ?: return null
        return if (relative.isEmpty()) base else "$base/$relative"
    }

    /** Mount points of every mounted external volume (e.g. `/storage/1AEF-2A03`). */
    private fun volumeRoots(): List<String> {
        val roots = ArrayList<String>()
        for (dir in getExternalFilesDirs(null)) {
            if (dir == null) continue
            try {
                // .../Android/data/<pkg>/files -> up to the volume root.
                val root = File(dir, "../../..").canonicalFile.absolutePath
                roots.add(root)
            } catch (_: Exception) {
                // Ignore volumes we can't resolve.
            }
        }
        return roots.distinct()
    }
}