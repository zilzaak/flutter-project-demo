import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import '../global_config.dart';
import '../models/employee_model.dart';
import '../services/employee_api_service.dart';
import 'location_service.dart';
import 'token_cache_service.dart';

class AuthService {

  EmployeeModel? employee;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  static const List<String> _scopes = <String>['openid', 'profile', 'email',];

  Future<EmployeeModel> loginWithSSO() async {
    try {
      final AuthorizationTokenResponse? response =
      await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          GlobalConfig.clientId,
          GlobalConfig.redirectUri,
          issuer: GlobalConfig.issuer,
          scopes: _scopes,
        ),
      );

      if (response == null) {throw Exception('SSO login was cancelled.');
      }
      if (response.accessToken == null || response.accessToken!.isEmpty) {throw Exception('Keycloak did not return an access token.');}

      final String accessToken = response.accessToken!;
      final String? idToken = response.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Keycloak did not return an ID token.');
      }
      final Map<String, dynamic> claims = _decodeJwtPayload(idToken);
      final String employeeId = claims['preferred_username']?.toString() ?? '';

      // ── Save fresh token to secure key store (overwrite same-day entry,
      //    evict any previous-date token automatically). ───────────────────
      await tokenCacheService.saveAndEvictOld(accessToken);

      // Store credentials in globals immediately for rest of app.
      globals.accessToken = accessToken;

      if (kDebugMode) {
        debugPrint('Employee ID: $employeeId');
        debugPrint('Name       : ${claims['name'] ?? ''}');
        debugPrint('Email      : ${claims['email'] ?? ''}');
      }

      final employee = await employeeApiService.fetchEmployeeInfo(
        employeeId: employeeId,
        date: DateTime.now().toIso8601String().split('T').first,
        accessToken: accessToken,
      );

      // Build employee object with the fresh token embedded.
      final employeeWithToken = EmployeeModel(
        userId: employee.userId,
        name: employee.name,
        designation: employee.designation,
        department: employee.department,
        joiningDate: employee.joiningDate,
        startTime: employee.startTime,
        endTime: employee.endTime,
        firstPunch: employee.firstPunch,
        token: accessToken,   // ← token field always reflects the fresh token
      );

      globals.setAuthData(accessToken, employeeWithToken);

      if (kDebugMode) {
        debugPrint('==============================================');
        debugPrint('SSO LOGIN COMPLETE');
        debugPrint('Employee : ${employeeWithToken.name} (${employeeWithToken.userId})');
        debugPrint('Token cached under today key in key store.');
        debugPrint('==============================================');
      }
      this.employee = employeeWithToken;
      return employeeWithToken;
    } on FlutterAppAuthUserCancelledException {
      throw Exception('SSO login was cancelled.');
    } on FlutterAppAuthPlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('AppAuth error: ${e.code}');
        debugPrint('AppAuth message: ${e.message}');
        debugPrint('AppAuth details: ${e.details}');
      }

      throw Exception(
        'SSO authentication failed: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SSO login failed: $e');
      }

      rethrow;
    }
  }

  // ============================================================
  // OLD LOGIN METHOD
  // ============================================================
  //
  // Your current UI has a password button, but it actually calls
  // SSO. Keep this only if you need backward compatibility.
  //
  Future<EmployeeModel> login({
    String? userId,
    String? password,
  }) {
    return loginWithSSO();
  }

  // ============================================================
  // JWT PAYLOAD DECODER
  // ============================================================
  //
  // IMPORTANT:
  // This ONLY decodes the JWT.
  //
  // It does NOT verify the JWT signature.
  //
  // Actual security validation must happen in Spring Boot.
  //
  Map<String, dynamic> _decodeJwtPayload(String token) {
    final List<String> parts = token.split('.');

    if (parts.length != 3) {
      throw const FormatException(
        'Invalid JWT: expected 3 parts.',
      );
    }

    final String normalized = base64Url.normalize(parts[1]);
    final String payload = utf8.decode(base64Url.decode(normalized));
    final dynamic decoded = jsonDecode(payload);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid JWT payload.',
      );
    }

    return decoded;
  }

  // ============================================================
  // SESSION MANAGEMENT
  // ============================================================

  /// Stops background location sync.
  ///
  /// NOTE: Auth data (globals.accessToken, globals.currentEmployee) and the
  /// key-store token cache are intentionally NOT cleared here.
  /// The session must remain alive for up to 8 hours of continuous service;
  /// token expiration is handled on the backend (Spring Boot ignores exp).
  void logout() {
    LocationService().stopScheduledSync();
    // globals.clearAuthData() ← deliberately disabled for continuous 8-h session
    if (kDebugMode) {
      debugPrint('⏹️  [AuthService] Location sync stopped. Session kept alive (8-h mode).');
    }
  }

  String? getAccessToken() {
    return globals.accessToken;
  }

  EmployeeModel? getCurrentEmployee() {
    return globals.currentEmployee;
  }

}
final authService = AuthService();