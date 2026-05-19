package com.viax.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * MainActivity principal de Viax.
 * Maneja la comunicación con Flutter para el overlay flotante
 * cuando hay un viaje en curso.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val OVERLAY_CHANNEL = "com.viax.app/floating_overlay"
        private const val DEVICE_COUNTRY_CHANNEL = "com.viax.app/device_country"
        private const val REQUEST_OVERLAY_PERMISSION = 1001
    }

    private var methodChannel: MethodChannel? = null
    private var deviceCountryChannel: MethodChannel? = null
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

        deviceCountryChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_COUNTRY_CHANNEL
        )
        deviceCountryChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPreferredCountryIso" -> result.success(getPreferredCountryIso())
                else -> result.notImplemented()
            }
        }

        // Registrar receiver para acciones del overlay
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                overlayReceiver,
                IntentFilter("com.viax.app.OVERLAY_ACTION"),
                RECEIVER_NOT_EXPORTED
            )
        } else {
            registerReceiver(
                overlayReceiver,
                IntentFilter("com.viax.app.OVERLAY_ACTION")
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
        // Verificación simple; en producción podría endurecerse más.
        return false // El servicio maneja su propio estado
    }

    // Priorizar la red móvil evita caer en locales del sistema que no reflejan el país real.
    private fun getPreferredCountryIso(): String? {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val networkCountry = normalizeCountryIso(telephonyManager?.networkCountryIso)
        if (networkCountry != null) {
            return networkCountry
        }

        val simCountry = normalizeCountryIso(telephonyManager?.simCountryIso)
        if (simCountry != null) {
            return simCountry
        }

        return getLocaleCountryIso()
    }

    @Suppress("DEPRECATION")
    private fun getLocaleCountryIso(): String? {
        val configuration = resources.configuration
        val rawCountry = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !configuration.locales.isEmpty) {
            configuration.locales[0]?.country
        } else {
            configuration.locale?.country
        }

        return normalizeCountryIso(rawCountry)
    }

    private fun normalizeCountryIso(rawCountry: String?): String? {
        val country = rawCountry
            ?.trim()
            ?.uppercase(Locale.US)

        return if (country.isNullOrEmpty()) null else country
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(overlayReceiver)
        } catch (e: Exception) {
            // El receiver ya no estaba registrado.
        }
    }
}
