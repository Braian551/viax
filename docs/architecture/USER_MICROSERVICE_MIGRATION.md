# Migración Exitosa: Microservicio de Usuarios

## 📋 Resumen Ejecutivo

Se ha completado exitosamente la migración del módulo de autenticación y usuarios a una arquitectura de microservicios siguiendo los principios de Clean Architecture. El proyecto mantiene compatibilidad total con la base de datos existente mientras establece las bases para una futura separación completa de servicios.

## ✅ Estado de la Migración

### Completado

- ✅ **Arquitectura Clean implementada** (Domain, Data, Presentation)
- ✅ **Microservicio de Usuarios funcional** con todas las operaciones CRUD
- ✅ **Inyección de dependencias** con Service Locator
- ✅ **Configuración modular** preparada para múltiples servicios
- ✅ **Backend documentado** con README completo
- ✅ **Provider integrado** en la aplicación principal
- ✅ **Compatibilidad mantenida** con código existente

### Pendiente

- ⏳ Actualizar screens de login/register para usar nuevo provider
- ⏳ Implementar tests unitarios para domain layer
- ⏳ Separar base de datos (cuando escale)
- ⏳ Implementar JWT tokens
- ⏳ Dockerizar servicio

## 🏗️ Estructura Implementada

### Frontend (Flutter)

```
lib/src/features/user/  # Microservicio de Usuarios
├── domain/
│   ├── entities/
│   │   ├── user.dart              # Entidad User + UserLocation + UserType
│   │   └── auth_session.dart      # Entidad AuthSession
│   ├── repositories/
│   │   └── user_repository.dart   # Contrato del repositorio
│   └── usecases/
│       ├── register_user.dart     # UC: Registrar usuario
│       ├── login_user.dart        # UC: Login
│       ├── logout_user.dart       # UC: Logout
│       ├── get_user_profile.dart  # UC: Obtener perfil
│       ├── update_user_profile.dart    # UC: Actualizar perfil
│       ├── update_user_location.dart   # UC: Actualizar ubicación
│       └── get_saved_session.dart      # UC: Cargar sesión guardada
├── data/
│   ├── datasources/
│   │   ├── user_remote_datasource.dart      # Contrato API
│   │   ├── user_remote_datasource_impl.dart # Implementación HTTP
│   │   ├── user_local_datasource.dart       # Contrato Local
│   │   └── user_local_datasource_impl.dart  # Implementación SharedPrefs
│   ├── models/
│   │   └── user_model.dart        # DTOs con serialización JSON
│   └── repositories/
│       └── user_repository_impl.dart  # Implementación del repositorio
└── presentation/
    └── providers/
        └── user_provider.dart      # Provider para UI (ChangeNotifier)
```

### Backend (PHP)

```
viax/backend/auth/  # Microservicio de Usuarios (Backend)
├── register.php           # POST - Registrar usuario
├── login.php             # POST - Login
├── profile.php           # GET - Obtener perfil
├── profile_update.php    # POST - Actualizar perfil/ubicación
├── check_user.php        # POST - Verificar existencia de usuario
└── README_USER_MICROSERVICE.md  # Documentación completa
```

### Core (Compartido)

```
lib/src/core/
├── config/
│   └── app_config.dart           # URLs y configuración de servicios
├── di/
│   └── service_locator.dart      # Inyección de dependencias
├── error/
│   ├── exceptions.dart           # Excepciones técnicas
│   ├── failures.dart             # Errores de dominio
│   └── result.dart               # Tipo Result<T> funcional
```

## 🔄 Flujo de Datos

### Ejemplo: Registro de Usuario

```
1. UI (RegisterScreen)
   └─> UserProvider.register()

2. Presentation Layer
   └─> RegisterUser UseCase
       └─> Validaciones de negocio

3. Domain Layer
   └─> UserRepository (interface)

4. Data Layer
   └─> UserRepositoryImpl
       ├─> UserRemoteDataSource (HTTP)
       │   └─> POST /auth/register.php
       └─> UserLocalDataSource (SharedPreferences)
           └─> Guardar sesión

5. Response
   └─> AuthSession (Entity)
       └─> Success/Error (Result<T>)
```

## 📊 Comparación: Antes vs Después

