
package com.example.maxxing

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "maxxing/app_blocker"
    private val logTag = "MAXXING_BLOCKER"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "getLaunchableApps" -> {
                    try {
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                        }

                        val apps = if (
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                        ) {
                            packageManager.queryIntentActivities(
                                intent,
                                PackageManager.ResolveInfoFlags.of(0L)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.queryIntentActivities(intent, 0)
                        }

                        Log.d(
                            logTag,
                            "Launcher activities found: ${apps.size}"
                        )

                        val appList = apps
                            .mapNotNull { resolveInfo ->
                                val activityInfo = resolveInfo.activityInfo
                                    ?: return@mapNotNull null

                                val packageName = activityInfo.packageName

                                // Do not include MAXXING itself.
                                if (packageName == applicationContext.packageName) {
                                    return@mapNotNull null
                                }

                                val label = resolveInfo
                                    .loadLabel(packageManager)
                                    ?.toString()
                                    ?.trim()
                                    .orEmpty()

                                if (label.isBlank()) {
                                    return@mapNotNull null
                                }

                                mapOf(
                                    "name" to label,
                                    "packageName" to packageName
                                )
                            }
                            .distinctBy { it["packageName"] }
                            .sortedBy {
                                (it["name"] as String).lowercase()
                            }

                        Log.d(
                            logTag,
                            "Apps returned to Flutter: ${appList.size}"
                        )

                        result.success(appList)
                    } catch (e: Exception) {
                        Log.e(
                            logTag,
                            "Failed to load launchable apps",
                            e
                        )

                        result.error(
                            "APP_QUERY_FAILED",
                            "Could not load launchable apps.",
                            e.message
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
