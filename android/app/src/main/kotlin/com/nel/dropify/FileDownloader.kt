package com.nel.dropify

import android.content.Context
import android.os.Environment
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

/**
 * Pengunduh berkas yang berjalan sepenuhnya di sisi native.
 *
 * Unduhan besar tidak lagi ditulis dari Dart: seluruh aliran data ditangani
 * thread di sini dengan buffer 64 KB, jadi memori aplikasi tidak tumbuh
 * mengikuti ukuran berkas. Progres dikirim ke Dart sebagai kejadian biasa;
 * kalau Dart sedang sibuk, unduhan tetap jalan.
 */
object FileDownloader {

    class Job(val id: String, val url: String, val name: String, val headers: Map<String, String>) {
        @Volatile
        var canceled: Boolean = false
    }

    private val jobs = ConcurrentHashMap<String, Job>()

    fun cancel(id: String) {
        jobs[id]?.canceled = true
        jobs.remove(id)
    }

    /**
     * Mulai unduhan. [emit] dipanggil dari thread latar dengan keadaan terbaru:
     * {id, state: running|done|failed, received, total, path, error}.
     */
    fun start(
        context: Context,
        id: String,
        url: String,
        name: String,
        headers: Map<String, String>,
        emit: (Map<String, Any?>) -> Unit,
    ) {
        val job = Job(id, url, name, headers)
        jobs[id] = job

        val thread = Thread({
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "Dropify",
            )
            if (!dir.exists()) dir.mkdirs()

            val target = uniqueFile(dir, sanitize(name))
            val part = File(target.path + ".part")

            try {
                var attempt = 0
                while (attempt < 4) {
                    attempt++
                    if (job.canceled) return@Thread
                    try {
                        downloadOnce(job, part, emit)
                        if (job.canceled) return@Thread
                        if (target.exists()) target.delete()
                        if (!part.renameTo(target)) {
                            part.copyTo(target, overwrite = true)
                            part.delete()
                        }
                        android.media.MediaScannerConnection.scanFile(
                            context, arrayOf(target.path), null, null,
                        )
                        emit(
                            mapOf(
                                "id" to id,
                                "state" to "done",
                                "received" to target.length(),
                                "total" to target.length(),
                                "path" to target.path,
                            ),
                        )
                        return@Thread
                    } catch (e: Throwable) {
                        if (job.canceled) return@Thread
                        if (attempt >= 4) {
                            emit(
                                mapOf(
                                    "id" to id,
                                    "state" to "failed",
                                    "received" to part.length(),
                                    "total" to part.length(),
                                    "error" to (e.message ?: e.toString()),
                                ),
                            )
                            return@Thread
                        }
                        try {
                            Thread.sleep(700L * attempt)
                        } catch (_: InterruptedException) {
                        }
                    }
                }
            } finally {
                jobs.remove(id)
            }
        }, "dropify-download-$id")
        thread.start()
    }

    private fun downloadOnce(
        job: Job,
        part: File,
        emit: (Map<String, Any?>) -> Unit,
    ) {
        var start = if (part.exists()) part.length() else 0L

        var connection = openConnection(job, start)
        var code = connection.responseCode
        if (start > 0 && code != 206) {
            // Server mengabaikan Range: mulai dari nol.
            connection.disconnect()
            if (part.exists()) part.delete()
            start = 0
            connection = openConnection(job, 0)
            code = connection.responseCode
        }
        if (code != 200 && code != 206) {
            connection.disconnect()
            throw IllegalStateException("HTTP $code")
        }

        var total = connection.contentLengthLong
        if (total > 0) total += start

        var received = start
        val buffer = ByteArray(64 * 1024)
        var lastEmit = 0L

        val output = FileOutputStream(part, start > 0)
        try {
            connection.inputStream.use { input ->
                while (true) {
                    if (job.canceled) break
                    val read = input.read(buffer)
                    if (read <= 0) break
                    output.write(buffer, 0, read)
                    received += read
                    val now = System.currentTimeMillis()
                    if (now - lastEmit >= 500) {
                        lastEmit = now
                        emit(
                            mapOf(
                                "id" to job.id,
                                "state" to "running",
                                "received" to received,
                                "total" to total,
                            ),
                        )
                    }
                }
            }
            output.flush()
        } finally {
            try {
                output.close()
            } catch (_: Exception) {
            }
            connection.disconnect()
        }

        if (job.canceled) return
        if (total > 0 && received < total) {
            throw IllegalStateException("terputus (${received}/${total})")
        }
        emit(
            mapOf(
                "id" to job.id,
                "state" to "running",
                "received" to received,
                "total" to if (total > 0) total else received,
            ),
        )
    }

    private fun openConnection(job: Job, start: Long): HttpURLConnection {
        val connection = URL(job.url).openConnection() as HttpURLConnection
        connection.connectTimeout = 20000
        connection.readTimeout = 30000
        connection.instanceFollowRedirects = true
        connection.setRequestProperty(
            "User-Agent",
            "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/124.0.0.0 Mobile Safari/537.36",
        )
        connection.setRequestProperty("Accept", "*/*")
        for ((key, value) in job.headers) {
            connection.setRequestProperty(key, value)
        }
        if (start > 0) connection.setRequestProperty("Range", "bytes=$start-")
        return connection
    }

    private fun sanitize(name: String): String {
        var clean = name.replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_").trim()
        clean = clean.replace(Regex("\\s+"), " ")
        if (clean.isEmpty()) clean = "file"
        if (clean.startsWith(".")) clean = "_$clean"
        return clean
    }

    private fun uniqueFile(dir: File, name: String): File {
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        var candidate = File(dir, name)
        var i = 1
        // Nama yang belum punya berkas final dipakai apa adanya, termasuk kalau
        // ada sisa .part — itu yang membuat unduhan melanjutkan, bukan mengulang.
        while (candidate.exists()) {
            candidate = File(dir, "$stem ($i)$ext")
            i++
            if (i > 999) break
        }
        return candidate
    }
}