| Aspecto | Antes (Monolito) | Después (Microservicio) |
|---------|------------------|-------------------------|
| **Arquitectura** | Acoplado, sin capas | Clean Architecture (3 capas) |
| **Testabilidad** | Difícil (dependencias mixtas) | Fácil (domain sin dependencias) |
| **Mantenibilidad** | Código espagueti | Separación de responsabilidades |
| **Escalabilidad** | Monolítica | Preparado para microservicios |
| **Reutilización** | Baja | Alta (use cases reutilizables) |
| **Manejo de errores** | try-catch inconsistente | Result<T> funcional |
| **Dependencias** | Directas (new) | Inyectadas (DI) |
| **URLs Backend** | Hardcoded en servicios | Centralizadas en AppConfig |

## 🚀 Cómo Usar el Microservicio

### En Flutter (Ejemplo con Provider)

```dart
// 1. Obtener el provider
final userProvider = Provider.of<UserProvider>(context, listen: false);

// 2. Registrar usuario
final success = await userProvider.register(
  nombre: 'Juan',
  apellido: 'Pérez',
  email: 'juan@example.com',
  telefono: '3001234567',
  password: '123456',
  direccion: 'Calle 123',
  latitud: 4.6097,
  longitud: -74.0817,
  ciudad: 'Bogotá',
);

if (success) {
  // Usuario registrado, sesión activa
  final user = userProvider.currentUser;
  print('Usuario: ${user?.nombreCompleto}');
}

// 3. Login
await userProvider.login(
  email: 'juan@example.com',
  password: '123456',
);

// 4. Obtener perfil
await userProvider.getProfile(userId: 1);

// 5. Actualizar perfil
await userProvider.updateProfile(
  userId: 1,
  nombre: 'Juan Carlos',
  telefono: '3009876543',
);

// 6. Logout
await userProvider.logout();
```

### Usando Use Cases Directamente (Sin Provider)

```dart
// Obtener use case del service locator
final registerUser = ServiceLocator().registerUser;

// Ejecutar
final result = await registerUser(
  nombre: 'Juan',
  apellido: 'Pérez',
  email: 'juan@example.com',
  telefono: '3001234567',
  password: '123456',
);

// Manejar resultado
result.when(
  success: (session) => print('Éxito: ${session.user.nombreCompleto}'),
  error: (failure) => print('Error: ${failure.message}'),
);
```

## 🔧 Configuración

### URLs de Servicios

En `lib/src/core/config/app_config.dart`:

```dart
// Desarrollo
static String get baseUrl => 'http://10.0.2.2/viax/backend';

// Microservicio de Usuarios
static String get userServiceUrl => '$baseUrl/auth';

// Futuro (con microservicios separados):
// static String get userServiceUrl => 'https://api.Viax.com/user-service/v1';
```

### Service Locator

En `lib/main.dart`:

```dart
void main() async {
  // Inicializar DI
  final serviceLocator = ServiceLocator();
  await serviceLocator.init();

  runApp(
    MultiProvider(
      providers: [
        // User Microservice
        ChangeNotifierProvider(
          create: (_) => serviceLocator.createUserProvider(),
        ),
        // ... otros providers
      ],
      child: const MyApp(),
    ),
  );
}
```

## 📱 Endpoints del Backend

### Base URL
- **Desarrollo**: `http://10.0.2.2/viax/backend/auth`
- **Producción**: `https://api.Viax.com/user-service/v1` (futuro)

