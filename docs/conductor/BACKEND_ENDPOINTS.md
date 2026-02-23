# Backend Endpoints - Conductor Profile Module

## 📋 Endpoints Requeridos

### 1. GET /conductor/get_profile.php

**Descripción:** Obtiene el perfil completo del conductor incluyendo licencia, vehículo y estado de verificación.

**Parámetros:**
- `conductor_id` (required): ID del conductor

**Response Success:**
```json
{
  "success": true,
  "profile": {
    "licencia": {
      "licencia_conduccion": "12345678",
      "licencia_expedicion": "2020-01-15",
      "licencia_vencimiento": "2030-01-15",
      "licencia_categoria": "C1",
      "licencia_foto": "https://...",
      "licencia_foto_reverso": "https://...",
      "licencia_verificada": 1
    },
    "vehiculo": {
      "vehiculo_placa": "ABC123",
      "vehiculo_tipo": "carro",
      "vehiculo_marca": "Toyota",
      "vehiculo_modelo": "Corolla",
      "vehiculo_anio": 2020,
      "vehiculo_color": "Blanco",
      "aseguradora": "Seguros ABC",
      "numero_poliza_seguro": "POL123",
      "vencimiento_seguro": "2025-12-31",
      "soat_numero": "SOAT123",
      "soat_vencimiento": "2025-12-31",
      "tecnomecanica_numero": "TM123",
      "tecnomecanica_vencimiento": "2025-12-31",
      "tarjeta_propiedad_numero": "TP123",
      "foto_vehiculo": "https://...",
      "foto_tarjeta_propiedad": "https://...",
      "foto_soat": "https://...",
      "foto_tecnomecanica": "https://..."
    },
    "estado_verificacion": "pendiente",
    "fecha_ultima_verificacion": null,
    "documentos_pendientes": ["foto_licencia", "foto_vehiculo"],
    "documentos_rechazados": [],
    "motivo_rechazo": null,
    "aprobado": 0
  }
}
```

**Response Error:**
```json
{
  "success": false,
  "message": "Conductor no encontrado"
}
```

---

### 2. POST /conductor/update_license.php

**Descripción:** Actualiza o crea la información de licencia del conductor.

**Body (JSON):**
```json
{
  "conductor_id": 1,
  "licencia_conduccion": "12345678",
  "licencia_expedicion": "2020-01-15",
  "licencia_vencimiento": "2030-01-15",
  "licencia_categoria": "C1"
}
```

**Response Success:**
```json
{
  "success": true,
  "message": "Licencia actualizada correctamente"
}
```

**SQL Example:**
```sql
INSERT INTO detalles_conductor 
(usuario_id, licencia_conduccion, licencia_expedicion, licencia_vencimiento, licencia_categoria)
VALUES (?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
  licencia_conduccion = VALUES(licencia_conduccion),
  licencia_expedicion = VALUES(licencia_expedicion),
  licencia_vencimiento = VALUES(licencia_vencimiento),
  licencia_categoria = VALUES(licencia_categoria),
  actualizado_en = CURRENT_TIMESTAMP
```

---

### 3. POST /conductor/update_vehicle.php

**Descripción:** Actualiza o crea la información del vehículo del conductor.

**Body (JSON):**
```json
{
  "conductor_id": 1,
  "vehiculo_placa": "ABC123",
  "vehiculo_tipo": "carro",
  "vehiculo_marca": "Toyota",
  "vehiculo_modelo": "Corolla",
  "vehiculo_anio": 2020,
  "vehiculo_color": "Blanco",
  "aseguradora": "Seguros ABC",
  "numero_poliza_seguro": "POL123",
  "vencimiento_seguro": "2025-12-31",
  "soat_numero": "SOAT123",
  "soat_vencimiento": "2025-12-31",
  "tecnomecanica_numero": "TM123",
  "tecnomecanica_vencimiento": "2025-12-31",
  "tarjeta_propiedad_numero": "TP123"
}
```

**Response Success:**
```json
{
  "success": true,
  "message": "Vehículo actualizado correctamente"
}
```

**SQL Example:**
```sql
INSERT INTO detalles_conductor 
(usuario_id, vehiculo_placa, vehiculo_tipo, vehiculo_marca, vehiculo_modelo, 
 vehiculo_anio, vehiculo_color, aseguradora, numero_poliza_seguro, 
 vencimiento_seguro, soat_numero, soat_vencimiento, tecnomecanica_numero, 
 tecnomecanica_vencimiento, tarjeta_propiedad_numero)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE
  vehiculo_placa = VALUES(vehiculo_placa),
  vehiculo_tipo = VALUES(vehiculo_tipo),
  -- ... resto de campos
  actualizado_en = CURRENT_TIMESTAMP
```

