import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

import '../global_config.dart';
import '../models/employee_model.dart';
import '../services/employee_api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  static const List<String> _scopes = <String>['openid', 'profile', 'email',];

  // ============================================================
  // SSO LOGIN
  //
  // Authorization Code + PKCE
  //
  // flutter_appauth / native AppAuth handles:
  //
  //   1. state generation
  //   2. PKCE code_verifier generation
  //   3. PKCE S256 code_challenge generation
  //   4. authorization request
  //   5. redirect handling
  //   6. authorization-code exchange
  //   7. sending code_verifier to Keycloak
  //
  // ============================================================

  Future<EmployeeModel> loginWithSSO() async {
    try {
      if (kDebugMode) {
        debugPrint('==============================================');
        debugPrint('SSO LOGIN START');
        debugPrint('Issuer       : ${GlobalConfig.issuer}');
        debugPrint('Client ID    : ${GlobalConfig.clientId}');
        debugPrint('Redirect URI : ${GlobalConfig.redirectUri}');
        debugPrint('Scopes       : ${_scopes.join(' ')}');
        debugPrint('Grant        : Authorization Code + PKCE');
        debugPrint('==============================================');
      }

      // ----------------------------------------------------------
      // Authorization Code + PKCE
      // ----------------------------------------------------------
      //
      // AppAuth automatically creates a cryptographically random
      // code_verifier and derives the S256 code_challenge.
      //
      // It also uses state to protect the authorization response.
      //
      // DO NOT manually create the verifier/challenge here unless
      // you have a specific reason to implement the complete OAuth
      // transaction yourself.
      //
      final AuthorizationTokenResponse? response =
      await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          GlobalConfig.clientId,
          GlobalConfig.redirectUri,

          // OIDC discovery.
          // AppAuth obtains:
          //
          // authorization_endpoint
          // token_endpoint
          // jwks_uri
          // issuer
          //
          issuer: GlobalConfig.issuer,

          scopes: _scopes,

          // This is an OAuth authorization-code request.
          //
          // PKCE is handled by AppAuth.
        ),
      );

      if (response == null) {
        throw Exception('SSO login was cancelled.');
      }

      if (response.accessToken == null ||
          response.accessToken!.isEmpty) {
        throw Exception('Keycloak did not return an access token.');
      }

      final String accessToken = response.accessToken!;

      if (kDebugMode) {
        debugPrint('==============================================');
        debugPrint('TOKEN EXCHANGE SUCCESS');
        debugPrint(
          'Access token received : ${response.accessToken != null}',
        );
        debugPrint(
          'ID token received     : ${response.idToken != null}',
        );
        debugPrint(
          'Refresh token received: ${response.refreshToken != null}',
        );
        debugPrint(
          'Expires at             : '
              '${response.accessTokenExpirationDateTime}',
        );
        debugPrint('==============================================');
      }

      // ----------------------------------------------------------
      // Read employee ID from ID token
      // ----------------------------------------------------------

      final String? idToken = response.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Keycloak did not return an ID token.');
      }

      final Map<String, dynamic> claims =
      _decodeJwtPayload(idToken);

      final String employeeId =
          claims['preferred_username']?.toString() ?? '';

      if (employeeId.isEmpty) {
        throw Exception(
          'Employee ID was not found in preferred_username claim.',
        );
      }

      if (kDebugMode) {
        debugPrint('Employee ID: $employeeId');
        debugPrint('Name       : ${claims['name'] ?? ''}');
        debugPrint('Email      : ${claims['email'] ?? ''}');
      }

      // ----------------------------------------------------------
      // Call Spring Boot
      // ----------------------------------------------------------

      final EmployeeModel employee =
      await EmployeeApiService.fetchEmployeeInfo(
        employeeId: employeeId,
        date: DateTime.now()
            .toIso8601String()
            .split('T')
            .first,
        accessToken: accessToken,
      );

      // ----------------------------------------------------------
      // Store authenticated session
      // ----------------------------------------------------------

      globals.setAuthData(
        accessToken,
        employee,
      );

      if (kDebugMode) {
        debugPrint('==============================================');
        debugPrint('SSO LOGIN COMPLETE');
        debugPrint(
          'Employee: ${employee.name} (${employee.userId})',
        );
        debugPrint('==============================================');
      }

      return employee;
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

    final String normalized =
    base64Url.normalize(parts[1]);

    final String payload =
    utf8.decode(base64Url.decode(normalized));

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

  void logout() {
    globals.clearAuthData();
  }

  String? getAccessToken() {
    return globals.accessToken;
  }

  EmployeeModel? getCurrentEmployee() {
    return globals.currentEmployee;
  }

  bool isLoggedIn() {
    return globals.isLoggedIn;
  }
}