package com.jianxi.reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val APK_CHANNEL = "com.jianxi.reader/apk_install"
    private val DOCUMENT_CHANNEL = "com.jianxi.reader/document_access"
    private val DOCUMENT_PICK_REQUEST = 21013
    private var pendingDocumentPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    result.success(canRequestPackageInstalls())
                }
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(true)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        installApk(path)
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOCUMENT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDocument" -> pickDocument(result)
                "refreshDocument" -> {
                    val uri = call.argument<String>("uri")
                    val path = call.argument<String>("path")
                    if (uri.isNullOrEmpty() || path.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "uri and path are required", null)
                    } else {
                        try {
                            result.success(copyUriToFile(Uri.parse(uri), File(path)))
                        } catch (error: Exception) {
                            result.error("REFRESH_FAILED", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == DOCUMENT_PICK_REQUEST) {
            val result = pendingDocumentPickResult
            pendingDocumentPickResult = null
            if (result == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }

            val uri = data?.data
            if (uri == null) {
                result.error("NO_URI", "Document picker did not return a uri", null)
                return
            }

            persistReadPermission(uri, data)
            try {
                val name = queryDisplayName(uri) ?: "document"
                val file = nextDocumentMirrorFile(name)
                val metadata = copyUriToFile(uri, file).toMutableMap()
                metadata["uri"] = uri.toString()
                result.success(metadata)
            } catch (error: Exception) {
                result.error("COPY_FAILED", error.message, null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun pickDocument(result: MethodChannel.Result) {
        if (pendingDocumentPickResult != null) {
            result.error("PICK_IN_PROGRESS", "A document picker request is already active", null)
            return
        }
        pendingDocumentPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "text/markdown",
                    "text/x-markdown",
                    "text/html",
                    "application/xhtml+xml"
                )
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, DOCUMENT_PICK_REQUEST)
        } catch (error: Exception) {
            pendingDocumentPickResult = null
            result.error("PICK_FAILED", error.message, null)
        }
    }

    private fun persistReadPermission(uri: Uri, data: Intent?) {
        val flags = data?.flags ?: 0
        val readFlag = flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (readFlag == 0) return
        try {
            contentResolver.takePersistableUriPermission(uri, readFlag)
        } catch (_: SecurityException) {
            // Some providers grant only transient read permission. The local mirror still works
            // for the current session, and refresh will surface an error if permission is lost.
        }
    }

    private fun copyUriToFile(uri: Uri, file: File): Map<String, Any?> {
        file.parentFile?.mkdirs()
        val input = contentResolver.openInputStream(uri)
            ?: throw IOException("Unable to open document input stream")
        input.use { source ->
            file.outputStream().use { destination ->
                source.copyTo(destination)
            }
        }

        val modifiedAt = queryLastModified(uri)
        if (modifiedAt > 0L) {
            file.setLastModified(modifiedAt)
        }
        return mapOf(
            "path" to file.absolutePath,
            "name" to file.name,
            "size" to file.length(),
            "modifiedAt" to file.lastModified()
        )
    }

    private fun nextDocumentMirrorFile(displayName: String): File {
        val directory = File(filesDir, "referenced_documents")
        val cleanName = sanitizeFileName(displayName).ifEmpty { "document" }
        val candidate = File(directory, "${System.currentTimeMillis()}_$cleanName")
        return candidate
    }

    private fun sanitizeFileName(name: String): String {
        return name.replace(Regex("""[\\/:*?"<>|]"""), "_").trim()
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && !cursor.isNull(index)) {
                    return cursor.getString(index)
                }
            }
        }
        return null
    }

    private fun queryLastModified(uri: Uri): Long {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex("last_modified")
                if (index >= 0 && !cursor.isNull(index)) {
                    return cursor.getLong(index)
                }
            }
        }
        return 0L
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallSettings() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val intent = Intent(
                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
