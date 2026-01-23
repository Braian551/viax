package com.example.viax

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.ImageView
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Servicio de overlay flotante para mostrar un botón fuera de la app
 * cuando hay un viaje en curso. Permite al usuario volver a la app
 * con un solo toque.
 * 
 * Características:
 * - Solo aparece cuando la app está en segundo plano
 * - Se puede arrastrar a cualquier posición
 * - Muestra un basurero al arrastrar para eliminar
 * - Se auto-oculta cuando la app vuelve al frente
 */
class FloatingOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var deleteZoneView: View? = null
    
    // Posición inicial del touch
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    
    // Estado
    private var isDragging = false
    private var isInDeleteZone = false
    
    // Constantes
    companion object {
        const val CHANNEL_ID = "viax_floating_overlay"
        const val NOTIFICATION_ID = 1001
        const val ACTION_SHOW = "com.example.viax.ACTION_SHOW_OVERLAY"
        const val ACTION_HIDE = "com.example.viax.ACTION_HIDE_OVERLAY"
        const val EXTRA_USER_ROLE = "user_role"
        const val EXTRA_SOLICITUD_ID = "solicitud_id"
        
        private const val CLICK_THRESHOLD = 15f // píxeles para detectar drag
        private const val DELETE_ZONE_HEIGHT = 120 // dp
        private const val BUTTON_SIZE = 56 // dp
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
                hideAll()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        hideAll()
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
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun showFloatingButton() {
        if (floatingView != null) return
        
        floatingView = createFloatingButtonView()
        
        val layoutParams = WindowManager.LayoutParams().apply {
            width = dpToPx(BUTTON_SIZE)
            height = dpToPx(BUTTON_SIZE)
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
            x = dpToPx(12)
            y = dpToPx(150)
        }

        setupTouchListener(floatingView!!, layoutParams)
        windowManager?.addView(floatingView, layoutParams)
        
        // Animación de entrada
        floatingView?.alpha = 0f
        floatingView?.scaleX = 0.5f
        floatingView?.scaleY = 0.5f
        floatingView?.animate()
            ?.alpha(1f)
            ?.scaleX(1f)
            ?.scaleY(1f)
            ?.setDuration(300)
            ?.setInterpolator(OvershootInterpolator())
            ?.start()
    }

    private fun createFloatingButtonView(): View {
        // Contenedor principal con sombra
        val container = FrameLayout(this).apply {
            elevation = dpToPx(6).toFloat()
        }
        
        // Fondo circular blanco
        val background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.WHITE)
            setStroke(dpToPx(1), Color.parseColor("#E0E0E0"))
        }
        container.background = background
        
        // Logo de la app
        val imageView = ImageView(this).apply {
            setImageResource(R.mipmap.launcher_icon)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            val padding = dpToPx(8)
            setPadding(padding, padding, padding, padding)
        }
        
        container.addView(imageView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        
        return container
    }

    private fun createDeleteZoneView(): View {
        val displayMetrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
        
        // Contenedor de la zona de eliminación
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            
            // Gradiente rojo de abajo hacia arriba
            val gradient = GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                intArrayOf(
                    Color.parseColor("#E53935"), // Rojo intenso abajo
                    Color.parseColor("#00E53935") // Transparente arriba
                )
            )
            background = gradient
        }
        
        // Ícono de basurero
        val trashIcon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_delete)
            setColorFilter(Color.WHITE)
            val size = dpToPx(40) // Un poco más grande
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                bottomMargin = dpToPx(16) // Más margen ya que no hay texto
            }
            tag = "trash_icon" // Tag para encontrarlo fácil
        }
        
        container.addView(trashIcon)
        // Eliminado: Texto "Soltar para eliminar"
        
        return container
    }

    private fun showDeleteZone() {
        if (deleteZoneView != null) return
        
        val displayMetrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
        
        deleteZoneView = createDeleteZoneView()
        
        val layoutParams = WindowManager.LayoutParams().apply {
            width = displayMetrics.widthPixels
            height = dpToPx(DELETE_ZONE_HEIGHT)
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.BOTTOM or Gravity.START
        }
        
        windowManager?.addView(deleteZoneView, layoutParams)
        
        // Animación de entrada desde abajo
        deleteZoneView?.translationY = dpToPx(DELETE_ZONE_HEIGHT).toFloat()
        deleteZoneView?.animate()
            ?.translationY(0f)
            ?.setDuration(200)
            ?.setInterpolator(AccelerateDecelerateInterpolator())
            ?.start()
    }

    private fun hideDeleteZone() {
        deleteZoneView?.let { view ->
            view.animate()
                .translationY(dpToPx(DELETE_ZONE_HEIGHT).toFloat())
                .setDuration(150)
                .withEndAction {
                    try {
                        windowManager?.removeView(view)
                    } catch (e: Exception) { }
                    deleteZoneView = null
                }
                .start()
        }
    }

    private fun setupTouchListener(view: View, originalLayoutParams: WindowManager.LayoutParams) {
        var layoutParams = originalLayoutParams
        
        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    // DETENER cualquier animación en curso (snap)
                    v.animate().cancel()
                    
                    // Actualizar referencia de layoutParams por si acaso
                    layoutParams = v.layoutParams as WindowManager.LayoutParams
                    
                    isDragging = false
                    isInDeleteZone = false
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    
                    // Pequeño efecto de presión
                    v.animate()
                        .scaleX(0.9f)
                        .scaleY(0.9f)
                        .setDuration(100)
                        .start()
                    true
                }
                
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    val distance = sqrt(deltaX * deltaX + deltaY * deltaY)
                    
                    if (distance > CLICK_THRESHOLD) {
                        if (!isDragging) {
                            isDragging = true
                            showDeleteZone()
                            v.animate().scaleX(1.1f).scaleY(1.1f).setDuration(100).start()
                        }
                        
                        layoutParams.x = initialX + deltaX.toInt()
                        layoutParams.y = initialY + deltaY.toInt()
                        windowManager?.updateViewLayout(v, layoutParams)
                        
                        // Verificar si está sobre la zona de eliminación
                        val displayMetrics = DisplayMetrics()
                        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
                        val screenHeight = displayMetrics.heightPixels
                        val deleteZoneTop = screenHeight - dpToPx(DELETE_ZONE_HEIGHT)
                        
                        val buttonCenterY = layoutParams.y + dpToPx(BUTTON_SIZE) / 2
                        val wasInDeleteZone = isInDeleteZone
                        isInDeleteZone = buttonCenterY > deleteZoneTop
                        
                        // Cambio visual cuando entra/sale de zona de eliminación
                        if (isInDeleteZone != wasInDeleteZone) {
                            // Buscar el ícono del basurero
                            val trashIcon = (deleteZoneView as? LinearLayout)?.findViewWithTag<View>("trash_icon")
                            
                            if (isInDeleteZone) {
                                // El botón se encoge y se vuelve rojo translúcido
                                v.animate()
                                    .scaleX(0.6f)
                                    .scaleY(0.6f)
                                    .alpha(0.5f)
                                    .setDuration(200)
                                    .start()
                                    
                                // El basurero crece
                                trashIcon?.animate()
                                    ?.scaleX(1.5f)
                                    ?.scaleY(1.5f)
                                    ?.setDuration(200)
                                    ?.start()
                            } else {
                                // Restaurar botón
                                v.animate()
                                    .scaleX(1.1f)
                                    .scaleY(1.1f)
                                    .alpha(1f)
                                    .setDuration(200)
                                    .start()
                                    
                                // Restaurar basurero
                                trashIcon?.animate()
                                    ?.scaleX(1.0f)
                                    ?.scaleY(1.0f)
                                    ?.setDuration(200)
                                    ?.start()
                            }
                        }
                    }
                    true
                }
                
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    hideDeleteZone()
                    
                    if (isInDeleteZone) {
                        // Animación de eliminación
                        v.animate()
                            .scaleX(0f)
                            .scaleY(0f)
                            .alpha(0f)
                            .setDuration(200)
                            .withEndAction {
                                hideAll()
                                sendBroadcastToFlutter("overlay_removed")
                                stopForeground(STOP_FOREGROUND_REMOVE)
                                stopSelf()
                            }
                            .start()
                        return@setOnTouchListener true
                    }
                    
                    // Restaurar escala normal
                    v.animate()
                        .scaleX(1f)
                        .scaleY(1f)
                        .alpha(1f)
                        .setDuration(150)
                        .start()
                    
                    if (!isDragging) {
                        // Fue un click - abrir la app
                        openApp()
                    } else {
                        // Snap a los bordes
                        snapToEdge(layoutParams, v)
                    }
                    true
                }
                
                else -> false
            }
        }
    }

    private fun snapToEdge(layoutParams: WindowManager.LayoutParams, view: View) {
        val displayMetrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
        // Snap horizontal al borde más cercano
        val buttonCenter = layoutParams.x + dpToPx(BUTTON_SIZE) / 2
        val targetX = if (buttonCenter < screenWidth / 2) {
            dpToPx(12) // Izquierda
        } else {
            screenWidth - dpToPx(BUTTON_SIZE + 12) // Derecha
        }
        
        // Mantener dentro de límites verticales
        val margin = dpToPx(50)
        val targetY = layoutParams.y.coerceIn(margin, screenHeight - dpToPx(BUTTON_SIZE) - margin)
        
        // Animar hacia la posición final
        val startX = layoutParams.x
        val startY = layoutParams.y
        
        view.animate()
            .setDuration(300) // Un poco más lento para que sea visible
            .setInterpolator(OvershootInterpolator(0.8f)) // Efecto rebote suave
            .setUpdateListener { animator ->
                val fraction = animator.animatedFraction
                layoutParams.x = (startX + (targetX - startX) * fraction).toInt()
                layoutParams.y = (startY + (targetY - startY) * fraction).toInt()
                try {
                    windowManager?.updateViewLayout(view, layoutParams)
                } catch (e: Exception) { }
            }
            .start()
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
        
        // Ocultar el overlay cuando se abre la app
        hideAll()
    }

    private fun sendBroadcastToFlutter(action: String) {
        val intent = Intent("com.example.viax.OVERLAY_ACTION").apply {
            putExtra("action", action)
        }
        sendBroadcast(intent)
    }

    private fun hideAll() {
        floatingView?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) { }
            floatingView = null
        }
        deleteZoneView?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) { }
            deleteZoneView = null
        }
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