---

### 4. POST /conductor/upload_document.php

**Descripción:** Sube una foto de documento del conductor.

**Content-Type:** `multipart/form-data`

**Form Data:**
- `conductor_id` (required): ID del conductor
- `document_type` (required): Tipo de documento 
  - Valores: `licencia_foto`, `licencia_foto_reverso`, `foto_vehiculo`, 
    `foto_tarjeta_propiedad`, `foto_soat`, `foto_tecnomecanica`
- `document` (required): Archivo de imagen

**Response Success:**
```json
{
  "success": true,
  "message": "Documento subido correctamente",
  "file_url": "https://Viax.com/uploads/conductores/1/licencia_foto.jpg"
}
```

**PHP Example:**
```php
<?php
// Validar conductor existe
// Validar tipo de documento
// Validar archivo (tamaño, tipo)

$allowedTypes = ['licencia_foto', 'licencia_foto_reverso', 'foto_vehiculo', 
                 'foto_tarjeta_propiedad', 'foto_soat', 'foto_tecnomecanica'];

if (!in_array($_POST['document_type'], $allowedTypes)) {
    echo json_encode(['success' => false, 'message' => 'Tipo de documento inválido']);
    exit;
}

$uploadDir = __DIR__ . '/uploads/conductores/' . $conductorId . '/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

$fileName = $documentType . '_' . time() . '.jpg';
$targetFile = $uploadDir . $fileName;

if (move_uploaded_file($_FILES['document']['tmp_name'], $targetFile)) {
    $fileUrl = 'https://Viax.com/uploads/conductores/' . $conductorId . '/' . $fileName;
    
    // Actualizar en base de datos
    $sql = "UPDATE detalles_conductor SET $documentType = ? WHERE usuario_id = ?";
    // Ejecutar query
    
    echo json_encode([
        'success' => true, 
        'message' => 'Documento subido correctamente',
        'file_url' => $fileUrl
    ]);
} else {
    echo json_encode(['success' => false, 'message' => 'Error al subir archivo']);
}
?>
```

---

### 5. POST /conductor/submit_verification.php

**Descripción:** Envía el perfil del conductor para verificación por parte del administrador.

**Body (JSON):**
```json
{
  "conductor_id": 1
}
```

**Response Success:**
```json
{
  "success": true,
  "message": "Perfil enviado para verificación"
}
```

**Validaciones:**
- Verificar que el conductor tenga licencia completa
- Verificar que el conductor tenga vehículo registrado
- Verificar que tenga todos los documentos requeridos
- Cambiar estado a "en_revision"

**SQL Example:**
```sql
-- Verificar completitud
SELECT 
  licencia_conduccion, vehiculo_placa, vehiculo_tipo,
  licencia_foto, foto_vehiculo, foto_soat, foto_tecnomecanica
FROM detalles_conductor
WHERE usuario_id = ?

-- Si está completo:
UPDATE detalles_conductor 
SET estado_verificacion = 'en_revision',
    fecha_ultima_verificacion = CURRENT_TIMESTAMP
WHERE usuario_id = ?
```

---

### 6. GET /conductor/get_verification_status.php

**Descripción:** Obtiene el estado actual de verificación del conductor.

**Parámetros:**
- `conductor_id` (required): ID del conductor

**Response Success:**
```json
{
  "success": true,
  "estado_verificacion": "en_revision",
  "aprobado": 0,
  "documentos_pendientes": ["foto_licencia_reverso"],
  "documentos_rechazados": ["foto_vehiculo"],
  "motivo_rechazo": "La foto del vehículo no es clara, por favor sube una nueva foto",
  "fecha_ultima_verificacion": "2025-10-24 10:30:00"
}
```

**SQL Example:**
```sql
SELECT 
  estado_verificacion,
  aprobado,
  fecha_ultima_verificacion,
  motivo_rechazo
FROM detalles_conductor
WHERE usuario_id = ?
```

---

### 7. POST /conductor/actualizar_disponibilidad.php (ACTUALIZAR)

**Descripción:** Actualiza el estado de disponibilidad del conductor.

**Agregar validación de perfil completo:**

