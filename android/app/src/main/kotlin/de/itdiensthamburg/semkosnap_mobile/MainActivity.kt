package de.itdiensthamburg.semkosnap_mobile

import android.app.Activity
import android.net.Uri
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "semkosnap/document_scanner"
    private var pendingResult: MethodChannel.Result? = null

    private val scannerLauncher = registerForActivityResult(
        ActivityResultContracts.StartIntentSenderForResult()
    ) { activityResult ->
        val result = pendingResult ?: return@registerForActivityResult
        pendingResult = null

        if (activityResult.resultCode != Activity.RESULT_OK) {
            result.error("cancelled", "Der Dokumentenscan wurde abgebrochen.", null)
            return@registerForActivityResult
        }

        val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(activityResult.data)
        val page = scanResult?.pages?.firstOrNull()
        val imageUri = page?.imageUri

        if (imageUri == null) {
            result.error("scan_failed", "Der Scanner hat kein Bild zurückgegeben.", null)
            return@registerForActivityResult
        }

        try {
            val outputFile = copyUriToCache(imageUri)
            result.success(outputFile.absolutePath)
        } catch (exception: Exception) {
            result.error(
                "scan_failed",
                exception.message ?: "Der Scan konnte nicht gespeichert werden.",
                null,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScan" -> startScan(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startScan(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Der Scanner ist bereits geöffnet.", null)
            return
        }

        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(1)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()

        pendingResult = result

        GmsDocumentScanning.getClient(options)
            .getStartScanIntent(this)
            .addOnSuccessListener { intentSender ->
                scannerLauncher.launch(IntentSenderRequest.Builder(intentSender).build())
            }
            .addOnFailureListener { exception ->
                pendingResult = null
                result.error(
                    "unavailable",
                    exception.message ?: "Der Google-Dokumentenscanner ist nicht verfügbar.",
                    null,
                )
            }
    }

    private fun copyUriToCache(uri: Uri): File {
        val inputStream = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Der gescannte Beleg konnte nicht geöffnet werden.")
        val outputFile = File(cacheDir, "semkosnap_scan_${System.currentTimeMillis()}.jpg")

        inputStream.use { input ->
            FileOutputStream(outputFile).use { output ->
                input.copyTo(output)
            }
        }

        return outputFile
    }
}
