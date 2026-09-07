import 'package:flutter/foundation.dart';
import 'models/employee_model.dart';

/// Global variables - accessible from anywhere in the app
class AppGlobals {
  // Singleton pattern
  static const String baseUrl = 'https://api.diu.edu.bd';
      //'http://192.168.90.9:7014';
  static final AppGlobals _instance = AppGlobals._internal();
  factory AppGlobals() => _instance;
  AppGlobals._internal();

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
final globals = AppGlobals();