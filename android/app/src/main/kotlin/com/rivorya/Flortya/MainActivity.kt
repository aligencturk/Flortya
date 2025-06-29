package com.rivorya.flortya

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.zip.ZipInputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rivorya.flortya/share"
    private val TAG = "FloryaMainActivity"
    private var pendingIntent: Intent? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "=== ACTIVITY LIFECYCLE ===")
        Log.d(TAG, "onCreate called - App starting")
        Log.d(TAG, "Intent action: ${intent?.action}")
        Log.d(TAG, "Intent type: ${intent?.type}")
        Log.d(TAG, "Intent data: ${intent?.data}")
        Log.d(TAG, "Intent extras keys: ${intent?.extras?.keySet()}")
        Log.d(TAG, "Task ID: $taskId")
        Log.d(TAG, "Is finishing: $isFinishing")
        Log.d(TAG, "savedInstanceState: ${savedInstanceState != null}")
        Log.d(TAG, "=========================")
        
        // Gelen intent'i sakla
        if (intent?.action == Intent.ACTION_SEND || intent?.action == Intent.ACTION_SEND_MULTIPLE) {
            Log.d(TAG, "COLD START with share intent detected - saving as pending")
            pendingIntent = intent
        }
        
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedData" -> {
                        val sharedData = getSharedData()
                        result.success(sharedData)
                    }
                    "checkPendingIntent" -> {
                        val hasPendingIntent = pendingIntent != null
                        result.success(hasPendingIntent)
                    }
                    "processPendingIntent" -> {
                        pendingIntent?.let { intent ->
                            val tempIntent = this.intent
                            this.intent = intent
                            val sharedData = getSharedData()
                            this.intent = tempIntent
                            pendingIntent = null // İşlendikten sonra temizle
                            result.success(sharedData)
                        } ?: result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
    
    override fun onStart() {
        super.onStart()
        Log.d(TAG, "onStart called")
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause called")
    }
    
    override fun onStop() {
        super.onStop()
        Log.d(TAG, "onStop called")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy called - App ending")
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "onNewIntent called - Action: ${intent.action}")
        
        val oldIntent = this.intent
        setIntent(intent)
        
        // Eğer paylaşım intent'i ise hot handling yap
        if (intent.action == Intent.ACTION_SEND || intent.action == Intent.ACTION_SEND_MULTIPLE) {
            Log.d(TAG, "HOT INTENT detected - App was already running")
            
            // Uygulama arka planda açıkken yeni intent geldi
            val tempIntent = this.intent
            this.intent = intent
            val hotSharedData = getSharedData()
            this.intent = tempIntent // Restore original intent
            
            Log.d(TAG, "Hot shared data: $hotSharedData")
            
            // Flutter'a hot intent geldiğini bildir
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                Log.d(TAG, "Sending onHotIntent to Flutter")
                MethodChannel(messenger, CHANNEL).invokeMethod("onHotIntent", hotSharedData)
            } ?: run {
                Log.e(TAG, "Flutter engine not available for hot intent")
            }
        } else {
            Log.d(TAG, "Normal intent change - not a share intent")
            // Normal intent değişikliği
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onNewIntent", getSharedData())
            }
        }
    }
    
    private fun getSharedData(): Map<String, Any?> {
        val intent = intent
        val action = intent.action
        val type = intent.type
        
        return when {
            Intent.ACTION_SEND == action && type?.startsWith("text/") == true -> {
                if (intent.hasExtra(Intent.EXTRA_STREAM)) {
                    // Dosya paylaşımı
                    val fileUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    val fileContent = readFileFromUri(fileUri)
                    mapOf(
                        "type" to "file",
                        "content" to fileContent,
                        "uri" to fileUri?.toString()
                    )
                } else {
                    // Text paylaşımı
                    val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
                    mapOf(
                        "type" to "text",
                        "text" to sharedText,
                        "subject" to subject
                    )
                }
            }
            Intent.ACTION_SEND == action && (type == "application/zip" || type?.contains("zip") == true) -> {
                // ZIP dosya paylaşımı (WhatsApp sohbet dışa aktarımları)
                val fileUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                val fileContent = readZipFileContent(fileUri)
                mapOf(
                    "type" to "file",
                    "content" to fileContent,
                    "uri" to fileUri?.toString(),
                    "source" to "zip"
                )
            }
            Intent.ACTION_SEND == action && type?.contains("application/") == true -> {
                // Diğer uygulama dosyaları (ZIP olabilir)
                val fileUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                val fileContent = readFileOrZipContent(fileUri)
                mapOf(
                    "type" to "file",
                    "content" to fileContent,
                    "uri" to fileUri?.toString()
                )
            }
            Intent.ACTION_SEND_MULTIPLE == action && type?.startsWith("text/") == true -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                val contents = uris?.mapNotNull { uri -> readFileFromUri(uri) }
                mapOf(
                    "type" to "multiple_files",
                    "contents" to contents
                )
            }
            Intent.ACTION_SEND_MULTIPLE == action && (type?.contains("zip") == true || type?.contains("application/") == true) -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                val contents = uris?.mapNotNull { uri -> readFileOrZipContent(uri) }
                mapOf(
                    "type" to "multiple_files",
                    "contents" to contents
                )
            }
            else -> {
                mapOf("type" to "none")
            }
        }
    }
    
    private fun readFileFromUri(uri: Uri?): String? {
        if (uri == null) return null
        
        return try {
            val inputStream = contentResolver.openInputStream(uri)
            val reader = BufferedReader(InputStreamReader(inputStream))
            val content = reader.readText()
            reader.close()
            content
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    private fun readZipFileContent(uri: Uri?): String? {
        if (uri == null) return null
        
        return try {
            val inputStream = contentResolver.openInputStream(uri)
            val zipInputStream = ZipInputStream(inputStream)
            
            var zipEntry = zipInputStream.nextEntry
            while (zipEntry != null) {
                val fileName = zipEntry.name
                
                // .txt dosyası bul (WhatsApp sohbet dışa aktarımı)
                if (fileName.endsWith(".txt", ignoreCase = true)) {
                    val reader = BufferedReader(InputStreamReader(zipInputStream))
                    val content = StringBuilder()
                    var line: String?
                    
                    while (reader.readLine().also { line = it } != null) {
                        content.append(line).append("\n")
                    }
                    
                    zipInputStream.close()
                    return content.toString()
                }
                
                zipEntry = zipInputStream.nextEntry
            }
            
            zipInputStream.close()
            null // .txt dosyası bulunamadı
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    private fun readFileOrZipContent(uri: Uri?): String? {
        if (uri == null) return null
        
        return try {
            // Önce ZIP dosyası olarak okumayı dene
            val zipContent = readZipFileContent(uri)
            if (zipContent != null) {
                return zipContent
            }
            
            // ZIP değilse normal dosya olarak oku
            readFileFromUri(uri)
        } catch (e: Exception) {
            e.printStackTrace()
            // ZIP okuma başarısızsa normal dosya olarak dene
            readFileFromUri(uri)
        }
    }
}
