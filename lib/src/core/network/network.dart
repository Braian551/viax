/// Módulo de resiliencia de red y sincronización
/// 
/// Este módulo proporciona herramientas para manejar:
/// - Latencia de red y reintentos automáticos
/// - Operaciones offline con cola de sincronización
/// - Optimistic updates para mejor UX
/// - Detección y resolución de conflictos
library;

export 'network_resilience_service.dart';
export 'connectivity_service.dart';
export 'app_network_exception.dart';
export 'network_request_executor.dart';
export 'trip_sync_manager.dart';
