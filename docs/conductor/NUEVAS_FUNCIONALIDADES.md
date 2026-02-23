# Nuevas Funcionalidades para Conductores - Viax

## 📋 Resumen de Cambios

Se han agregado funcionalidades completas para el módulo de conductores, incluyendo registro de vehículos, verificación de documentos, alertas inteligentes y gestión de perfil.

## 🚀 Nuevas Características Implementadas

### 1. **Modelos de Datos Completos**

#### `VehicleModel` (`vehicle_model.dart`)
- Información completa del vehículo (marca, modelo, año, color, placa)
- Tipos de vehículo: Motocicleta, Carro, Furgoneta, Camión
- Documentos del vehículo: SOAT, Tecnomecánica, Tarjeta de Propiedad
- Validaciones de completitud de datos
- Gestión de fotos de documentos

#### `DriverLicenseModel` (`driver_license_model.dart`)
- Información de licencia de conducción
- Categorías de licencia colombianas (A1, A2, B1, B2, B3, C1, C2, C3)
- Validación de vigencia y alertas de vencimiento
- Gestión de fotos de licencia (frente y reverso)

#### `ConductorProfileModel` (`conductor_profile_model.dart`)
- Perfil completo del conductor
- Estados de verificación: Pendiente, En Revisión, Aprobado, Rechazado
- Porcentaje de completitud del perfil
- Lista de tareas pendientes
- Documentos pendientes y rechazados

### 2. **Servicios (Backend Integration)**

#### `ConductorProfileService` (`conductor_profile_service.dart`)
- `getProfile()` - Obtener perfil completo del conductor
- `updateLicense()` - Actualizar información de licencia
- `updateVehicle()` - Actualizar información del vehículo
- `uploadDocument()` - Subir fotos de documentos
- `submitForVerification()` - Enviar perfil para verificación
- `getVerificationStatus()` - Obtener estado de verificación
- `hasCompleteProfile()` - Verificar si el perfil está completo

### 3. **Gestión de Estado**

#### `ConductorProfileProvider` (`conductor_profile_provider.dart`)
- Gestión de estado del perfil del conductor
- Carga y actualización de datos
- Manejo de errores y mensajes
- Progreso de carga de documentos
- Sincronización con backend

### 4. **Pantallas Principales**

#### **Registro de Vehículo** (`vehicle_registration_screen.dart`)
Formulario multi-paso con 3 etapas:

**Paso 1: Licencia de Conducción**
- Número de licencia
- Categoría de licencia (dropdown con todas las categorías colombianas)
- Fecha de expedición
- Fecha de vencimiento
- Validación de datos

**Paso 2: Información del Vehículo**
- Tipo de vehículo (selector visual con emojis)
- Placa del vehículo
- Marca y modelo
- Año y color
- Validaciones en tiempo real

**Paso 3: Documentos del Vehículo**
- Número y vencimiento de SOAT
- Número y vencimiento de Tecnomecánica
- Número de tarjeta de propiedad
- Selector de fechas interactivo

Características:
- Indicador de progreso visual
- Navegación entre pasos
- Validación en cada paso
- Diseño consistente con el tema de la app
- Guardado automático al finalizar

#### **Estado de Verificación** (`verification_status_screen.dart`)
Pantalla detallada que muestra:

- **Estado actual de verificación** con código de colores:
  - 🟡 Pendiente
  - 🔵 En Revisión
  - 🟢 Aprobado
  - 🔴 Rechazado

- **Progreso del perfil**:
  - Porcentaje de completitud
  - Barra de progreso visual
  - Lista de tareas pendientes

- **Documentos pendientes**:
  - Lista de documentos faltantes
  - Indicadores visuales por tipo

- **Documentos rechazados**:
  - Lista de documentos con problemas
  - Motivo de rechazo

- **Información completa**:
  - Datos de licencia con validación de vigencia
  - Datos del vehículo registrado
  - Botón para completar perfil

- Pull-to-refresh para actualizar datos

### 5. **Sistema de Alertas Inteligentes**

#### `ProfileIncompleteAlert`
Modal que aparece cuando el conductor intenta activar disponibilidad sin completar su perfil.

