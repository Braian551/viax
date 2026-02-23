# Corrección de Errores: Registro de Vehículos

## Problema Identificado
Al guardar la información del vehículo y licencia, la aplicación mostraba errores del servidor. El problema era que faltaban los endpoints backend y columnas en la base de datos.

## Soluciones Implementadas

### 1. Base de Datos ✓
Se agregaron las siguientes columnas a la tabla `detalles_conductor`:

- `licencia_expedicion` - Fecha de expedición de la licencia
- `licencia_categoria` - Categoría de la licencia (A1, A2, B1, B2, C1, etc.)
- `soat_numero` - Número del SOAT
- `soat_vencimiento` - Fecha de vencimiento del SOAT
- `tecnomecanica_numero` - Número de la tecnomecánica
- `tecnomecanica_vencimiento` - Fecha de vencimiento de la tecnomecánica
- `tarjeta_propiedad_numero` - Número de la tarjeta de propiedad

**Archivo de migración:** `viax/backend/migrations/005_add_vehicle_registration_fields.sql`

**Script de ejecución:** `viax/backend/migrations/run_migration_005.php`

### 2. Endpoints Backend ✓

#### **update_license.php**
Endpoint para actualizar la información de la licencia de conducción.

**Ubicación:** `viax/backend/conductor/update_license.php`

**Campos que acepta:**
```json
{
  "conductor_id": 7,
  "licencia_conduccion": "123456789",
  "licencia_expedicion": "2023-01-15",
  "licencia_vencimiento": "2028-01-15",
  "licencia_categoria": "C1"
}
```

#### **update_vehicle.php**
Endpoint para actualizar la información del vehículo y sus documentos.

**Ubicación:** `viax/backend/conductor/update_vehicle.php`

**Campos que acepta:**
```json
{
  "conductor_id": 7,
  "vehiculo_tipo": "motocicleta",
  "vehiculo_marca": "Honda",
  "vehiculo_modelo": "CB300R",
  "vehiculo_anio": 2023,
  "vehiculo_color": "Rojo",
  "vehiculo_placa": "ABC123",
  "soat_numero": "SOAT123456",
  "soat_vencimiento": "2025-12-31",
  "tecnomecanica_numero": "TEC789012",
  "tecnomecanica_vencimiento": "2025-12-31",
  "tarjeta_propiedad_numero": "TP345678",
  "aseguradora": "Seguros Bolívar",
  "numero_poliza_seguro": "POL123456",
  "vencimiento_seguro": "2025-12-31"
}
```

### 3. Actualización de get_profile.php ✓
Se actualizó el endpoint `get_profile.php` para incluir todos los nuevos campos en la respuesta.

**Ubicación:** `viax/backend/conductor/get_profile.php`

Ahora retorna:
- Información completa de la licencia (número, expedición, vencimiento, categoría)
- Información completa del vehículo (placa, marca, modelo, año, color)
- Documentos del vehículo (SOAT, tecnomecánica, tarjeta de propiedad)

### 4. Scripts de Verificación ✓

#### **verify_structure.php**
Script para verificar que la base de datos tenga todas las columnas necesarias.

**Ubicación:** `viax/backend/migrations/verify_structure.php`

**Uso:**
```bash
cd viax/backend/migrations
php verify_structure.php
```

#### **test_vehicle_registration.php**
Script para probar los endpoints de registro de vehículos.

**Ubicación:** `viax/backend/conductor/test_vehicle_registration.php`

**Uso:**
```bash
cd viax/backend/conductor
php test_vehicle_registration.php
```

## Flujo de Registro Actualizado

### Paso 1: Licencia de Conducción
1. El usuario ingresa:
   - Número de licencia
   - Categoría (C1, C2, etc.)
   - Fecha de expedición
   - Fecha de vencimiento

2. Al hacer clic en "Siguiente", se envía la información a `update_license.php`

3. El backend guarda la información en la tabla `detalles_conductor`

### Paso 2: Información del Vehículo
1. El usuario ingresa:
   - Tipo de vehículo (motocicleta, carro, etc.)
   - Placa
   - Marca
   - Modelo
   - Año
   - Color

2. Al hacer clic en "Siguiente", la información se almacena temporalmente

### Paso 3: Documentos del Vehículo
1. El usuario ingresa:
   - Número y vencimiento del SOAT
   - Número y vencimiento de la tecnomecánica
   - Número de la tarjeta de propiedad

2. Al hacer clic en "Guardar", se envía toda la información del vehículo a `update_vehicle.php`

3. El backend guarda toda la información en la tabla `detalles_conductor`

## Verificación

Para verificar que todo funciona correctamente:

1. **Verificar la base de datos:**
   ```bash
   php viax/backend/migrations/verify_structure.php
   ```
   
   Debe mostrar: "✓ All required columns are present!"

2. **La aplicación Flutter ahora puede:**
   - Guardar la información de la licencia sin errores
   - Guardar la información del vehículo con todos sus documentos
   - Recuperar toda la información guardada

## Archivos Modificados

### Creados:
- `viax/backend/conductor/update_license.php`
- `viax/backend/conductor/update_vehicle.php`
- `viax/backend/migrations/005_add_vehicle_registration_fields.sql`
- `viax/backend/migrations/run_migration_005.php`
- `viax/backend/migrations/verify_structure.php`
- `viax/backend/conductor/test_vehicle_registration.php`

### Modificados:
- `viax/backend/conductor/get_profile.php`

## Estado Actual

✅ Base de datos actualizada con todas las columnas necesarias
✅ Endpoints backend creados y funcionando
✅ Endpoint de perfil actualizado para retornar nueva información
✅ Scripts de verificación disponibles

## Próximos Pasos (Opcional)

1. Agregar validaciones adicionales en el backend (formato de placa, fechas, etc.)
2. Implementar subida de fotos de documentos
3. Agregar verificación de documentos por un administrador
4. Notificaciones cuando los documentos estén próximos a vencer

## Notas Importantes

- Los endpoints requieren que el servidor PHP esté corriendo (XAMPP/WAMP)
- El `conductor_id` debe ser un ID válido de un usuario con tipo 'conductor'
- Todas las fechas deben estar en formato ISO (YYYY-MM-DD)
- La migración es segura y no afecta datos existentes
