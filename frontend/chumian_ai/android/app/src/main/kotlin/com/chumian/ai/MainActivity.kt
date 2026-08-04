package com.chumian.ai

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "com.chumian.ai/signature"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSignature" -> {
                    try {
                        result.success(
                            mapOf(
                                "packageName" to packageName,
                                "md5" to getSignatureMd5()
                            )
                        )
                    } catch (e: Exception) {
                        result.success(
                            mapOf(
                                "packageName" to packageName,
                                "md5" to ""
                            )
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getSignatureMd5(): String {
        return try {
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                ).signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                ).signatures?.toList()
            }

            val signature = signatures?.firstOrNull()?.toByteArray()
                ?: return ""

            val digest = MessageDigest.getInstance("MD5").apply {
                update(signature)
            }.digest()

            digest.joinToString("") { "%02X".format(it) }
        } catch (e: Exception) {
            ""
        }
    }
}
