
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_global.dart';
import '../models/employee_model.dart';
import '../services/employee_api_service.dart';


class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String realm = 'demo';
  static const String tokenUrl = 'https://auth0.diu.edu.bd/realms/$realm/protocol/openid-connect/token';

  /// Login with SSO
  Future<EmployeeModel> login({
    required String userId,
    required String password,
  }) async {
    final usernameInput = userId.trim();
    final passwordInput = password.trim();

    if (usernameInput.isEmpty || passwordInput.isEmpty) {
      throw Exception('Please enter valid Employee ID and Password');
    }

    try {
      // Step 1: Get JWT token from Keycloak
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': usernameInput,
          'password': passwordInput,
          'client_id': 'ess-portal-ui',
          'grant_type': 'password',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to authenticate');
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      final String accessToken = responseBody['access_token']?.toString() ?? '';

      // Step 2: Fetch employee info from Spring Boot
      final EmployeeModel employee = await EmployeeApiService.fetchEmployeeInfo(
        employeeId: usernameInput,
        date: DateTime.now().toIso8601String().split('T').first,
        accessToken: accessToken,
      );

      // Step 3: Store in global variables
      globals.setAuthData(accessToken, employee);

      return employee;
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      rethrow;
    }
  }

  /// Logout - clear global variables
  void logout() {
    globals.clearAuthData();
  }

  /// Get current token (just returns from globals)
  String? getAccessToken() {
    return globals.accessToken;
  }

  /// Get current employee (just returns from globals)
  EmployeeModel? getCurrentEmployee() {
    return globals.currentEmployee;
  }

  /// Check if logged in
  bool isLoggedIn() {
    return globals.isLoggedIn;
  }
}
