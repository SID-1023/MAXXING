
package com.example.maxxing

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "MAXXING_BLOCKER"
        private const val PREFS_NAME = "FlutterSharedPreferences"

        private val SELECTED_APPS_KEYS = arrayOf(
            "flutter.maxxing_selected_apps",
            "maxxing_selected_apps"
        )

        private val RULES_ENABLED_KEYS = arrayOf(
            "flutter.maxxing_blocker_enabled",
            "maxxing_blocker_enabled"
        )
    }

    private var lastBlockedPackage: String? = null
    private var lastBlockedTime = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "SERVICE_CONNECTED")
        logPreferences()
    }

    private fun logPreferences() {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        Log.d(TAG, "Preference keys: ${prefs.all.keys}")

        for (key in SELECTED_APPS_KEYS) {
            Log.d(TAG, "Selected[$key]: ${prefs.all[key]}")
        }

        for (key in RULES_ENABLED_KEYS) {
            Log.d(TAG, "Enabled[$key]: ${prefs.all[key]}")
        }
    }

    private fun parseStringList(raw: String): List<String> {
        val trimmed = raw.trim()
        val jsonStart = trimmed.indexOf('[')
        if (jsonStart < 0) {
            return emptyList()
        }

        val json = trimmed.substring(jsonStart)
        if (!json.startsWith("[")) {
            return emptyList()
        }

        val array = JSONArray(json)
        return buildList {
            for (i in 0 until array.length()) {
                val item = array.optString(i).trim()
                if (item.isNotEmpty()) add(item)
            }
        }
    }

    private fun readSelectedApps(): Set<String> {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val selected = linkedSetOf<String>()

        for (key in SELECTED_APPS_KEYS) {
            if (!prefs.contains(key)) {
                Log.d(TAG, "SELECTED_KEY_MISSING: $key")
                continue
            }

            val raw = prefs.all[key]
            Log.d(TAG, "SELECTED_KEY_FOUND: key=$key, type=${raw?.javaClass?.name}, value=$raw")

            try {
                when (raw) {
                    is Set<*> -> selected.addAll(raw.filterIsInstance<String>())
                    is List<*> -> selected.addAll(raw.filterIsInstance<String>())
                    is String -> {
                        val value = raw.trim()
                        val parsed = when {
                            value.startsWith("[") -> parseStringList(value)
                            value.startsWith("StringList") -> parseStringList(
                                value.removePrefix("StringList").trim()
                            )
                            value.contains("[") -> parseStringList(value)
                            else -> emptyList()
                        }

                        selected.addAll(parsed)
                    }
                    else -> Log.w(TAG, "UNSUPPORTED_SELECTED_TYPE: key=$key")
                }
            } catch (e: Exception) {
                Log.e(TAG, "SELECTED_PARSE_ERROR: key=$key", e)
            }
        }

        Log.d(TAG, "SELECTED_APPS_FINAL: $selected")
        return selected
    }

    private fun isBlockingEnabled(): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        for (key in RULES_ENABLED_KEYS) {
            when (val value = prefs.all[key]) {
                is Boolean -> if (value) return true
                is String -> if (value.equals("true", ignoreCase = true)) return true
            }
        }

        return false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null ||
            event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        ) return

        val foregroundPackage = event.packageName?.toString() ?: return
        if (foregroundPackage == packageName) return

        if (!isBlockingEnabled()) {
            Log.d(TAG, "Protection OFF; foreground=$foregroundPackage")
            return
        }

        val selectedApps = readSelectedApps()
        Log.d(TAG, "Foreground=$foregroundPackage, selected=$selectedApps")

        if (foregroundPackage !in selectedApps) return

        val now = System.currentTimeMillis()
        if (foregroundPackage == lastBlockedPackage &&
            now - lastBlockedTime < 1500L
        ) return

        lastBlockedPackage = foregroundPackage
        lastBlockedTime = now

        val appName = try {
            val info = packageManager.getApplicationInfo(foregroundPackage, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            foregroundPackage
        }

        Log.d(TAG, "BLOCK_MATCH: $foregroundPackage")

        performGlobalAction(GLOBAL_ACTION_HOME)

        try {
            val intent = Intent(this, BlockedActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
                )
                putExtra("blocked_app_name", appName)
                putExtra("blocked_package", foregroundPackage)
            }

            startActivity(intent)
            Log.d(TAG, "BLOCK_SCREEN_LAUNCH_REQUESTED")
        } catch (e: Exception) {
            Log.e(TAG, "BLOCK_SCREEN_LAUNCH_FAILED", e)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "SERVICE_INTERRUPTED")
    }
}
