package com.example.build_distribution_app

import android.os.Build
import android.os.Bundle
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "apk_install_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "canInstallApk") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val canInstall = applicationContext.packageManager.canRequestPackageInstalls()
                    result.success(canInstall)
                } else {
                    result.success(true) // до Android 8.0
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