Características:
- Icono de advertencia animado
- Lista de items faltantes
- Botones "Después" y "Completar Ahora"
- Diseño con glassmorphism effect
- No intrusivo pero informativo

#### `DocumentExpiryAlert`
Modal para documentos próximos a vencer o vencidos.

Características:
- 3 estados: Normal (30 días), Urgente (7 días), Vencido
- Código de colores automático (amarillo, naranja, rojo)
- Cálculo automático de días restantes
- Navegación directa a renovación
- Modal bloqueante si el documento está vencido

#### `ConfirmationAlert`
Modal genérico reutilizable para confirmaciones.

Características:
- Personalizable (título, mensaje, botones, colores, icono)
- Consistente con el diseño de la app
- Fácil de usar: `ConfirmationAlert.show(context, ...)`

### 6. **Mejoras en ConductorHomeScreen**

#### **Nueva Sección: Estado del Perfil**
Card interactivo que muestra:
- Estado de verificación actual
- Porcentaje de completitud
- Tareas pendientes (contador)
- Barra de progreso si está en revisión
- Navegación a pantalla de verificación al tocar

#### **Tab de Perfil Mejorado**
Ahora incluye:
- **Header del perfil**:
  - Avatar circular con borde dorado
  - Nombre completo
  - Calificación promedio
  - Total de viajes

- **Acciones rápidas**:
  - Estado de Verificación → VerificationStatusScreen
  - Mi Vehículo → VehicleRegistrationScreen
  - Historial de Viajes (preparado para implementar)
  - Ganancias (preparado para implementar)
  - Configuración (preparado para implementar)
  - Cerrar Sesión (con confirmación)

#### **Verificación Automática al Iniciar**
- Carga automática del perfil del conductor
- Verificación de completitud
- Muestra alerta si el perfil está incompleto
- Verifica documentos próximos a vencer
- Alerta automática para licencias por vencer

### 7. **Integración con Provider**

Se integró `ConductorProfileProvider` en toda la app para:
- Mantener sincronizado el estado del perfil
- Actualizar datos en tiempo real
- Manejar errores de forma centralizada
- Optimizar llamadas al backend

## 🎨 Características de Diseño

### Consistencia Visual
- Todos los componentes siguen el diseño dark con acentos amarillos
- Glassmorphism effect en todos los cards
- Animaciones suaves y transiciones fluidas
- Iconografía consistente

### UX/UI Mejorada
- Feedback visual inmediato
- Mensajes de error claros
- Loading states en todas las operaciones
- Pull-to-refresh donde aplica
- Validaciones en tiempo real
- Indicadores de progreso claros

### Responsive
- Diseño adaptable a diferentes tamaños de pantalla
- Campos de texto con tamaño apropiado
- Cards que se ajustan al contenido
- Navegación intuitiva

## 🔧 Estructura del Código

```
lib/src/features/conductor/
├── models/
│   ├── conductor_model.dart (existente)
│   ├── conductor_profile_model.dart (nuevo)
│   ├── driver_license_model.dart (nuevo)
│   └── vehicle_model.dart (nuevo)
├── services/
│   ├── conductor_service.dart (existente)
│   └── conductor_profile_service.dart (nuevo)
├── providers/
│   ├── conductor_provider.dart (existente, actualizado)
│   └── conductor_profile_provider.dart (nuevo)
└── presentation/
    ├── screens/
    │   ├── conductor_home_screen.dart (actualizado)
    │   ├── verification_status_screen.dart (nuevo)
    │   └── vehicle_registration_screen.dart (nuevo)
    └── widgets/
        ├── conductor_alerts.dart (nuevo)
        ├── viaje_activo_card.dart (existente)
        └── conductor_stats_card.dart (existente)
```

## 📝 Endpoints del Backend Requeridos

Para que todo funcione correctamente, necesitas implementar estos endpoints en el backend:

### 1. GET `/conductor/get_profile.php`
```php
// Parámetros: conductor_id
// Retorna: perfil completo con licencia, vehículo y estado de verificación
```

### 2. POST `/conductor/update_license.php`
```php
// Body: conductor_id, licencia_conduccion, licencia_expedicion, 
//       licencia_vencimiento, licencia_categoria
// Retorna: success, message
```

