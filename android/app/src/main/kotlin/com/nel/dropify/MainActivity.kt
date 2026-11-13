package com.nel.dropify

import android.Manifest
import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Jembatan native untuk download.
 *
 * Semua unduhan memakai DownloadManager supaya file selalu mendarat di
 * /storage/emulated/0/Download/Dropify, tetap jalan di latar belakang, dan
 * progresnya muncul sebagai notifikasi sistem.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.nel.dropify/native"
    private var pendingPermission: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_PERMISSIONS = 4711
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PERMISSIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermission?.success(granted)
            pendingPermission = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "enqueue" -> enqueue(
                            url = call.argument<String>("url"),
                            name = call.argument<String>("name"),
                            mime = call.argument<String>("mime"),
                            subdirArg = call.argument<String>("subdir"),
                            headers = headersFrom(call.argument<Map<String, String>>("headers")),
                            result = result,
                        )
                        "query" -> query((call.argument<Any>("id") as? Number)?.toLong(), result)
                        "cancel" -> cancel((call.argument<Any>("id") as? Number)?.toLong(), result)
                        "openFile" -> openFile((call.argument<Any>("id") as? Number)?.toLong(), result)
                        "openPath" -> result.success(
                            openPath(
                                call.argument<String>("path"),
                                call.argument<String>("mime"),
                            )
                        )
                        "scanFile" -> {
                            val path = call.argument<String>("path")
                            if (path != null) {
                                android.media.MediaScannerConnection.scanFile(
                                    this, arrayOf(path), null, null
                                )
                            }
                            result.success(true)
                        }
                        "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                        "requestAllFilesAccess" -> {
                            requestAllFilesAccess()
                            result.success(hasAllFilesAccess())
                        }
                        "notifyDownload" -> result.success(notifyDownload(call.arguments as? Map<String, Any?>))
                        "cancelNotification" -> {
                            val id = (call.arguments as? Map<String, Any?>)?.get("id") as? Number
                            if (id != null) {
                                NotificationManagerCompat.from(this).cancel(id.toInt())
                            }
                            result.success(true)
                        }
                        "startTransferService" -> {
                            TransferService.start(
                                this,
                                call.argument<String>("text") ?: "Transfer berjalan",
                            )
                            result.success(true)
                        }
                        "updateTransferService" -> {
                            TransferService.update(
                                this,
                                call.argument<String>("text") ?: "Transfer berjalan",
                            )
                            result.success(true)
                        }
                        "stopTransferService" -> {
                            TransferService.stop(this)
                            result.success(true)
                        }
                        "restartApp" -> {
                            recreate()
                            result.success(true)
                        }
                        "shareText" -> {
                            val text = call.argument<String>("text")
                            val title = call.argument<String>("title") ?: "Dropify"
                            if (!text.isNullOrBlank()) {
                                val send = Intent(Intent.ACTION_SEND)
                                    .setType("text/plain")
                                    .putExtra(Intent.EXTRA_TEXT, text)
                                startActivity(Intent.createChooser(send, title))
                            }
                            result.success(true)
                        }
                        "notificationsEnabled" -> result.success(notificationsEnabled())
                        "systemAccent" -> result.success(systemAccentColor())
                        "requestPermissions" -> requestPermissions(result)
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native_error", e.message ?: e.toString(), null)
                }
            }
    }

    private fun headersFrom(raw: Map<String, String>?): Map<String, String> =
        raw ?: emptyMap()

    // ---------------------------------------------------------------- enqueue

    private fun enqueue(
        url: String?,
        name: String?,
        mime: String?,
        subdirArg: String?,
        headers: Map<String, String>,
        result: MethodChannel.Result,
    ) {
        if (url.isNullOrBlank()) {
            result.error("bad_args", "URL download kosong", null)
            return
        }

        val subdir = if (subdirArg.isNullOrBlank()) "Dropify" else sanitize(subdirArg)
        val wanted = sanitize(name ?: "file")
        val unique = uniqueName(subdir, wanted)
        val relative = "$subdir/$unique"

        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(unique)
            .setDescription("Dropify · Download")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, relative)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .addRequestHeader("Accept", "*/*")

        for ((key, value) in headers) {
            request.addRequestHeader(key, value)
        }

        val resolvedMime = if (!mime.isNullOrBlank()) mime else guessMime(unique)
        if (!resolvedMime.isNullOrBlank()) request.setMimeType(resolvedMime)

        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val id = manager.enqueue(request)

        result.success(
            mapOf(
                "id" to id,
                "name" to unique,
                "path" to "/storage/emulated/0/Download/$relative",
            )
        )
    }

    // ------------------------------------------------------------------ query

    private fun query(id: Long?, result: MethodChannel.Result) {
        if (id == null) {
            result.success(null)
            return
        }
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(id))
            ?: run {
                result.success(null)
                return
            }

        try {
            if (!cursor.moveToFirst()) {
                result.success(null)
                return
            }
            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            val received = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            )
            val total = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            )
            val localUri = runCatching {
                cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            }.getOrNull()

            val state = when (status) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "done"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "unknown"
            }

            result.success(
                mapOf(
                    "state" to state,
                    "received" to received,
                    "total" to total,
                    "reason" to reason,
                    "error" to if (state == "failed") reasonText(reason) else null,
                    "uri" to localUri,
                )
            )
        } finally {
            cursor.close()
        }
    }

    // ----------------------------------------------------------------- cancel

    private fun cancel(id: Long?, result: MethodChannel.Result) {
        if (id == null) {
            result.success(false)
            return
        }
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val removed = manager.remove(id)
        result.success(removed > 0)
    }

    // --------------------------------------------------------------- openFile

    private fun openFile(id: Long?, result: MethodChannel.Result) {
        if (id == null) {
            result.success(false)
            return
        }
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val uri: Uri? = manager.getUriForDownloadedFile(id)
        if (uri == null) {
            result.success(false)
            return
        }
        val mime = manager.getMimeTypeForDownloadedFile(id) ?: "application/octet-stream"
        val openUri = if (uri.scheme == "file") {
            runCatching {
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    File(uri.path ?: ""),
                )
            }.getOrNull() ?: uri
        } else {
            uri
        }
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(openUri, mime)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }

    // ------------------------------------------------------- storage akses

    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager()

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT < 30) return
        try {
            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            } catch (_: Exception) {
            }
        }
    }

    // ---------------------------------------------------------- notifikasi

    private fun ensureChannel(): String {
        val channelId = "dropify_downloads"
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(channelId) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        channelId,
                        "Download",
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply {
                        description = "Progres download Dropify"
                        setShowBadge(false)
                    }
                )
            }
        }
        return channelId
    }

    private fun notifyDownload(args: Map<String, Any?>?): Boolean {
        if (args == null) return false
        val id = (args["id"] as? Number)?.toInt() ?: return false
        val title = args["title"] as? String ?: "Download"
        val text = args["text"] as? String ?: ""
        val progress = (args["progress"] as? Number)?.toDouble() ?: -1.0
        val done = args["done"] as? Boolean ?: false
        val error = args["error"] as? String

        val channelId = ensureChannel()
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(if (error != null) error else text)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(!done && error == null)

        when {
            error != null -> builder
                .setSmallIcon(android.R.drawable.stat_notify_error)
                .setProgress(0, 0, false)
            done -> builder
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setProgress(0, 0, false)
            progress >= 0 -> builder
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setProgress(1000, (progress.coerceIn(0.0, 1.0) * 1000).toInt(), false)
            else -> builder
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setProgress(0, 0, true)
        }

        return try {
            NotificationManagerCompat.from(this).notify(id, builder.build())
            true
        } catch (e: SecurityException) {
            false
        }
    }

    private fun openPath(path: String?, mime: String?): Boolean {
        if (path.isNullOrBlank()) return false
        val file = File(path)
        if (!file.exists()) return false
        val uri = try {
            FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        } catch (e: Exception) {
            Uri.fromFile(file)
        }
        val type = if (!mime.isNullOrBlank()) mime else guessMime(file.name) ?: "*/*"
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, type)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    // ------------------------------------------------------------- tema

    /** Warna aksen sistem (Material You), 0 kalau tidak tersedia. */
    private fun systemAccentColor(): Int {
        if (Build.VERSION.SDK_INT < 31) return 0
        return try {
            getColor(android.R.color.system_accent1_500)
        } catch (e: Exception) {
            0
        }
    }

    // ------------------------------------------------------------ permissions

    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= 33) {
            return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        }
        if (Build.VERSION.SDK_INT >= 24) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            return nm.areNotificationsEnabled()
        }
        return true
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        val wanted = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            wanted.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (Build.VERSION.SDK_INT in 23..29 &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            wanted.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
        if (wanted.isEmpty()) {
            result.success(true)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(this, wanted.toTypedArray(), REQUEST_PERMISSIONS)
    }

    // ----------------------------------------------------------------- utils

    private fun reasonText(reason: Int): String = when (reason) {
        DownloadManager.ERROR_INSUFFICIENT_SPACE -> "Ruang penyimpanan penuh"
        DownloadManager.ERROR_FILE_ALREADY_EXISTS -> "File dengan nama itu sudah ada"
        DownloadManager.ERROR_CANNOT_RESUME -> "Download tidak bisa dilanjutkan"
        DownloadManager.ERROR_TOO_MANY_REDIRECTS -> "Terlalu banyak redirect"
        DownloadManager.ERROR_UNHANDLED_HTTP_CODE -> "Server menolak permintaan"
        DownloadManager.ERROR_HTTP_DATA_ERROR -> "Koneksi terputus saat mengunduh"
        DownloadManager.ERROR_UNKNOWN -> "Download gagal"
        else -> if (reason in 400..599) "Server menolak (HTTP $reason)" else "Download gagal ($reason)"
    }

    private fun sanitize(raw: String): String {
        var name = raw.trim()
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .replace(Regex("[\\u0000-\\u001F]"), "")
        if (name.isEmpty()) name = "file"
        if (name.startsWith(".")) name = "_$name"
        if (name.length > 100) name = name.substring(0, 100)
        return name
    }

    private fun uniqueName(subdir: String, name: String): String {
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var candidate = name
        var index = 1
        while (existsInDownloads(subdir, candidate) && index < 1000) {
            candidate = "$stem ($index)$ext"
            index++
        }
        return candidate
    }

    private fun existsInDownloads(subdir: String, name: String): Boolean {
        if (Build.VERSION.SDK_INT >= 29) {
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val projection = arrayOf(MediaStore.Downloads._ID)
            val selection =
                "${MediaStore.Downloads.DISPLAY_NAME} = ? AND ${MediaStore.Downloads.RELATIVE_PATH} LIKE ?"
            val args = arrayOf(name, "%Download/$subdir/%")
            return try {
                contentResolver.query(collection, projection, selection, args, null)?.use {
                    it.count > 0
                } ?: false
            } catch (e: Exception) {
                false
            }
        }
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            subdir,
        )
        return File(dir, name).exists()
    }

    private fun guessMime(name: String): String? {
        val ext = name.substringAfterLast('.', "").lowercase()
        if (ext.isEmpty()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
    }
}
