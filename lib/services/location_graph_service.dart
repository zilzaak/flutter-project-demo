// lib/services/location_graph_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_global.dart';
import '../models/location_graph_model.dart';
import 'employee_api_service.dart';

class LocationGraphService {
  static const String endpoint = '/api/ess/portal/employee-duty-monitoring/my-location-graph';

  /// Fetch today's logged-in employee location graph from Spring Boot API
  static Future<LocationGraphData> fetchMyLocationGraph({String? token}) async {
    final authToken = token ?? globals.accessToken;

    if (authToken == null || authToken.isEmpty) {
      throw Exception('User is not authenticated. Access token is missing.');
    }

    final String baseUrl = EmployeeApiService.baseUrl;
    final Uri uri = Uri.parse('$baseUrl$endpoint');

    if (kDebugMode) {
      print('🌐 Calling Location Graph API: $uri');
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('📡 Location Graph API Status: ${response.statusCode}');
        print('📡 Response Body: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        final bool status = jsonResponse['status'] == true;
        if (!status && jsonResponse.containsKey('message')) {
          throw Exception(jsonResponse['message'] ?? 'Failed to retrieve location points.');
        }

        final dynamic data = jsonResponse['data'];
        if (data == null) {
          return const LocationGraphData(locationPoints: []);
        }

        return LocationGraphData.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw Exception('Server returned error code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ LocationGraphService Error: $e');
      }
      rethrow;
    }
  }
}
