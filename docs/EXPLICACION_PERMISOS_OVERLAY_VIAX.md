# Uso de Permisos de Overlay en App Viax

Este documento explica de forma clara y detallada con base técnica por qué la aplicación **Viax** requiere el uso de permisos especiales altamente sensibles de Android (`SYSTEM_ALERT_WINDOW` y `FOREGROUND_SERVICE_SPECIAL_USE`).

Esta documentación servirá como manifiesto para responder a las revisiones manuales de **Google Play Store Policy** y debe incluirse o adaptarse como nota para los revisores.

---

## 1. Contexto de Negocio y Funcionalidad

**Viax** es una aplicación de movilidad y transporte similar a Uber o DiDi, donde participan dos actores principales durante la ejecución de un viaje en tiempo real: el pasajero y el conductor.

Durante un viaje activo, es un comportamiento habitual y **absolutamente necesario** que el conductor deba salir de la aplicación Viax para abrir aplicaciones de navegación de terceros (como **Waze** o **Google Maps**) para seguir la ruta óptima hacia el destino.

### El problema:
Cuando el conductor sale de la app de Viax y entra a Waze/Google Maps, pierde temporalmente el acceso rápido al panel de control del viaje (botones para aceptar el viaje, finalizar el viaje, contactar soporte, ver la tarifa o recibir notificaciones urgentes).

### La solución implementada:
Viax ha integrado un **Floating Overlay Service** (Botón Flotante Sobre Otras Aplicaciones) que se dibuja sobre la pantalla (por ejemplo, flotando sobre Google Maps) *únicamente* durante un viaje activo. Esto permite al conductor volver inmediatamente a Viax o realizar acciones rápidas sin tener que usar el menú de recientes (multitarea) de Android, minimizando drásticamente la distracción visual al volante y previniendo accidentes.

---

## 2. Permiso: SYSTEM_ALERT_WINDOW (`Mostrar sobre otras aplicaciones`)

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

### ¿Por qué lo usamos?
Se requiere este permiso de nivel de sistema para poder instanciar y dibujar un `View` en pantalla fuera de los límites del `Activity` principal del Flutter. Este `View` contiene el widget flotante (ícono de la app de Viax) interactivo, esencial para la seguridad conductiva.

### Justificación para Google Play Store:
*   **Core Feature (Funcionalidad Principal):** La naturaleza principal de la aplicación es proveer servicios de transporte geolocalizado en tiempo real.
*   **Casos de uso válidos por políticas:** El uso de superposiciones para controles de navegación o transporte en tiempo real es una excepción de uso válida contemplada en las guías de desarrollador de Google.
*   **Seguridad del Usuario:** Limita la necesidad de interactuar profundamente con la UI del sistema mientras se conduce.

### Interacción y Transparencia con el Usuario:
1.  El permiso no se solicita arbitrariamente al inicio de la app.
2.  Solo se invita al usuario (Conductor) a otorgar este permiso desde la configuración nativa de "Mostrar sobre otras apps" la primera vez que inicia sesión como conductor, mostrando primero un cuadro de diálogo explicativo interno (In-App Disclosure) que dice claramente **para qué se usará y por qué**.

---

## 3. Permiso: FOREGROUND_SERVICE_SPECIAL_USE (`Servicio en Primer Plano - Uso Especial`)

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<!-- Declaración del servicio en AndroidManifest.xml -->
<service
    android:name=".FloatingOverlayService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="specialUse" />
```

### ¿Por qué lo usamos?
A partir de Android 14 (API 34), Google restringe fuertemente qué procesos pueden mantenerse vivos en segundo plano. Dado que el widget de la ventana de alerta (`SYSTEM_ALERT_WINDOW`) necesita dibujarse y responder a clics *incluso cuando la app de Flutter está minimizada*, es obligatorio correr esto dentro de un `Service`.

Para evitar que el sistema operativo "mate" el servicio casi inmediatamente por gestión de batería (OOM killer/Doze mode), este servicio se debe promover a **Foreground Service** mostrándole una notificación persistente e inamovible al usuario.

Dado que la acción de "dibujar una burbuja flotante de viaje" no encaja perfectamente en las categorías tradicionales (como `location` o `mediaPlayback`), la guía técnica de Android actual exige categorizar este caso bajo `specialUse`.

### Justificación para Google Play Store:
*   **Necesario para el Overlay:** Sirve exclusivamente como el proceso anfitrión u host para inyectar la vista que usa el permiso `SYSTEM_ALERT_WINDOW`.
*   **Visibilidad para el usuario:** Mientras este permiso/servicio se usa, hay una doble indicación visual para el usuario:
    1.  El widget/burbuja flotante de Viax en pantalla.
    2.  Una notificación permanente en la barra de estado de Android indicando que "Viax está activo en segundo plano".

---

## 4. Texto Propuesto para la Caja de Declaración de Play Console

Al momento de subir a producción y rellenar las declaraciones en Google Play Console para estos permisos, utilice este texto (o modifíquelo ligeramente):

> **Why the app needs the permission:**
> "Viax is a ride-hailing app. We use SYSTEM_ALERT_WINDOW and a Foreground Service with 'specialUse' type exclusively to display a floating widget overlay during active trips. This allows our drivers to safely navigate using third-party GPS apps (like Waze or Google Maps) while maintaining immediate, one-tap access to critical trip controls (like completing the ride or responding to chat messages) without navigating through Android's recent apps menu. This prevents driver distraction and improves road safety."

---

## 5. Recomendación Técnica Final

Como solicita la directiva original: **"👉 Si no es crítico → quítalo"**.

Al ser Viax una app de transporte similar a Uber, esta funcionalidad es **virtualmente crítica para los conductores** y proporciona una experiencia de usuario (UX) sumamente mejorada.

Sin embargo, si la primera versión MVP o el lanzamiento a la tienda enfrenta un rechazo inesperado por las políticas estrictas, la aplicación de Flutter debería estar diseñada funcionalmente para ignorar este flujo constructivamente si el permiso es negado o removido internamente temporalmente, usando las notificaciones push enriquecidas (con botones de acción de respuesta de Firebase Notification) como alternativa paliativa, de modo que sirva como plan B hasta destrabar las restricciones en futuras versiones.
