package com.jianxi.reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.view.HapticFeedbackConstants
import android.window.BackEvent
import android.window.OnBackAnimationCallback
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val APK_CHANNEL = "com.jianxi.reader/apk_install"
    private val DOCUMENT_CHANNEL = "com.jianxi.reader/document_access"
    private val HAPTIC_CHANNEL = "com.jianxi.reader/haptics"
    private val PREDICTIVE_BACK_CHANNEL = "com.jianxi.reader/predictive_back"
    private val DOCUMENT_PICK_REQUEST = 21013
    private var pendingDocumentPickResult: MethodChannel.Result? = null
    private var predictiveBackCallback: OnBackInvokedCallback? = null
    private var predictiveBackChannel: MethodChannel? = null

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
                        result.error("INVALID_PATH", "安装包路径为空", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOCUMENT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDocument", "pickDocuments" -> pickDocument(result)
                "refreshDocument" -> {
                    val uri = call.argument<String>("uri")
                    val path = call.argument<String>("path")
                    if (uri.isNullOrEmpty() || path.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "文档地址和本地路径不能为空", null)
                    } else {
                        try {
                            result.success(copyUriToFile(Uri.parse(uri), File(path)))
                        } catch (error: Exception) {
                            result.error("REFRESH_FAILED", error.message, null)
                        }
                    }
                }
                "importExternalUri" -> {
                    val uriValue = call.argument<String>("uri")
                    if (uriValue.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "文档地址不能为空", null)
                    } else {
                        try {
                            result.success(importExternalUri(Uri.parse(uriValue)))
                        } catch (error: Exception) {
                            result.error("IMPORT_FAILED", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTIC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "selectionClick" -> {
                    performHaptic(HapticFeedbackConstants.CLOCK_TICK)
                    result.success(true)
                }
                "lightImpact" -> {
                    performHaptic(HapticFeedbackConstants.VIRTUAL_KEY)
                    result.success(true)
                }
                "mediumImpact" -> {
                    performHaptic(HapticFeedbackConstants.LONG_PRESS)
                    result.success(true)
                }
                "successFeedback" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                        performHaptic(HapticFeedbackConstants.CONFIRM)
                    } else {
                        performHaptic(HapticFeedbackConstants.LONG_PRESS)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        predictiveBackChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PREDICTIVE_BACK_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "setPredictiveBackEnabled") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                setPredictiveBackEnabled(call.argument<Boolean>("enabled") == true)
                result.success(true)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onDestroy() {
        setPredictiveBackEnabled(false)
        super.onDestroy()
    }

    private fun setPredictiveBackEnabled(enabled: Boolean) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return
        }
        val dispatcher = onBackInvokedDispatcher
        predictiveBackCallback?.let(dispatcher::unregisterOnBackInvokedCallback)
        predictiveBackCallback = null
        if (!enabled) {
            return
        }
        val callback = object : OnBackAnimationCallback {
            override fun onBackStarted(backEvent: BackEvent) {
                predictiveBackChannel?.invokeMethod("started", null)
            }

            override fun onBackProgressed(backEvent: BackEvent) {
                predictiveBackChannel?.invokeMethod("progressed", backEvent.progress.toDouble())
            }

            override fun onBackCancelled() {
                predictiveBackChannel?.invokeMethod("cancelled", null)
            }

            override fun onBackInvoked() {
                predictiveBackChannel?.invokeMethod("invoked", null)
            }
        }
        predictiveBackCallback = callback
        dispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            callback
        )
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

            val uris = documentUrisFromResult(data)
            if (uris.isEmpty()) {
                result.error("NO_URI", "Document picker did not return a uri", null)
                return
            }

            try {
                val documents = uris.map { uri ->
                    persistReadPermission(uri, data)
                    val name = documentNameForUri(uri)
                    val file = nextDocumentMirrorFile(name)
                    val metadata = copyUriToFile(uri, file).toMutableMap()
                    metadata["uri"] = uri.toString()
                    metadata
                }
                result.success(documents)
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
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
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
            ?: throw IOException("无法读取文档内容")
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

    private fun documentUrisFromResult(data: Intent?): List<Uri> {
        val uris = mutableListOf<Uri>()
        val clipData = data?.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index).uri?.let { uri ->
                    if (!uris.contains(uri)) {
                        uris.add(uri)
                    }
                }
            }
        }
        data?.data?.let { uri ->
            if (!uris.contains(uri)) {
                uris.add(uri)
            }
        }
        return uris
    }

    private fun importExternalUri(uri: Uri): Map<String, Any?> {
        val currentIntent = intent
        if (currentIntent?.data == uri) {
            persistReadPermission(uri, currentIntent)
        }

        val name = documentNameForUri(uri)
        val file = nextDocumentMirrorFile(name)
        val metadata = copyUriToFile(uri, file).toMutableMap()
        metadata["uri"] = uri.toString()
        return metadata
    }

    private fun documentNameForUri(uri: Uri): String {
        val displayName = queryDisplayName(uri)
        val fallbackName = when (uri.scheme) {
            "file" -> uri.path?.let { File(it).name }
            else -> uri.lastPathSegment
        }
        val rawName = sanitizeFileName(
            displayName ?: fallbackName ?: "document"
        ).ifEmpty { "document" }
        return ensureSupportedDocumentName(uri, rawName)
    }

    private fun ensureSupportedDocumentName(uri: Uri, rawName: String): String {
        val lowerName = rawName.lowercase()
        if (isSupportedDocumentName(lowerName)) return rawName

        val path = uri.path?.lowercase().orEmpty()
        val extension = when {
            path.endsWith(".md") -> ".md"
            path.endsWith(".markdown") -> ".markdown"
            path.endsWith(".html") -> ".html"
            path.endsWith(".htm") -> ".htm"
            else -> extensionForMimeType(contentResolver.getType(uri))
        }

        if (extension != null) return "$rawName$extension"
        throw IOException("仅支持 Markdown 和 HTML 文档: $uri")
    }

    private fun isSupportedDocumentName(name: String): Boolean {
        return name.endsWith(".md") ||
            name.endsWith(".markdown") ||
            name.endsWith(".html") ||
            name.endsWith(".htm")
    }

    private fun extensionForMimeType(mimeType: String?): String? {
        return when (mimeType?.lowercase()) {
            "text/markdown", "text/x-markdown" -> ".md"
            "text/html", "application/xhtml+xml" -> ".html"
            else -> null
        }
    }

    private fun nextDocumentMirrorFile(displayName: String): File {
        val directory = File(filesDir, "referenced_documents")
        val cleanName = sanitizeFileName(displayName).ifEmpty { "document" }
        var candidateDirectory = File(directory, "doc-${System.nanoTime()}")
        var index = 1
        while (candidateDirectory.exists()) {
            candidateDirectory = File(directory, "doc-${System.nanoTime()}-$index")
            index += 1
        }
        return File(candidateDirectory, cleanName)
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

    private fun performHaptic(constant: Int) {
        window.decorView.performHapticFeedback(
            constant,
            HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING
        )
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
