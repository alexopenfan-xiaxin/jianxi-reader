package com.jianxi.reader

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.system.Os
import android.view.HapticFeedbackConstants
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
    private val DOCUMENT_PICK_REQUEST = 21013
    private val FOLDER_PICK_REQUEST = 21014
    private val MAX_READABLE_BYTES = 100L * 1024L * 1024L
    private var pendingDocumentPickResult: MethodChannel.Result? = null
    private var pendingFolderPickResult: MethodChannel.Result? = null

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
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("INSTALL_FAILED", "无法打开安装程序", error.message)
                        }
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
                "pickFolderDocuments" -> pickFolder(result)
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
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
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
        if (requestCode == FOLDER_PICK_REQUEST) {
            val result = pendingFolderPickResult
            pendingFolderPickResult = null
            if (result == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }
            val treeUri = data?.data
            if (treeUri == null) {
                result.error("NO_URI", "Folder picker did not return a uri", null)
                return
            }
            try {
                persistReadPermission(treeUri, data)
                result.success(importFolderDocuments(treeUri))
            } catch (error: Exception) {
                result.error("FOLDER_IMPORT_FAILED", error.message, null)
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

    private fun pickFolder(result: MethodChannel.Result) {
        if (pendingFolderPickResult != null) {
            result.error("PICK_IN_PROGRESS", "A folder picker request is already active", null)
            return
        }
        pendingFolderPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, FOLDER_PICK_REQUEST)
        } catch (error: Exception) {
            pendingFolderPickResult = null
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
        val fileExisted = file.exists()
        val declaredSize = querySize(uri)
        if (declaredSize > MAX_READABLE_BYTES) {
            throw IOException("文档超过 100 MB 限制")
        }
        val temporary = File(
            file.parentFile,
            ".${file.name}.${System.nanoTime()}.tmp"
        )
        var replaced = false
        try {
            val input = contentResolver.openInputStream(uri)
                ?: throw IOException("无法读取文档内容")
            input.use { source ->
                temporary.outputStream().use { destination ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    var copied = 0L
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        copied += count
                        if (copied > MAX_READABLE_BYTES) {
                            throw IOException("文档超过 100 MB 限制")
                        }
                        destination.write(buffer, 0, count)
                    }
                    destination.fd.sync()
                }
            }
            Os.rename(temporary.absolutePath, file.absolutePath)
            replaced = true
        } finally {
            temporary.delete()
            if (!replaced && !fileExisted) {
                file.parentFile?.delete()
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

    private fun importFolderDocuments(treeUri: Uri): Map<String, Any?> {
        val documents = mutableListOf<Map<String, Any?>>()
        var skipped = 0
        var failed = 0
        for (uri in documentUrisInTree(treeUri)) {
            try {
                val displayName = queryDisplayName(uri) ?: uri.lastPathSegment.orEmpty()
                val mimeType = contentResolver.getType(uri)
                if (!isSupportedDocumentName(displayName.lowercase()) &&
                    extensionForMimeType(mimeType) == null) {
                    skipped += 1
                    continue
                }
                val name = documentNameForUri(uri)
                val size = querySize(uri)
                if (size > MAX_READABLE_BYTES) {
                    skipped += 1
                    continue
                }
                val file = nextDocumentMirrorFile(name)
                val metadata = copyUriToFile(uri, file).toMutableMap()
                metadata["uri"] = uri.toString()
                documents.add(metadata)
            } catch (error: Exception) {
                failed += 1
            }
        }
        return mapOf(
            "documents" to documents,
            "skipped" to skipped,
            "failed" to failed
        )
    }

    private fun documentUrisInTree(treeUri: Uri): List<Uri> {
        val uris = mutableListOf<Uri>()
        fun walk(childrenUri: Uri) {
            contentResolver.query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_MIME_TYPE
                ),
                null,
                null,
                null
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val mimeIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
                if (idIndex < 0) return@use
                while (cursor.moveToNext()) {
                    val documentId = cursor.getString(idIndex)
                    val mimeType = if (mimeIndex >= 0 && !cursor.isNull(mimeIndex)) {
                        cursor.getString(mimeIndex)
                    } else {
                        null
                    }
                    if (DocumentsContract.Document.MIME_TYPE_DIR == mimeType) {
                        walk(DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, documentId))
                    } else {
                        uris.add(DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId))
                    }
                }
            }
        }
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        walk(DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, rootId))
        return uris
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

    private fun querySize(uri: Uri): Long {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (index >= 0 && !cursor.isNull(index)) {
                    return cursor.getLong(index)
                }
            }
        }
        return -1L
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
        if (!file.isFile) {
            throw IOException("安装包不存在或无法读取")
        }
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
