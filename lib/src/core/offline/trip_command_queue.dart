import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Tipos de comando soportados para sincronización confiable de viajes.
enum TripCommandType {
  finishTrip,
  startTrip,
  driverArrived,
  cancelTrip,
}

extension TripCommandTypeWire on TripCommandType {
  String get wireValue {
    switch (this) {
      case TripCommandType.finishTrip:
        return 'finish_trip';
      case TripCommandType.startTrip:
        return 'start_trip';
      case TripCommandType.driverArrived:
        return 'driver_arrived';
      case TripCommandType.cancelTrip:
        return 'cancel_trip';
    }
  }

  static TripCommandType fromWire(String value) {
    switch (value) {
      case 'finish_trip':
        return TripCommandType.finishTrip;
      case 'start_trip':
        return TripCommandType.startTrip;
      case 'driver_arrived':
        return TripCommandType.driverArrived;
      case 'cancel_trip':
        return TripCommandType.cancelTrip;
      default:
        throw ArgumentError('Tipo de comando no soportado: $value');
    }
  }
}

/// Modelo persistente de un comando de viaje pendiente por sincronizar.
class TripCommand {
  final int? id;
  final int tripId;
  final String commandType;
  final String payloadJson;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttemptAt;

  const TripCommand({
    this.id,
    required this.tripId,
    required this.commandType,
    required this.payloadJson,
    required this.createdAt,
    required this.retryCount,
    this.lastAttemptAt,
  });

  TripCommand copyWith({
    int? id,
    int? tripId,
    String? commandType,
    String? payloadJson,
    DateTime? createdAt,
    int? retryCount,
    DateTime? lastAttemptAt,
    bool clearLastAttemptAt = false,
  }) {
    return TripCommand(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      commandType: commandType ?? this.commandType,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: clearLastAttemptAt ? null : (lastAttemptAt ?? this.lastAttemptAt),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'trip_id': tripId,
      'command_type': commandType,
      'payload_json': payloadJson,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> payloadMap() {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  factory TripCommand.fromMap(Map<String, dynamic> map) {
    return TripCommand(
      id: map['id'] as int?,
      tripId: (map['trip_id'] as num).toInt(),
      commandType: map['command_type'] as String,
      payloadJson: map['payload_json'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      lastAttemptAt: map['last_attempt_at'] != null
          ? DateTime.parse(map['last_attempt_at'] as String)
          : null,
    );
  }
}

/// Cola persistente en SQLite para comandos críticos de viaje.
class TripCommandQueue {
  TripCommandQueue._();

  static final TripCommandQueue instance = TripCommandQueue._();

  static const String _dbName = 'viax_trip_commands.db';
  static const int _dbVersion = 1;
  static const String _table = 'trip_commands';

  Database? _db;

  Future<void> initialize() async {
    if (_db != null) {
      return;
    }

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            command_type TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_attempt_at TEXT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_trip_commands_trip ON $_table(trip_id, command_type)',
        );
        await db.execute(
          'CREATE INDEX idx_trip_commands_created ON $_table(created_at)',
        );
      },
    );
  }

  Future<TripCommand?> enqueue({
    required int tripId,
    required TripCommandType type,
    required Map<String, dynamic> payload,
  }) async {
    await initialize();

    final startedAt = DateTime.now();

    // Guardia de seguridad: evitar duplicar finalización para el mismo viaje.
    if (type == TripCommandType.finishTrip) {
      final existing = await _findExistingPendingFinish(tripId);
      if (existing != null) {
        _log(
          tag: '[TripCommandQueue]',
          tripId: tripId,
          result: 'duplicate_finish_ignored',
          latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
        );
        return existing;
      }
    }

    final now = DateTime.now();
    final command = TripCommand(
      tripId: tripId,
      commandType: type.wireValue,
      payloadJson: jsonEncode(payload),
      createdAt: now,
      retryCount: 0,
      lastAttemptAt: null,
    );

    final id = await _db!.insert(_table, command.toMap());
    final inserted = command.copyWith(id: id);

    _log(
      tag: '[TripCommandQueue]',
      tripId: tripId,
      result: 'enqueued_${type.wireValue}',
      latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
    );

    return inserted;
  }

  Future<List<TripCommand>> getPendingCommands({int limit = 200}) async {
    await initialize();

    final rows = await _db!.query(
      _table,
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return rows.map(TripCommand.fromMap).toList();
  }

  Future<void> markAttempt({
    required int commandId,
    required int retryCount,
    required DateTime lastAttemptAt,
  }) async {
    await initialize();
    await _db!.update(
      _table,
      <String, dynamic>{
        'retry_count': retryCount,
        'last_attempt_at': lastAttemptAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object>[commandId],
    );
  }

  Future<void> removeById(int commandId) async {
    await initialize();
    await _db!.delete(
      _table,
      where: 'id = ?',
      whereArgs: <Object>[commandId],
    );
  }

  Future<void> clearAll() async {
    await initialize();
    await _db!.delete(_table);
  }

  Future<TripCommand?> _findExistingPendingFinish(int tripId) async {
    final rows = await _db!.query(
      _table,
      where: 'trip_id = ? AND command_type = ?',
      whereArgs: <Object>[tripId, TripCommandType.finishTrip.wireValue],
      orderBy: 'created_at ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return TripCommand.fromMap(rows.first);
  }

  void _log({
    required String tag,
    required int tripId,
    required String result,
    required int latencyMs,
  }) {
    final ts = DateTime.now().toIso8601String();
    debugPrint(
      '$tag ts=$ts tripId=$tripId latency_ms=$latencyMs result=$result',
    );
  }
}
