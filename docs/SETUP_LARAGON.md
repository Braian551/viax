# Guía de Configuración Local con Laragon

Esta guía te ayudará a configurar el proyecto Viax en tu entorno local usando **Laragon**.

---

## 📋 Requisitos Previos

- **Laragon** instalado (descarga desde [laragon.org](https://laragon.org/download/))
- **Git** instalado (opcional, para clonar el repositorio)
- Al menos **500 MB** de espacio libre en disco

---

## 🚀 Paso 1: Instalar y Configurar Laragon

### 1.1 Descargar Laragon
- Descarga **Laragon Full** desde [https://laragon.org/download/](https://laragon.org/download/)
- Ejecuta el instalador y sigue las instrucciones
- Laragon incluye: Apache, MySQL, PHP, Redis, Memcached

### 1.2 Iniciar Laragon
1. Abre **Laragon**
2. Click en **Start All** (esquina inferior izquierda)
3. Espera a que Apache y MySQL se inicien (íconos en verde)

### 1.3 Verificar Servicios
- **Apache**: debe estar corriendo en puerto 80
- **MySQL**: debe estar corriendo en puerto 3306
- **PHP**: verifica la versión (mínimo PHP 7.4, recomendado 8.0+)

---

## 📂 Paso 2: Configurar el Backend

### 2.1 Copiar el Backend a Laragon

1. Navega a la carpeta de tu proyecto Viax:
   ```
   c:\Flutter\ping_go
   ```

2. Copia la carpeta `backend-deploy` a la carpeta `www` de Laragon:
   ```
   Desde: c:\Flutter\ping_go\backend-deploy
   Hacia: C:\laragon\www\ping_go\backend-deploy
   ```

   Estructura final:
   ```
   C:\laragon\www\
   └── ping_go\
       └── backend-deploy\
           ├── admin\
           ├── auth\
           ├── conductor\
           ├── config\
           ├── user\
           └── ...
   ```

### 2.2 Verificar la URL

Abre tu navegador y accede a:
```
http://localhost/ping_go/backend-deploy/health.php
```

Deberías ver un mensaje de salud del sistema.

---

## 💾 Paso 3: Configurar la Base de Datos

### 3.1 Crear la Base de Datos

**Opción A: Usando HeidiSQL (incluido en Laragon)**

1. En Laragon, click derecho en **MySQL** → **Open**
2. Se abrirá **HeidiSQL**
3. Click derecho en la conexión → **Create new** → **Database**
4. Nombre: `Viax`
5. Charset: `utf8mb4_unicode_ci`
6. Click **OK**

**Opción B: Usando phpMyAdmin**

1. En Laragon, click en **Database** (botón superior)
2. Se abrirá phpMyAdmin
3. Click en **New** (Nueva base de datos)
4. Nombre: `Viax`
5. Cotejamiento: `utf8mb4_unicode_ci`
6. Click **Create**

### 3.2 Importar el SQL

1. En HeidiSQL o phpMyAdmin, selecciona la base de datos `Viax`
2. Click en **Import** o **Importar**
3. Selecciona el archivo:
   ```
   c:\Flutter\ping_go\basededatos (2).sql
   ```
4. Click **Execute** o **Continuar**
5. Espera a que la importación termine

### 3.3 Verificar las Tablas

La base de datos debe contener las siguientes tablas:
- `usuarios`
- `conductores`
- `viajes`
- `solicitudes_viaje`
- `calificaciones`
- `documentos_conductor`
- `configuracion_precios`
- `administradores`
- `audit_logs`

### 3.4 Configurar Credenciales en el Backend

El archivo `backend-deploy/config/database.php` ya está configurado para Laragon:

```php
public function __construct() {
    $this->host = 'localhost';
    $this->db_name = 'Viax';
    $this->username = 'root';
    $this->password = 'root';
}
```

> **Nota**: Si tu Laragon tiene una contraseña diferente para MySQL, actualiza el valor de `$this->password`.

---

## 🔧 Paso 4: Configurar Composer (Dependencias PHP)

El backend usa **PHPMailer** para envío de correos. Instala las dependencias:

### 4.1 Verificar que Composer esté instalado

En Laragon, abre la terminal:
1. Click derecho en Laragon → **Terminal**
2. Ejecuta:
   ```bash
   composer --version
   ```

Si Composer no está instalado:
1. Menu Laragon → **Tools** → **Quick add** → **Composer**

### 4.2 Instalar Dependencias

En la terminal de Laragon:
```bash
cd C:\laragon\www\ping_go\backend-deploy
composer install
```

Esto instalará todas las dependencias definidas en `composer.json`.

---

## 🎯 Paso 5: Configurar Flutter

### 5.1 Verificar Configuración

Los siguientes archivos ya están configurados para local:

**`lib/src/core/config/app_config.dart`**:
```dart
static const Environment environment = Environment.development;

static String get baseUrl {
  switch (environment) {
    case Environment.development:
      return 'http://localhost/ping_go/backend-deploy';
    // ...
  }
}
```

**`lib/src/global/config/api_config.dart`**:
```dart
static const String baseUrl = 'http://localhost/ping_go/backend-deploy';
```

### 5.2 Consideraciones para Diferentes Dispositivos

| Dispositivo | URL Backend |
|-------------|-------------|
| **Navegador** (Chrome/Edge) | `http://localhost/ping_go/backend-deploy` |
| **Emulador Android** | `http://10.0.2.2/ping_go/backend-deploy` |
| **Dispositivo Físico** | `http://TU_IP_LOCAL/ping_go/backend-deploy` |

#### Para Emulador Android:
Edita `lib/src/core/config/app_config.dart`:
```dart
case Environment.development:
  return 'http://10.0.2.2/ping_go/backend-deploy';
```

#### Para Dispositivo Físico:
1. Obtén tu IP local:
   ```powershell
   ipconfig
   ```
   Busca **IPv4** (ej: `192.168.1.100`)

2. Edita la URL:
   ```dart
   return 'http://192.168.1.100/ping_go/backend-deploy';
   ```

---

## ✅ Paso 6: Probar la Configuración

### 6.1 Probar el Backend

Abre tu navegador y prueba estos endpoints:

1. **Health Check**:
   ```
   http://localhost/ping_go/backend-deploy/health.php
   ```
   Debería mostrar: `{"status":"ok"}`

2. **System Verification**:
   ```
   http://localhost/ping_go/backend-deploy/verify_system_json.php
   ```
   Debería mostrar información del sistema y base de datos

3. **Test Authentication** (opcional):
   ```
   http://localhost/ping_go/backend-deploy/auth/login.php
   ```

### 6.2 Probar desde Flutter

Ejecuta el script de prueba:
```bash
cd c:\Flutter\ping_go
dart test_backend.dart
```

Esto probará todos los endpoints principales.

### 6.3 Ejecutar la App

```bash
cd c:\Flutter\ping_go
flutter run
```

O desde VS Code:
- Presiona **F5**
- O click en **Run** → **Start Debugging**

---

## 🔍 Solución de Problemas

### Problema: "Could not connect to database"

**Solución**:
1. Verifica que MySQL esté corriendo en Laragon
2. Verifica las credenciales en `config/database.php`
3. Verifica que la base `Viax` exista
4. Ejecuta en terminal:
   ```bash
   mysql -u root -proot -e "SHOW DATABASES;"
   ```

### Problema: "404 Not Found"

**Solución**:
1. Verifica que la carpeta esté en `C:\laragon\www\ping_go\backend-deploy`
2. Verifica que Apache esté corriendo
3. Prueba acceder a:
   ```
   http://localhost
   ```
   Deberías ver la página de inicio de Laragon

### Problema: "Connection refused" desde Flutter

**Solución**:

Para **navegador web**: usa `localhost`
```dart
return 'http://localhost/ping_go/backend-deploy';
```

Para **emulador Android**: usa `10.0.2.2`
```dart
return 'http://10.0.2.2/ping_go/backend-deploy';
```

Para **dispositivo físico**: usa tu IP local
```dart
return 'http://192.168.1.XXX/ping_go/backend-deploy';
```

### Problema: "Composer dependencies not found"

**Solución**:
```bash
cd C:\laragon\www\ping_go\backend-deploy
composer install --no-dev
```

### Problema: "Permission denied" al escribir archivos

**Solución**:
1. Click derecho en la carpeta `backend-deploy`
2. **Properties** → **Security**
3. Da permisos completos a tu usuario

---

## 📊 Estructura de Archivos Importantes

```
C:\laragon\www\ping_go\backend-deploy\
├── config/
│   ├── database.php          ← Configuración de BD (localhost)
│   └── config.php            ← Configuración general
├── auth/
│   ├── login.php             ← Endpoint de login
│   ├── register.php          ← Endpoint de registro
│   └── email_service.php     ← Servicio de correo
├── conductor/
│   ├── get_profile.php       ← Perfil del conductor
│   ├── update_location.php   ← Actualizar ubicación
│   └── ...
├── user/
│   ├── create_trip_request.php
│   └── ...
├── admin/
│   ├── dashboard_stats.php
│   └── ...
├── health.php                ← Verificación rápida
├── verify_system_json.php    ← Verificación completa
└── composer.json             ← Dependencias PHP
```

---

## 🎓 Tips y Mejores Prácticas

### Desarrollo Eficiente

1. **Mantén Laragon siempre abierto** durante el desarrollo
2. **Usa HeidiSQL** para verificar datos en tiempo real
3. **Revisa los logs de Apache**:
   ```
   C:\laragon\www\ping_go\backend-deploy\logs\
   ```

### Debugging

1. **Activa errores PHP** (solo en desarrollo):
   En cada archivo PHP, agrega al inicio:
   ```php
   error_reporting(E_ALL);
   ini_set('display_errors', 1);
   ```

2. **Usa var_dump()** para debug:
   ```php
   var_dump($data);
   exit;
   ```

3. **Revisa logs de MySQL**:
   Laragon → MySQL → Log file

### Seguridad

> **⚠️ IMPORTANTE**: La configuración actual es SOLO para desarrollo local.
> 
> Antes de desplegar a producción:
> - Cambia las contraseñas
> - Desactiva `display_errors`
> - Usa HTTPS
> - Valida todas las entradas
> - Usa prepared statements (ya implementado)

---

## 📚 Recursos Adicionales

- **Documentación de Laragon**: [https://laragon.org/docs/](https://laragon.org/docs/)
- **Configuración de entornos**: Ver `docs/CONFIGURACION_ENTORNOS.md`
- **Guía de despliegue**: Ver `docs/DEPLOYMENT.md`
- **Endpoints del backend**: Ver `backend-deploy/docs/README.md`

---

## ✨ Resumen del Checklist

- [ ] Laragon instalado y corriendo
- [ ] Backend copiado a `C:\laragon\www\ping_go\backend-deploy`
- [ ] Base de datos `Viax` creada
- [ ] SQL importado correctamente
- [ ] `composer install` ejecutado
- [ ] `config/database.php` configurado (localhost/root/root)
- [ ] Flutter configurado con URL local
- [ ] `health.php` responde correctamente
- [ ] `verify_system_json.php` muestra conexión exitosa
- [ ] App Flutter se conecta al backend local

---

**¡Listo!** Ahora puedes desarrollar Viax en tu entorno local con Laragon.

Para cambiar a producción más tarde, consulta: `docs/CONFIGURACION_ENTORNOS.md`
