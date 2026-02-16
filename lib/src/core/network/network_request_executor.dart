import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:viax/src/core/network/app_network_exception.dart';
import 'package:viax/src/core/network/connectivity_service.dart';

class NetworkRequestResult {
  final bool success;
  final Map<String, dynamic>? json;
  final AppNetworkException? error;
  final int? statusCode;

  const NetworkRequestResult._({
    required this.success,
    this.json,
    this.error,
    this.statusCode,
  });

  factory NetworkRequestResult.ok(Map<String, dynamic> json, int statusCode) {
    return NetworkRequestResult._(success: true, json: json, statusCode: statusCode);
  }

  factory NetworkRequestResult.fail(AppNetworkException error, {int? statusCode}) {
    return NetworkRequestResult._(success: false, error: error, statusCode: statusCode);
  }
}

/// Ejecuta requests HTTP con verificación de internet, timeout y parseo consistente.
class NetworkRequestExecutor {
  const NetworkRequestExecutor();

  Future<NetworkRequestResult> getJson({
    required Uri url,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
    bool requireDataPayload = false,
  }) async {
    return _execute(
      request: () => http.get(url, headers: headers),
      timeout: timeout,
      requireDataPayload: requireDataPayload,
    );
  }

  Future<NetworkRequestResult> postJson({
    required Uri url,
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
    bool requireDataPayload = false,
  }) async {
    return _execute(
      request: () => http.post(url, headers: headers, body: body),
      timeout: timeout,
      requireDataPayload: requireDataPayload,
    );
  }

  Future<NetworkRequestResult> putJson({
    required Uri url,
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
    bool requireDataPayload = false,
  }) async {
    return _execute(
      request: () => http.put(url, headers: headers, body: body),
      timeout: timeout,
      requireDataPayload: requireDataPayload,
    );
  }

  Future<NetworkRequestResult> deleteJson({
    required Uri url,
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
    bool requireDataPayload = false,
  }) async {
    return _execute(
      request: () => http.delete(url, headers: headers, body: body),
      timeout: timeout,
      requireDataPayload: requireDataPayload,
    );
  }

  Future<NetworkRequestResult> _execute({
    required Future<http.Response> Function() request,
    required Duration timeout,
    required bool requireDataPayload,
  }) async {
    try {
      final hasInternet = await ConnectivityService().hasInternetConnection();
      if (!hasInternet) {
        return NetworkRequestResult.fail(
          const AppNetworkException(
            type: AppNetworkErrorType.offline,
            technicalMessage: 'No internet connection before request',
          ),
        );
      }

      final response = await request().timeout(timeout);

      Map<String, dynamic>? json;
      if (response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        } else {
          return NetworkRequestResult.fail(
            AppNetworkException(
              type: AppNetworkErrorType.invalidResponse,
              technicalMessage: 'Response is not a JSON object',
              statusCode: response.statusCode,
            ),
            statusCode: response.statusCode,
          );
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final backendMessage = json?['message']?.toString();
        return NetworkRequestResult.fail(
          AppNetworkException.fromStatusCode(
            response.statusCode,
            backendMessage: backendMessage,
          ),
          statusCode: response.statusCode,
        );
      }

      if (json == null) {
        return NetworkRequestResult.fail(
          AppNetworkException(
            type: AppNetworkErrorType.noData,
            technicalMessage: 'Empty body with successful status',
            statusCode: response.statusCode,
          ),
          statusCode: response.statusCode,
        );
      }

      if (requireDataPayload && (!json.containsKey('data') || json['data'] == null)) {
        return NetworkRequestResult.fail(
          AppNetworkException(
            type: AppNetworkErrorType.noData,
            technicalMessage: 'JSON response missing data payload',
            backendMessage: json['message']?.toString(),
            statusCode: response.statusCode,
          ),
          statusCode: response.statusCode,
        );
      }

      return NetworkRequestResult.ok(json, response.statusCode);
    } on TimeoutException catch (e) {
      return NetworkRequestResult.fail(AppNetworkException.fromError(e));
    } catch (e) {
      return NetworkRequestResult.fail(AppNetworkException.fromError(e));
    }
  }
}
