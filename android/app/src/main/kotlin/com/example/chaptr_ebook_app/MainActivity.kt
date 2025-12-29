package com.example.chaptr_ebook_app

import android.os.Bundle
import android.util.Base64
import android.util.Log
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // One-time helper: log the app's signing key hash so it can be added to
        // the Facebook Developer console if you see "Invalid Key Hash" errors.
        try {
            val pm = packageManager
            val packageName = packageName
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            val signatures = info.signatures
            if (signatures != null && signatures.isNotEmpty()) {
                for (signature in signatures) {
                    val md = java.security.MessageDigest.getInstance("SHA")
                    md.update(signature.toByteArray())
                    val keyHash = Base64.encodeToString(md.digest(), Base64.DEFAULT)
                    Log.d("KeyHash", keyHash.trim())
                }
            } else {
                Log.w("KeyHash", "No signatures found for package $packageName")
            }
        } catch (e: Exception) {
            Log.e("KeyHash", "Failed to compute key hash", e)
        }
    }
}
