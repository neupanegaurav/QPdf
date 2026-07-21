package studio.gaurav.qpdf

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launchDocumentChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchDocumentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "studio.gaurav.qpdf/launch_document",
        ).also { channel -> channel.setMethodCallHandler { call, result ->
            if (call.method != "getInitialDocument") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                result.success(documentPayload(intent?.data))
            } catch (error: Exception) {
                result.error("open_failed", error.message, null)
            }
        } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = intent.data ?: return
        try {
            launchDocumentChannel?.invokeMethod("documentOpened", documentPayload(uri))
        } catch (_: Exception) {
            // Dart presents file-read errors for picker-based opens. An external
            // provider may revoke access before this callback; keep QPdf stable.
        }
    }

    private fun documentPayload(uri: Uri?): Map<String, Any>? {
        if (uri == null) return null
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        var name = uri.lastPathSegment ?: "Document.pdf"
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    name = cursor.getString(0) ?: name
                }
            }
        return mapOf("id" to uri.toString(), "name" to name, "bytes" to bytes)
    }
}