### Endpoints Disponibles

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/register.php` | Registrar nuevo usuario |
| POST | `/login.php` | Iniciar sesión |
| GET | `/profile.php?userId=X` | Obtener perfil por ID |
| GET | `/profile.php?email=X` | Obtener perfil por email |
| POST | `/profile_update.php` | Actualizar perfil/ubicación |
| POST | `/check_user.php` | Verificar si usuario existe |

Ver documentación completa en: `viax/backend/auth/README_USER_MICROSERVICE.md`

## 🧪 Testing

### Unit Tests (Domain Layer)

```dart
test('RegisterUser should validate email format', () async {
  // Arrange
  final mockRepo = MockUserRepository();
  final useCase = RegisterUser(mockRepo);

  // Act
  final result = await useCase(
    nombre: 'Juan',
    apellido: 'Pérez',
    email: 'invalid-email', // Email inválido
    telefono: '123',
    password: '123456',
  );

  // Assert
  expect(result, isA<Error>());
  expect(result.when(
    success: (_) => '',
    error: (failure) => failure.message,
  ), contains('email no es válido'));
});
```

### Integration Tests (Data Layer)

```dart
test('UserRemoteDataSource should register user successfully', () async {
  // Arrange
  final mockClient = MockClient((request) async {
    return http.Response(
      '{"success":true,"data":{"user":{"id":1,"nombre":"Juan"}}}',
      200,
    );
  });
  final dataSource = UserRemoteDataSourceImpl(client: mockClient);

  // Act
  final result = await dataSource.register(
    nombre: 'Juan',
    apellido: 'Pérez',
    email: 'juan@test.com',
    telefono: '123',
    password: '123456',
  );

  // Assert
  expect(result['success'], true);
  expect(result['data']['user']['nombre'], 'Juan');
});
```

## 🎯 Próximos Pasos

### Corto Plazo (1-2 semanas)

1. **Migrar Screens de Auth**
   - Actualizar `login_screen.dart`
   - Actualizar `register_screen.dart`
   - Actualizar `home_screen.dart` (para auto-login)
   
2. **Implementar Tests**
   - Unit tests para domain layer
   - Widget tests para screens
   - Integration tests para repository

3. **Mejorar Manejo de Errores**
   - Mensajes de error amigables
   - Logging de errores
   - Sentry/Crashlytics

### Mediano Plazo (1-2 meses)

4. **Implementar JWT Tokens**
   - Generar tokens en backend
   - Validar tokens en cada request
   - Refresh tokens

5. **Migrar Otros Módulos**
   - Microservicio de Conductores
   - Microservicio de Viajes
   - Microservicio de Pagos

6. **API Gateway**
   - Configurar NGINX/Kong
   - Routing a servicios
   - Rate limiting

### Largo Plazo (3-6 meses)

7. **Separar Base de Datos**
   - `user_db` para usuarios
   - `conductor_db` para conductores
   - Event-driven sync entre servicios

8. **Dockerización**
   - Dockerfile por servicio
   - docker-compose.yml

9. **Observabilidad**
   - Logging centralizado (ELK Stack)
   - Métricas (Prometheus + Grafana)
   - Tracing (Jaeger)

## 📚 Documentación Relacionada

- [Clean Architecture](../docs/architecture/CLEAN_ARCHITECTURE.md)
- [Guía de Migración a Microservicios](../docs/architecture/MIGRATION_TO_MICROSERVICES.md)
- [Backend User Microservice](../viax/backend/auth/README_USER_MICROSERVICE.md)

## 🤝 Contribuir

### Agregar Nuevo Endpoint

1. **Backend**: Crear archivo PHP en `viax/backend/auth/`
2. **DataSource**: Agregar método en `UserRemoteDataSource`
3. **Repository**: Implementar en `UserRepositoryImpl`
4. **Use Case**: Crear archivo en `domain/usecases/`
5. **Provider**: Agregar método en `UserProvider`
6. **UI**: Consumir desde screen

### Ejemplo: Agregar "Cambiar Contraseña"

```dart
// 1. Use Case
class ChangePassword {
  final UserRepository repository;
  
  Future<Result<void>> call({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    // Validaciones...
    return await repository.changePassword(...);
  }
}

// 2. Provider
class UserProvider extends ChangeNotifier {
  Future<bool> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    final result = await changePasswordUseCase(...);
    // Handle result...
  }
}

// 3. UI
await userProvider.changePassword(
  userId: currentUser.id,
  oldPassword: '123456',
  newPassword: 'newpass123',
);
```

## ⚠️ Notas Importantes

1. **Compatibilidad**: El código legacy sigue funcionando. La migración es gradual.

2. **Base de Datos**: Todos los servicios usan la misma BD por ahora. Separar solo cuando sea necesario.

3. **URLs**: Las URLs apuntan al monolito actual. Cambiar solo cuando se desplieguen servicios separados.

4. **Testing**: Priorizar domain layer tests (sin dependencias externas).

5. **Performance**: La nueva arquitectura no afecta el rendimiento. Los use cases son lightweight.

## 🎉 Conclusión

La migración a arquitectura de microservicios para el módulo de usuarios se ha completado con éxito. El sistema ahora tiene:

- ✅ Separación clara de responsabilidades
- ✅ Código testeable y mantenible
- ✅ Preparado para escalar horizontalmente
- ✅ Compatible con código existente
- ✅ Documentación completa

**Siguiente módulo a migrar**: Conductores

---

**Versión**: 1.0.0  
**Fecha**: Octubre 2025  
**Autor**: Equipo Ping Go Development
