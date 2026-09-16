import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/employee_model.dart';

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  /// Initializes the FlutterBackgroundService configuration at app startup.
  static Future<void> initialize() async {
    try {
      final service = FlutterBackgroundService();

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onBackgroundServiceStart,
          autoStart: false,
          autoStartOnBoot: false,
          isForegroundMode: true,
          initialNotificationTitle: '📍 Location Tracking Active',
          initialNotificationContent: 'Syncing employee location every 1 minute...',
          foregroundServiceNotificationId: 8888,
          foregroundServiceTypes: [AndroidForegroundType.location],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onBackgroundServiceStart,
          onBackground: onIosBackground,
        ),
      );

      if (kDebugMode) {
        print('🚀 [BackgroundLocationService] Service configured successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] Configure error: $e');
      }
    }
  }

  /// Request essential permissions without blocking tracking startup.
  static Future<void> requestPermissions() async {
    try {
      // 1. Notification permission (Android 13+)
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }

      // 2. Location permissions
      final locStatus = await Permission.location.status;
      if (!locStatus.isGranted) {
        await Permission.location.request();
      }

      // 3. Battery optimization exemption (SECONDARY PLAN: keeps CPU alive when screen is off)
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        if (kDebugMode) {
          print('🔋 Requesting battery optimization exemption...');
        }
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] Error requesting permissions: $e');
      }
    }
  }

  /// Starts the Android Foreground Service (WakeLock + Ongoing notification).
  /// This prevents Android from suspending the app process when screen turns off.
  static Future<void> startTracking(EmployeeModel? employee) async {
    if (employee == null) {
      return;
    }

    try {
      // Request permissions asynchronously in background so tracking starts instantly
      requestPermissions().catchError((e) {
        if (kDebugMode) {
          print('⚠️ [BackgroundLocationService] Permission request error: $e');
        }
      });

      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();

      if (!isRunning) {
        final started = await service.startService();
        if (kDebugMode) {
          print('🚀 [BackgroundLocationService] Foreground service started: $started');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] startTracking error: $e');
      }
    }
  }

  /// Updates the foreground notification text (called after each location sync).
  static Future<void> updateNotification({required String title, required String content}) async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('updateNotification', {
          'title': title,
          'content': content,
        });
      }
    } catch (_) {}
  }

  /// Stops the background tracking foreground service.
  static Future<void> stopTracking() async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
        if (kDebugMode) {
          print('⏹️ [BackgroundLocationService] Stop signal sent to background service.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [BackgroundLocationService] stopTracking error: $e');
      }
    }
  }
}

// ============================================================================
// BACKGROUND ISOLATE ENTRY POINT
// Holds the Android Foreground Service notification and WakeLock alive.
// ============================================================================

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Listen for stop request
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Listen for notification updates from LocationService
  service.on('updateNotification').listen((data) {
    if (service is AndroidServiceInstance && data != null) {
      service.setForegroundNotificationInfo(
        title: data['title']?.toString() ?? '📍 Location Tracking Active',
        content: data['content']?.toString() ?? 'Tracking active',
      );
    }
  });

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: '📍 Location Tracking Active',
      content: 'Syncing employee location every 1 minute',
    );
  }
}
