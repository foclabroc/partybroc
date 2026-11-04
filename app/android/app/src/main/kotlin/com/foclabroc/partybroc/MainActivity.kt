package com.foclabroc.partybroc

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // La TV (et le téléphone du joueur) ne doit pas se mettre en veille pendant une partie
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    // Mise à jour automatique : infos de l'appli et lancement de l'installateur Android
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "partybroc/update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "info" -> {
                        @Suppress("DEPRECATION")
                        val pi = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val code = if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else pi.versionCode.toLong()
                        result.success(mapOf(
                            "versionCode" to code,
                            "versionName" to (pi.versionName ?: ""),
                            "cacheDir" to cacheDir.absolutePath,
                            "canInstall" to (Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls()),
                        ))
                    }
                    "openInstallSettings" -> {
                        // « Sources inconnues » pour PartyBroc TV (une seule fois)
                        val ok = tryStart(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                            || tryStart(Intent(Settings.ACTION_SECURITY_SETTINGS))
                        result.success(ok)
                    }
                    "install" -> {
                        val file = File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(this, "$packageName.update", file)
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        result.success(tryStart(intent))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("update", e.message, null)
            }
        }
        // Appli téléphone : inviter des joueurs (menu de partage) et ouvrir un lien (SMS, WhatsApp…)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "partybroc/share").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "share" -> {
                        val send = Intent(Intent.ACTION_SEND)
                            .setType("text/plain")
                            .putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("title") ?: "PartyBroc")
                            .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                        result.success(tryStart(Intent.createChooser(send, "Inviter des joueurs")))
                    }
                    "open" -> result.success(tryStart(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("share", e.message, null)
            }
        }
    }

    private fun tryStart(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: ActivityNotFoundException) {
        false
    }
}
