import 'package:flutter/foundation.dart';
import 'models/employee_model.dart';

/// Global variables - accessible from anywhere in the app
class GlobalConfig {
  //live configuration
/*  static const String baseUrl = 'https://api.diu.edu.bd';
  static const String _keycloakBaseUrl = 'https://auth0.diu.edu.bd';
  static const String _realm = 'diu';
  static const String _clientId = 'dm-app';
  static const String _issuer = '$_keycloakBaseUrl/realms/$_realm';
  static const String _redirectUri = 'com.example.mydemoproject://oauth2redirect';
  */

  //local configuration
  static const String baseUrl = 'http://192.168.90.9:7014';
  static const String keycloakBaseUrl = 'https://auth0.diu.edu.bd';
  static const String realm = 'demo';
  static const String clientId = 'ess-portal-ui';
  static const String issuer = '$keycloakBaseUrl/realms/$realm';
  static const String redirectUri = 'com.example.mydemoproject://oauth2redirect';

  static final GlobalConfig _instance = GlobalConfig._internal();
  factory GlobalConfig() => _instance;
  GlobalConfig._internal();

  // Global variables
  String? accessToken;          // JWT token
  EmployeeModel? currentEmployee;  // Employee data
  bool isLoggedIn = false;

  // Helper methods
  void setAuthData(String token, EmployeeModel employee) {
    accessToken = token;
    currentEmployee = employee;
    isLoggedIn = true;

    if (kDebugMode) {
      print('✅ Auth data set globally');
      print('   Token: ${token.substring(0, 20)}...');
      print('   Employee: ${employee.name} (${employee.userId})');
    }
  }

  void clearAuthData() {
    accessToken = null;
    currentEmployee = null;
    isLoggedIn = false;

    if (kDebugMode) {
      print('✅ Auth data cleared');
    }
  }

  // Get employee ID easily
  String? get employeeId => currentEmployee?.userId;
  // Check if token exists
  bool get hasToken => accessToken != null && accessToken!.isNotEmpty;
}

// Create a single instance to use everywhere
final globals = GlobalConfig();