package com.example.viax

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity principal de Viax.
 * Maneja la comunicación con Flutter para el overlay flotante
 * cuando hay un viaje en curso.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val OVERLAY_CHANNEL = "com.example.viax/floating_overlay"
        private const val REQUEST_OVERLAY_PERMISSION = 1001
    }

    private var methodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    
    // Datos del viaje para navegar cuando se abre desde overlay
    private var navigateToTrip = false
    private var userRole: String? = null
    private var solicitudId: Int = 0

    // Receiver para acciones del overlay
    private val overlayReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra("action")
            when (action) {
                "overlay_removed" -> {
                    methodChannel?.invokeMethod("onOverlayRemoved", null)
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    result.success(canDrawOverlays())
                }
                
                "requestOverlayPermission" -> {
                    if (canDrawOverlays()) {
                        result.success(true)
                    } else {
                        pendingResult = result
                        requestOverlayPermission()
                    }
                }
                
                "showOverlay" -> {
                    val userRole = call.argument<String>("userRole") ?: ""
                    val solicitudId = call.argument<Int>("solicitudId") ?: 0
                    
                    if (canDrawOverlays()) {
                        showFloatingOverlay(userRole, solicitudId)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                
                "hideOverlay" -> {
                    hideFloatingOverlay()
                    result.success(true)
                }
                
                "isOverlayVisible" -> {
                    result.success(isOverlayServiceRunning())
                }
                
                else -> result.notImplemented()
            }
        }

        // Registrar receiver para acciones del overlay
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                overlayReceiver,
                IntentFilter("com.example.viax.OVERLAY_ACTION"),
                RECEIVER_NOT_EXPORTED
            )
        } else {
            registerReceiver(
                overlayReceiver,
                IntentFilter("com.example.viax.OVERLAY_ACTION")
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // Verificar si debe navegar al viaje
        intent?.let { handleIntent(it) }
    }

    private fun handleIntent(intent: Intent) {
        if (intent.getBooleanExtra("navigate_to_trip", false)) {
            navigateToTrip = true
            userRole = intent.getStringExtra(FloatingOverlayService.EXTRA_USER_ROLE)
            solicitudId = intent.getIntExtra(FloatingOverlayService.EXTRA_SOLICITUD_ID, 0)
            
            // Notificar a Flutter para navegar
            methodChannel?.invokeMethod("navigateToTrip", mapOf(
                "userRole" to userRole,
                "solicitudId" to solicitudId
            ))
            
            // Limpiar flags
            intent.removeExtra("navigate_to_trip")
            navigateToTrip = false
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_OVERLAY_PERMISSION) {
            pendingResult?.success(canDrawOverlays())
            pendingResult = null
        }
    }

    private fun showFloatingOverlay(userRole: String, solicitudId: Int) {
        val intent = Intent(this, FloatingOverlayService::class.java).apply {
            action = FloatingOverlayService.ACTION_SHOW
            putExtra(FloatingOverlayService.EXTRA_USER_ROLE, userRole)
            putExtra(FloatingOverlayService.EXTRA_SOLICITUD_ID, solicitudId)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun hideFloatingOverlay() {
        val intent = Intent(this, FloatingOverlayService::class.java).apply {
            action = FloatingOverlayService.ACTION_HIDE
        }
        startService(intent)
    }

    private fun isOverlayServiceRunning(): Boolean {
        // Simple check - en producción podría ser más robusto
        return false // El servicio maneja su propio estado
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(overlayReceiver)
        } catch (e: Exception) {
            // Receiver not registered
        }
    }
}
