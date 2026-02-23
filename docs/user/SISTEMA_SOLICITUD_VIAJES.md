# Sistema de Solicitud de Viajes y Panel de Conductores

## 📋 Resumen de Cambios

Se ha implementado un sistema completo de solicitud de viajes con búsqueda de conductores en tiempo real y un panel para que los conductores vean y acepten solicitudes.

## 🎯 Funcionalidades Implementadas

### Para Usuarios
1. **Solicitar Viaje**: Los usuarios pueden solicitar un viaje desde `TripPreviewScreen`
2. **Búsqueda de Conductores**: Sistema automático que busca conductores cercanos disponibles
3. **Pantalla de Búsqueda**: Vista en tiempo real mientras se busca un conductor
4. **Cancelación**: Posibilidad de cancelar la búsqueda en cualquier momento

### Para Conductores
1. **Panel de Solicitudes**: Vista de todas las solicitudes de viaje pendientes cercanas
2. **Auto-refresh**: Actualización automática cada 5 segundos
3. **Información Detallada**: Ver origen, destino, distancia, duración y precio de cada viaje
4. **Aceptar Viajes**: Sistema para aceptar solicitudes y comenzar el servicio

## 📁 Archivos Creados

### Frontend (Flutter)
- `lib/src/global/config/api_config.dart` - Configuración de endpoints del API
- `lib/src/features/user/services/trip_request_service.dart` - Servicio para solicitudes de viaje
- `lib/src/features/user/presentation/screens/searching_driver_screen.dart` - Pantalla de búsqueda de conductor
- `lib/src/features/conductor/presentation/screens/conductor_requests_screen.dart` - Panel de solicitudes para conductores

### Backend (PHP)
- `viax/backend/user/create_trip_request.php` - Crear solicitud de viaje y buscar conductores
- `viax/backend/user/find_nearby_drivers.php` - Buscar conductores cercanos disponibles
- `viax/backend/conductor/get_pending_requests.php` - Obtener solicitudes pendientes para conductor
- `viax/backend/conductor/accept_trip_request.php` - Aceptar solicitud de viaje

## 🔧 Archivos Modificados

### Frontend
- `lib/src/features/user/presentation/screens/trip_preview_screen.dart`
  - Se ajustó la posición del cuadro de información del origen (offset: 65, -10)
  - Se implementó el método `_confirmTrip()` para crear solicitudes de viaje reales
  - Se agregaron imports para los nuevos servicios

## 🚀 Cómo Usar

### Para Usuarios

1. **Solicitar un Viaje**:
   ```dart
   // En RequestTripScreen, selecciona origen y destino
   // Navega a TripPreviewScreen
   // Presiona el botón "Solicitar viaje"
   ```

2. **Durante la Búsqueda**:
   - Se muestra la pantalla `SearchingDriverScreen`
   - El sistema busca conductores cada 3 segundos
   - Puedes cancelar en cualquier momento

### Para Conductores

1. **Ver Solicitudes Pendientes**:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => ConductorRequestsScreen(
         conductorId: tuConductorId,
       ),
     ),
   );
   ```

2. **Aceptar un Viaje**:
   - Las solicitudes se actualizan automáticamente
   - Presiona "Aceptar viaje" en la solicitud deseada
   - El sistema te asignará el viaje y actualizará tu disponibilidad

## 🔍 Lógica de Búsqueda de Conductores

### Criterios de Búsqueda
- **Radio**: 5 km desde el punto de origen
- **Estado**: Solo conductores con `disponibilidad = 1`
- **Verificación**: Solo conductores con `estado_verificacion = 'aprobado'`
- **Tipo de Vehículo**: Debe coincidir con el solicitado
- **Ubicación**: Conductores con coordenadas actuales válidas

### Cálculo de Distancia
Se usa la fórmula de Haversine para calcular la distancia entre el conductor y el punto de origen:

```sql
(6371 * acos(
    cos(radians(lat_origen)) * cos(radians(lat_conductor)) *
    cos(radians(lon_conductor) - radians(lon_origen)) +
    sin(radians(lat_origen)) * sin(radians(lat_conductor))
)) AS distancia_km
```

## 📊 Flujo de Datos

### Solicitud de Viaje
```
Usuario → TripPreviewScreen._confirmTrip()
    ↓