### 3. POST `/conductor/update_vehicle.php`
```php
// Body: conductor_id, vehiculo_placa, vehiculo_tipo, vehiculo_marca,
//       vehiculo_modelo, vehiculo_anio, vehiculo_color, soat_numero,
//       soat_vencimiento, tecnomecanica_numero, tecnomecanica_vencimiento,
//       tarjeta_propiedad_numero
// Retorna: success, message
```

### 4. POST `/conductor/upload_document.php`
```php
// Multipart form: conductor_id, document_type, document (file)
// Retorna: success, message, file_url
```

### 5. POST `/conductor/submit_verification.php`
```php
// Body: conductor_id
// Retorna: success, message
```

### 6. GET `/conductor/get_verification_status.php`
```php
// Parámetros: conductor_id
// Retorna: estado_verificacion, aprobado, documentos_pendientes,
//          documentos_rechazados, motivo_rechazo
```

## 🔐 Validaciones Implementadas

### Licencia de Conducción
- ✅ Número de licencia requerido
- ✅ Categoría válida seleccionada
- ✅ Fecha de expedición válida
- ✅ Fecha de vencimiento futura
- ✅ Alerta si vence en menos de 30 días
- ✅ Bloqueo si está vencida

### Vehículo
- ✅ Placa requerida y formato válido
- ✅ Marca y modelo requeridos
- ✅ Año válido (1900 - año actual + 1)
- ✅ Color requerido
- ✅ Tipo de vehículo seleccionado

### Documentos
- ✅ Números de SOAT y tecnomecánica requeridos
- ✅ Fechas de vencimiento futuras
- ✅ Tarjeta de propiedad requerida
- ✅ Validación de fechas lógicas

## 🚦 Flujo de Usuario

1. **Inicio de sesión como conductor**
   - La app carga automáticamente el perfil
   - Si el perfil está incompleto, muestra alerta

2. **Completar perfil**
   - Usuario navega a "Completar Perfil"
   - Completa los 3 pasos del registro
   - Datos se guardan en el backend

3. **Verificación**
   - Usuario envía perfil para verificación
   - Estado cambia a "En Revisión"
   - Administrador revisa y aprueba/rechaza

4. **Operación**
   - Con perfil aprobado, puede activar disponibilidad
   - Recibe viajes normalmente
   - Sistema verifica vencimientos automáticamente

## 🎯 Mejoras Futuras Sugeridas

1. **Upload de Fotos**
   - Implementar image_picker
   - Crop y compresión de imágenes
   - Preview antes de subir
   - Progreso de upload

2. **Notificaciones**
   - Push notifications para:
     - Perfil aprobado/rechazado
     - Documentos por vencer
     - Nuevas solicitudes de viaje

3. **Historial**
   - Pantalla de historial de viajes
   - Filtros por fecha, estado, etc.
   - Exportar a PDF

4. **Ganancias**
   - Dashboard de ganancias
   - Gráficos por período
   - Detalles de transacciones

5. **Configuración**
   - Cambiar contraseña
   - Configurar notificaciones
   - Preferencias de viaje

## 💡 Notas de Implementación

- Todos los archivos siguen la estructura del proyecto existente
- Se mantiene consistencia con el theme y diseño actual
- Los providers están listos para integrarse con el árbol de widgets
- Las pantallas están preparadas para navegación por rutas nombradas
- El código incluye comentarios y documentación
- Manejo de errores robusto en todos los servicios

## 🔗 Dependencias Requeridas

Asegúrate de tener en `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  http: ^1.0.0
  shimmer: ^3.0.0
  # Para upload de fotos (futuro):
  # image_picker: ^1.0.0
  # image_cropper: ^5.0.0
```

## ✅ Testing Recomendado

1. Probar flujo completo de registro
2. Validar todas las alertas
3. Verificar navegación entre pantallas
4. Testear con perfil incompleto
5. Testear con documentos vencidos
6. Validar actualización de estado
7. Probar pull-to-refresh
8. Verificar manejo de errores del backend

---

**Desarrollado por:** GitHub Copilot  
**Fecha:** 24 de Octubre, 2025  
**Proyecto:** Viax - Plataforma de Transporte