```php
<?php
// ... código existente ...

// AGREGAR ANTES DE ACTUALIZAR DISPONIBILIDAD:
if ($disponible == 1) {
    // Verificar que el conductor tenga perfil completo y aprobado
    $sql = "SELECT aprobado, estado_verificacion FROM detalles_conductor WHERE usuario_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $conductorId);
    $stmt->execute();
    $result = $stmt->get_result();
    $conductor = $result->fetch_assoc();
    
    if (!$conductor || $conductor['aprobado'] != 1 || $conductor['estado_verificacion'] != 'aprobado') {
        echo json_encode([
            'success' => false,
            'message' => 'Debes completar tu perfil de conductor y obtener aprobación antes de activar la disponibilidad'
        ]);
        exit;
    }
}

// ... continuar con actualización de disponibilidad ...
?>
```

---

## 🗄️ Modificaciones a la Base de Datos

### Agregar columnas a `detalles_conductor`:

```sql
ALTER TABLE detalles_conductor
ADD COLUMN licencia_expedicion DATE AFTER licencia_vencimiento,
ADD COLUMN licencia_categoria VARCHAR(10) AFTER licencia_expedicion,
ADD COLUMN licencia_foto VARCHAR(500) AFTER licencia_categoria,
ADD COLUMN licencia_foto_reverso VARCHAR(500) AFTER licencia_foto,
ADD COLUMN licencia_verificada TINYINT(1) DEFAULT 0 AFTER licencia_foto_reverso,
ADD COLUMN soat_numero VARCHAR(100) AFTER vencimiento_seguro,
ADD COLUMN soat_vencimiento DATE AFTER soat_numero,
ADD COLUMN tecnomecanica_numero VARCHAR(100) AFTER soat_vencimiento,
ADD COLUMN tecnomecanica_vencimiento DATE AFTER tecnomecanica_numero,
ADD COLUMN tarjeta_propiedad_numero VARCHAR(100) AFTER tecnomecanica_vencimiento,
ADD COLUMN foto_vehiculo VARCHAR(500) AFTER tarjeta_propiedad_numero,
ADD COLUMN foto_tarjeta_propiedad VARCHAR(500) AFTER foto_vehiculo,
ADD COLUMN foto_soat VARCHAR(500) AFTER foto_tarjeta_propiedad,
ADD COLUMN foto_tecnomecanica VARCHAR(500) AFTER foto_soat,
ADD COLUMN documentos_pendientes JSON AFTER estado_verificacion,
ADD COLUMN documentos_rechazados JSON AFTER documentos_pendientes,
ADD COLUMN motivo_rechazo TEXT AFTER documentos_rechazados;
```

---

## 🔒 Seguridad

### Recomendaciones:

1. **Validar autenticación:**
   ```php
   // En cada endpoint
   session_start();
   if (!isset($_SESSION['usuario_id'])) {
       http_response_code(401);
       echo json_encode(['success' => false, 'message' => 'No autorizado']);
       exit;
   }
   ```

2. **Validar que el usuario es conductor:**
   ```php
   if ($_SESSION['tipo_usuario'] !== 'conductor') {
       http_response_code(403);
       echo json_encode(['success' => false, 'message' => 'Acceso denegado']);
       exit;
   }
   ```

3. **Validar permisos:**
   ```php
   // Verificar que el conductor solo acceda a sus propios datos
   if ($_POST['conductor_id'] != $_SESSION['usuario_id']) {
       http_response_code(403);
       echo json_encode(['success' => false, 'message' => 'Acceso denegado']);
       exit;
   }
   ```

4. **Sanitizar inputs:**
   ```php
   $conductorId = filter_var($_POST['conductor_id'], FILTER_SANITIZE_NUMBER_INT);
   $placa = filter_var($_POST['vehiculo_placa'], FILTER_SANITIZE_STRING);
   ```

5. **Validar uploads:**
   ```php
   $allowedMimeTypes = ['image/jpeg', 'image/png', 'image/jpg'];
   $maxFileSize = 5 * 1024 * 1024; // 5MB
   
   if (!in_array($_FILES['document']['type'], $allowedMimeTypes)) {
       echo json_encode(['success' => false, 'message' => 'Tipo de archivo no permitido']);
       exit;
   }
   
   if ($_FILES['document']['size'] > $maxFileSize) {
       echo json_encode(['success' => false, 'message' => 'Archivo muy grande']);
       exit;
   }
   ```

---

## 📝 Notas de Implementación

1. Todos los endpoints deben retornar JSON
2. Usar prepared statements para prevenir SQL injection
3. Implementar rate limiting para prevenir abuso
4. Logear todas las acciones importantes
5. Manejar errores de forma consistente
6. Usar transacciones para operaciones críticas

---

Para más información, consulta `NUEVAS_FUNCIONALIDADES.md` y `GUIA_RAPIDA.md`
