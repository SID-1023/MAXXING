
package com.example.maxxing

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BlockedActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val appName = intent.getStringExtra("blocked_app_name")
            ?: "This app"

        window.statusBarColor = Color.rgb(9, 9, 15)
        window.navigationBarColor = Color.rgb(9, 9, 15)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(32, 32, 32, 32)
            setBackgroundColor(Color.rgb(9, 9, 15))
        }

        val icon = TextView(this).apply {
            text = "✦"
            textSize = 56f
            gravity = Gravity.CENTER
            setTextColor(Color.rgb(182, 156, 255))
        }

        val title = TextView(this).apply {
            text = "Time to refocus"
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
        }

        val message = TextView(this).apply {
            text = "$appName is on your MAXXING block list.\n\n" +
                "Take a breath and return to what matters."
            textSize = 16f
            gravity = Gravity.CENTER
            setTextColor(Color.LTGRAY)
            setPadding(0, 20, 0, 32)
        }

        val homeButton = Button(this).apply {
            text = "Return to home screen"
            isAllCaps = false
            setTextColor(Color.rgb(9, 9, 15))
            setBackgroundColor(Color.rgb(182, 156, 255))
            setOnClickListener {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
                finish()
            }
        }

        root.addView(
            icon,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        root.addView(
            title,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        root.addView(
            message,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        root.addView(
            homeButton,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        setContentView(root)
    }

    @Deprecated("Deprecated in Android API 33")
    override fun onBackPressed() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }
}
