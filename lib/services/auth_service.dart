
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import '../app_global.dart';
import '../models/employee_model.dart';
import '../services/employee_api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  // ─────────────────────────────────────────────────────────────────────────
  // Keycloak / SSO Configuration  (mirrors Angular environment.ts)
  //   sso_url     : https://auth0.diu.edu.bd
  //   sso_realm   : diu
  //   sso_clientId: dm-app
  // ─────────────────────────────────────────────────────────────────────────

  static const String _ssoBaseUrl  = 'https://auth0.diu.edu.bd';
  static const String _ssoRealm    = 'diu';          // ← realm is always 'diu'
  static const String _ssoClientId = 'dm-app';       // ← new client ID registered by admin

  /// OIDC issuer — flutter_appauth uses this to auto-discover:
  ///   auth endpoint    : /realms/diu/protocol/openid-connect/auth
  ///   token endpoint   : /realms/diu/protocol/openid-connect/token
  static const String _issuer = '$_ssoBaseUrl/realms/$_ssoRealm';

  /// ─── redirect_uri explanation ───────────────────────────────────────────
  ///
  /// The Angular web app uses  http://localhost:4200/dashboard  as redirect_uri
  /// because the browser can navigate to that URL after login.
  ///
  /// A NATIVE Android app cannot open http://localhost:4200 — it needs an
  /// Android custom-scheme URI that the OS can deliver back to the app.
  ///
  /// So our redirect_uri is:  com.example.mydemoproject://oauth2redirect
  ///
  /// What happens after login:
  ///  1. User enters credentials on Keycloak's login page (Chrome Custom Tab).
  ///  2. Keycloak's /login-actions/authenticate validates them.
  ///  3. Keycloak redirects the tab to:
  ///       com.example.mydemoproject://oauth2redirect?code=ABC&state=XYZ
  ///  4. Android delivers that URI to RedirectUriReceiverActivity (AndroidManifest).
  ///  5. flutter_appauth receives the `code`, then POSTs to the token endpoint:
  ///       POST /realms/diu/protocol/openid-connect/token
  ///         grant_type    = authorization_code
  ///         code          = ABC
  ///         code_verifier = <PKCE verifier generated at step 1>
  ///         client_id     = dm-app
  ///         redirect_uri  = com.example.mydemoproject://oauth2redirect
  ///  6. Keycloak returns access_token, id_token, refresh_token.
  ///  7. We extract preferred_username from id_token → employeeId.
  ///  8. We call Spring Boot /api/ess/portal/employee-duty-monitoring/enroll-user
  ///     with Bearer <access_token> → employee profile data.
  ///  9. Flutter navigates to EmployeeDetailsScreen — this is the "dashboard"
  ///     equivalent of the Angular app's /dashboard route.
  ///
  /// ⚠️  ACTION REQUIRED on Keycloak server:
  ///     Clients → dm-app → Settings → Valid Redirect URIs
  ///     Add:  com.example.mydemoproject://oauth2redirect
  /// ────────────────────────────────────────────────────────────────────────
  static const String _redirectUri = 'com.example.mydemoproject://oauth2redirect';

  // ─────────────────────────────────────────────────────────────────────────
  // SSO Login  (Authorization Code Grant + PKCE S256)
  // ─────────────────────────────────────────────────────────────────────────

  Future<EmployeeModel> loginWithSSO() async {
    try {
      if (kDebugMode) {
        print('══════════════════════════════════════════════════');
        print('🔑 SSO LOGIN STARTED');
        print('   Issuer      : $_issuer');
        print('   Client ID   : $_ssoClientId');
        print('   Redirect URI: $_redirectUri');
        print('   Scopes      : openid profile email');
        print('══════════════════════════════════════════════════');
      }

      // Steps 1–6: flutter_appauth opens Chrome Custom Tab, waits for redirect,
      // then exchanges the code for tokens automatically.
      final AuthorizationTokenResponse result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _ssoClientId,
          _redirectUri,
          issuer: _issuer,
          scopes: ['openid', 'profile', 'email'],
          // NOTE: Do NOT add 'response_mode: fragment' here.
          // AppAuth always uses query mode for native apps.
          // Fragment mode is only for browser-based implicit/hybrid flows.
        ),
      );

      if (kDebugMode) {
        print('✅ Token exchange successful');
        print('   Access token length  : ${result.accessToken?.length ?? 0}');
        print('   ID token present     : ${result.idToken != null}');
        print('   Refresh token present: ${result.refreshToken != null}');
        print('   Expires at           : ${result.accessTokenExpirationDateTime}');
      }

      final String accessToken = result.accessToken!;

      // Step 7: Decode id_token to get preferred_username (= employeeId)
      String employeeId = '';
      try {
        final Map<String, dynamic> claims =
            _decodeJwtPayload(result.idToken ?? accessToken);
        employeeId = claims['preferred_username']?.toString()
            ?? claims['sub']?.toString()
            ?? '';
        if (kDebugMode) {
          print('👤 Employee ID (preferred_username): $employeeId');
          print('   Name : ${claims['name']}');
          print('   Email: ${claims['email']}');
        }
      } catch (e) {
        if (kDebugMode) print('⚠️  JWT decode error: $e');
      }

      if (employeeId.isEmpty) {
        throw Exception('Could not extract employee ID from SSO token.');
      }

      // Step 8: Enroll device RSA key + fetch employee profile from Spring Boot
      if (kDebugMode) {
        print('🌐 Calling enroll-user API for employeeId: $employeeId');
      }

      final EmployeeModel employee = await EmployeeApiService.fetchEmployeeInfo(
        employeeId: employeeId,
        date: DateTime.now().toIso8601String().split('T').first,
        accessToken: accessToken,
      );

      // Step 9: Store token + employee globally; UI navigates to EmployeeDetailsScreen
      globals.setAuthData(accessToken, employee);

      if (kDebugMode) {
        print('🎉 SSO LOGIN COMPLETE');
        print('   Employee: ${employee.name} (${employee.userId})');
        print('══════════════════════════════════════════════════');
      }

      return employee;
    } catch (e) {
      if (kDebugMode) print('❌ SSO Login failed: $e');
      rethrow;
    }
  }

  /// Kept for backward compatibility — both buttons delegate to loginWithSSO.
  Future<EmployeeModel> login({String? userId, String? password}) =>
      loginWithSSO();

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Decodes the payload section of a JWT.
  /// (Signature verification happens server-side in Spring Boot via Keycloak keys.)
  Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid JWT: expected 3 dot-separated parts, got ${parts.length}');
    }
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Session management
  // ─────────────────────────────────────────────────────────────────────────

  void           logout()             => globals.clearAuthData();
  String?        getAccessToken()     => globals.accessToken;
  EmployeeModel? getCurrentEmployee() => globals.currentEmployee;
  bool           isLoggedIn()         => globals.isLoggedIn;
}
