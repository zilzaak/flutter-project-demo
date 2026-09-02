// lib/services/employee_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_global.dart';
import '../models/employee_model.dart';
import 'security_service.dart';

class EmployeeApiService {
  static const String baseUrl = AppGlobals.baseUrl;
  static const String employeeInfoEndpoint = '/api/ess/portal/employee-duty-monitoring/enroll-user';

  /// Fetch employee basic info from Spring Boot API and enroll device with RSA Key Pair
  static Future<EmployeeModel> fetchEmployeeInfo({
    required String employeeId,
    required String date,
    required String accessToken,
  }) async {
    try {
      final securityService = SecurityService();
      // Step 1: Retrieve existing device public key or generate & store a new key pair once
      final String publicRsa = await securityService.getOrCreateDevicePublicKey();

      if (kDebugMode) {
        print('🔑 Using RSA Public Key for enrollment: ${publicRsa.substring(0, 30)}...');
      }

      // Step 2: Call enroll-user API with the persistent public RSA key
      final Uri uri = Uri.parse(
        '$baseUrl$employeeInfoEndpoint'
        '?employeeId=${Uri.encodeComponent(employeeId)}'
        '&date=${Uri.encodeComponent(date)}'
        '&publicRsa=${Uri.encodeComponent(publicRsa)}',
      );

      if (kDebugMode) {
        print('🌐 Calling Enroll-User API: $uri');
      }

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (kDebugMode) {
        print('📡 Enroll-User API Status: ${response.statusCode}');
        print('📡 Enroll-User API Response: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final dynamic data = responseBody['data'];
        final Map<String, dynamic> employeeData = (data is Map<String, dynamic>)
            ? Map<String, dynamic>.from(data)
            : responseBody;

        employeeData['employeeId'] = employeeData['employeeId'] ?? employeeData['employee_id'] ?? employeeId;
        employeeData['token'] = accessToken;
        return EmployeeModel.fromJson(employeeData);
      } else {
        throw Exception('Failed to fetch employee info: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Employee API Error: $e');
      }
      rethrow;
    }
  }
}