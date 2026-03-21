import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../core/network/app_network_exception.dart';
import '../../core/network/network_request_executor.dart';

class UserBlockState {
  final bool blockedByMe;
  final bool blockedMe;
  final bool eitherBlocked;
  final bool hasActiveTrip;
  final bool canSendMessage;
  final bool canMatchFutureTrips;

  const UserBlockState({
    required this.blockedByMe,
    required this.blockedMe,
    required this.eitherBlocked,
    required this.hasActiveTrip,
    required this.canSendMessage,
    required this.canMatchFutureTrips,
  });

  factory UserBlockState.fromJson(Map<String, dynamic> json) {
    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final n = v.trim().toLowerCase();
        return n == '1' || n == 'true' || n == 'si' || n == 'yes';
      }
      return false;
    }

    return UserBlockState(
      blockedByMe: asBool(json['blocked_by_me']),
      blockedMe: asBool(json['blocked_me']),
      eitherBlocked: asBool(json['either_blocked']),
      hasActiveTrip: asBool(json['has_active_trip']),
      canSendMessage: asBool(json['can_send_message']),
      canMatchFutureTrips: asBool(json['can_match_future_trips']),
    );
  }
}

class UserBlockService {
  static const NetworkRequestExecutor _network = NetworkRequestExecutor();
  static String get _baseUrl => AppConfig.baseUrl;

  static String _friendlyError(NetworkRequestResult result, String fallback) {
    return result.error?.userMessage ?? fallback;
  }

  static Future<UserBlockState> getBlockState({
    required int actorId,
    required int otherUserId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/user/is_blocked.php?actor_id=$actorId&other_user_id=$otherUserId',
    );

    final result = await _network.getJson(
      url: uri,
      headers: {'Accept': 'application/json'},
      timeout: AppConfig.connectionTimeout,
    );

    if (!result.success || result.json == null) {
      throw Exception(
        _friendlyError(result, 'No pudimos consultar el estado de bloqueo.'),
      );
    }

    final payload = result.json!;
    if (payload['success'] != true) {
      throw Exception(
        payload['message']?.toString() ??
            'No pudimos consultar el estado de bloqueo.',
      );
    }

    return UserBlockState.fromJson(
      (payload['data'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
    );
  }

  static Future<UserBlockState> blockUser({
    required int actorId,
    required int blockedUserId,
    int? solicitudId,
    String? reason,
  }) async {
    final result = await _network.postJson(
      url: Uri.parse('$_baseUrl/user/block_user.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'actor_id': actorId,
        'blocked_user_id': blockedUserId,
        if (solicitudId != null) 'solicitud_id': solicitudId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
      timeout: AppConfig.connectionTimeout,
    );

    if (!result.success || result.json == null) {
      throw Exception(
        _friendlyError(result, 'No pudimos bloquear al usuario.'),
      );
    }

    final payload = result.json!;
    if (payload['success'] != true) {
      throw Exception(payload['message']?.toString() ?? 'No pudimos bloquear al usuario.');
    }

    final data = (payload['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    return UserBlockState.fromJson(data);
  }

  static Future<UserBlockState> unblockUser({
    required int actorId,
    required int blockedUserId,
  }) async {
    final result = await _network.postJson(
      url: Uri.parse('$_baseUrl/user/unblock_user.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'actor_id': actorId,
        'blocked_user_id': blockedUserId,
      }),
      timeout: AppConfig.connectionTimeout,
    );

    if (!result.success || result.json == null) {
      throw Exception(
        _friendlyError(result, 'No pudimos desbloquear al usuario.'),
      );
    }

    final payload = result.json!;
    if (payload['success'] != true) {
      throw Exception(
        payload['message']?.toString() ?? 'No pudimos desbloquear al usuario.',
      );
    }

    final data = (payload['data'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    return UserBlockState.fromJson(data);
  }

  static String friendlyFromError(Object error) {
    return AppNetworkException.fromError(error).userMessage;
  }
}