TripRequestService.createTripRequest()
    ↓
Backend: create_trip_request.php
    ↓
1. Crear registro en solicitudes_servicio
2. Buscar conductores cercanos
3. Retornar solicitud_id y lista de conductores
    ↓
SearchingDriverScreen (búsqueda en tiempo real)
```

### Panel de Conductor
```
ConductorRequestsScreen.initState()
    ↓
Auto-refresh cada 5 segundos
    ↓
Backend: get_pending_requests.php
    ↓
Buscar solicitudes pendientes cercanas al conductor
    ↓
Mostrar lista de solicitudes
    ↓
Conductor acepta viaje
    ↓
Backend: accept_trip_request.php
    ↓
1. Actualizar solicitud a 'aceptada'
2. Crear asignación
3. Cambiar disponibilidad del conductor a 0
```

## ⚙️ Configuración

### 1. Configurar URL del Backend
En `lib/src/global/config/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = 'http://tu-servidor:8000';
}
```

### 2. Iniciar el Servidor Backend
```bash
cd viax/backend
php -S localhost:8000
```

### 3. Sistema de Autenticación
Actualmente usa `userId: 1` temporal. Para integrar con tu sistema de auth:

```dart
// Reemplazar en trip_preview_screen.dart
final response = await TripRequestService.createTripRequest(
  userId: AuthService.currentUser.id, // Tu sistema de auth
  // ... resto de parámetros
);
```

## 🗄️ Estructura de Base de Datos

### Tabla: solicitudes_servicio
```sql
- id
- usuario_id
- latitud_origen, longitud_origen, direccion_origen
- latitud_destino, longitud_destino, direccion_destino
- tipo_servicio ('viaje' o 'paquete')
- tipo_vehiculo ('moto', 'carro', 'moto_carga', 'carro_carga')
- distancia_km
- duracion_minutos
- precio_estimado
- estado ('pendiente', 'aceptada', 'en_curso', 'completada', 'cancelada')
- fecha_solicitud
```

### Tabla: asignaciones_conductor
```sql
- id
- solicitud_id
- conductor_id
- fecha_asignacion
- estado ('asignado', 'aceptado', 'rechazado')
```

## 🐛 Solución de Problemas

### No se encuentran conductores
- Verificar que hay conductores con `disponibilidad = 1`
- Verificar que los conductores tienen `estado_verificacion = 'aprobado'`
- Verificar que los conductores tienen coordenadas actuales (`latitud_actual`, `longitud_actual`)
- Aumentar el radio de búsqueda si es necesario

### Error al crear solicitud
- Verificar que el backend está corriendo
- Verificar la URL en `api_config.dart`
- Revisar logs del servidor PHP
- Verificar que el usuario existe en la base de datos

### Conductor no ve solicitudes
- Verificar que `conductor_id` es correcto
- Verificar que el conductor está aprobado
- Verificar que hay solicitudes pendientes en los últimos 10 minutos
- Verificar que el tipo de vehículo coincide

## 📝 TODOs

- [ ] Integrar con sistema de autenticación real
- [ ] Implementar notificaciones push para conductores
- [ ] Agregar sistema de chat entre usuario y conductor
- [ ] Implementar seguimiento en tiempo real del viaje
- [ ] Agregar sistema de calificaciones después del viaje
- [ ] Implementar historial de viajes
- [ ] Agregar métodos de pago

## 🎨 Ajustes de UI Realizados

### Posición del Cuadro de Origen
- **Antes**: Tapaba el marcador del punto de origen
- **Después**: Posicionado al lado derecho con offset (65, -10)
- **Resultado**: El cuadro aparece al lado sin obstruir el marcador

### Cuadros Clickeables en Top Panel
- Los cuadros de origen y destino ahora son clickeables
- Al hacer click, regresan a `RequestTripScreen` para editar ubicaciones
- Incluye icono de edición para indicar interactividad

## 📞 Soporte

Si tienes problemas o preguntas sobre la implementación, revisa:
1. Los logs del servidor backend
2. Los logs de Flutter con `flutter run -v`
3. La consola del navegador para errores del API
