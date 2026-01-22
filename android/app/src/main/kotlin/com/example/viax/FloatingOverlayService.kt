package com.example.viax

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.GestureDetector
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.FrameLayout
import androidx.core.app.NotificationCompat
import kotlin.math.abs

/**
 * Servicio de overlay flotante para mostrar un botón fuera de la app
 * cuando hay un viaje en curso. Permite al usuario volver a la app
 * con un solo toque.
 */
class FloatingOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var gestureDetector: GestureDetector? = null
    
    // Posición inicial
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    
    // Para detectar si es un click o drag
    private var isDragging = false
    private var isLongPress = false
    
    // Constantes
    companion object {
        const val CHANNEL_ID = "viax_floating_overlay"
        const val NOTIFICATION_ID = 1001
        const val ACTION_SHOW = "com.example.viax.ACTION_SHOW_OVERLAY"
        const val ACTION_HIDE = "com.example.viax.ACTION_HIDE_OVERLAY"
        const val EXTRA_USER_ROLE = "user_role"
        const val EXTRA_SOLICITUD_ID = "solicitud_id"
        
        private const val CLICK_THRESHOLD = 10f // píxeles
        private const val LONG_PRESS_DURATION = 500L // ms
    }
    
    // Datos del viaje
    private var userRole: String = ""
    private var solicitudId: Int = 0

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                userRole = intent.getStringExtra(EXTRA_USER_ROLE) ?: ""
                solicitudId = intent.getIntExtra(EXTRA_SOLICITUD_ID, 0)
                showFloatingButton()
                startForeground(NOTIFICATION_ID, createNotification())
            }
            ACTION_HIDE -> {
                hideFloatingButton()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        hideFloatingButton()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Viaje en curso",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notificación para viaje activo"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_USER_ROLE, userRole)
            putExtra(EXTRA_SOLICITUD_ID, solicitudId)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Viaje en curso")
            .setContentText("Toca para volver a la app")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun showFloatingButton() {
        if (floatingView != null) return
        
        // Crear el view programáticamente para evitar dependencias de layout XML
        floatingView = createFloatingView()
        
        val layoutParams = WindowManager.LayoutParams().apply {
            width = dpToPx(60)
            height = dpToPx(60)
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.START
            x = dpToPx(16)
            y = dpToPx(100)
        }

        setupTouchListener(floatingView!!, layoutParams)
        windowManager?.addView(floatingView, layoutParams)
    }

    private fun createFloatingView(): View {
        // Crear un FrameLayout con fondo circular blanco
        val container = FrameLayout(this).apply {
            setBackgroundResource(R.drawable.floating_button_bg)
            elevation = dpToPx(8).toFloat()
        }
        
        // Agregar el logo de la app
        val imageView = ImageView(this).apply {
            setImageResource(R.mipmap.launcher_icon)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            val padding = dpToPx(10)
            setPadding(padding, padding, padding, padding)
        }
        
        container.addView(imageView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        
        return container
    }

    private fun setupTouchListener(view: View, layoutParams: WindowManager.LayoutParams) {
        var longPressRunnable: Runnable? = null
        
        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    isLongPress = false
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    
                    // Detectar long press para eliminar
                    longPressRunnable = Runnable {
                        isLongPress = true
                        // Mostrar visual feedback que se puede eliminar
                        showDeleteMode(v)
                    }
                    v.postDelayed(longPressRunnable, LONG_PRESS_DURATION)
                    true
                }
                
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    if (abs(deltaX) > CLICK_THRESHOLD || abs(deltaY) > CLICK_THRESHOLD) {
                        isDragging = true
                        longPressRunnable?.let { v.removeCallbacks(it) }
                    }
                    
                    if (isDragging || isLongPress) {
                        layoutParams.x = initialX + deltaX.toInt()
                        layoutParams.y = initialY + deltaY.toInt()
                        windowManager?.updateViewLayout(v, layoutParams)
                        
                        // Verificar si está en zona de eliminación (parte inferior)
                        val displayMetrics = DisplayMetrics()
                        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
                        val screenHeight = displayMetrics.heightPixels
                        
                        if (layoutParams.y > screenHeight - dpToPx(150)) {
                            v.alpha = 0.5f // Visual feedback de eliminación
                        } else {
                            v.alpha = 1.0f
                            if (isLongPress) {
                                hideDeleteMode(v)
                            }
                        }
                    }
                    true
                }
                
                MotionEvent.ACTION_UP -> {
                    longPressRunnable?.let { v.removeCallbacks(it) }
                    
                    // Verificar si está en zona de eliminación
                    val displayMetrics = DisplayMetrics()
                    windowManager?.defaultDisplay?.getMetrics(displayMetrics)
                    val screenHeight = displayMetrics.heightPixels
                    
                    if (isLongPress && layoutParams.y > screenHeight - dpToPx(150)) {
                        // Eliminar el overlay
                        hideFloatingButton()
                        sendBroadcastToFlutter("overlay_removed")
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf()
                        return@setOnTouchListener true
                    }
                    
                    // Restaurar alpha
                    v.alpha = 1.0f
                    hideDeleteMode(v)
                    
                    // Si no fue drag ni long press, es un click
                    if (!isDragging && !isLongPress) {
                        openApp()
                    } else {
                        // Snap to edge
                        snapToEdge(layoutParams, v)
                    }
                    true
                }
                
                else -> false
            }
        }
    }

    private fun showDeleteMode(view: View) {
        // Agregar efecto visual de que se puede eliminar
        view.animate()
            .scaleX(1.2f)
            .scaleY(1.2f)
            .setDuration(200)
            .start()
    }

    private fun hideDeleteMode(view: View) {
        view.animate()
            .scaleX(1.0f)
            .scaleY(1.0f)
            .setDuration(200)
            .start()
    }

    private fun snapToEdge(layoutParams: WindowManager.LayoutParams, view: View) {
        val displayMetrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
        val screenWidth = displayMetrics.widthPixels
        
        val targetX = if (layoutParams.x < screenWidth / 2) {
            dpToPx(8) // Snap a la izquierda
        } else {
            screenWidth - dpToPx(68) // Snap a la derecha
        }
        
        layoutParams.x = targetX
        windowManager?.updateViewLayout(view, layoutParams)
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("navigate_to_trip", true)
            putExtra(EXTRA_USER_ROLE, userRole)
            putExtra(EXTRA_SOLICITUD_ID, solicitudId)
        }
        startActivity(intent)
    }

    private fun sendBroadcastToFlutter(action: String) {
        val intent = Intent("com.example.viax.OVERLAY_ACTION").apply {
            putExtra("action", action)
        }
        sendBroadcast(intent)
    }

    private fun hideFloatingButton() {
        floatingView?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) {
                // View already removed
            }
            floatingView = null
        }
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
