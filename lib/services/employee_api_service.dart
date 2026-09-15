// lib/services/employee_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../global_config.dart';
import '../models/employee_model.dart';
import 'security_service.dart';

class EmployeeApiService {

  static const String baseUrl = GlobalConfig.baseUrl;
  static const String employeeInfoEndpoint = '/api/geoportal/geo-location/enroll-user';
  EmployeeModel? employee;

  /// Fetch employee basic info from Spring Boot API and enroll device with RSA Key Pair
  Future<EmployeeModel> fetchEmployeeInfo({required String employeeId, required String date,required String accessToken,
  })
  async {

    try {
      final securityService = SecurityService();
      final String publicRsa = await securityService.getOrCreateDevicePublicKey();
      if (kDebugMode) {
        print('🔑 Using RSA Public Key for enrollment: ${publicRsa.substring(0, 30)}...');
      }

      // Step 2: Prepare body and RSA signature for enrollment
      final Map<String, dynamic> requestPayload = {
        'employeeId': employeeId,
        'publicRsa': publicRsa,
        'accessToken': accessToken,
      };

      final String jsonBody = jsonEncode(requestPayload);
      final String canonicalPayload = '$employeeId|$publicRsa';
      final String? signature = await securityService.signPayload(canonicalPayload);
      final Uri uri = Uri.parse('$baseUrl$employeeInfoEndpoint');
      if (kDebugMode) {
        print('🌐 Calling Enroll-User API (POST): $uri');
        print('📦 Payload: $jsonBody');
      }

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      if (signature != null && signature.isNotEmpty) {
        headers['X-Signature'] = signature;
      }

      final response = await http.post(uri,
        headers: headers,
        body: jsonBody,
      );

      if (kDebugMode) {
        print('📡 Enroll-User API Status: ${response.statusCode}');
        print('📡 Enroll-User API Response: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final dynamic data = responseBody['data'];
        final Map<String, dynamic> employeeData = (data is Map<String, dynamic>) ? Map<String, dynamic>.from(data) : responseBody;

        employeeData['employeeId'] = employeeData['employeeId'] ?? employeeData['employee_id'] ?? employeeId;
        employeeData['token'] = accessToken;
        employee = EmployeeModel.fromJson(employeeData);
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

final employeeApiService = EmployeeApiService();


