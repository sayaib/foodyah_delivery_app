// lib/services/background_service.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;



@pragma('vm:entry-point')
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_channel',
    'Location Tracking',
    description: 'Used for tracking background location',
    importance: Importance.low,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
      notificationChannelId: 'location_channel',
      initialNotificationTitle: 'Location Service',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final socketUrl = prefs.getString('SOCKET_SERVER_URL_ANDROID') ?? 'http://10.0.2.2:5050';
  final notification = FlutterLocalNotificationsPlugin();

  final socket = IO.io(socketUrl, {
    'transports': ['websocket'],
    'autoConnect': true,
  });

  socket.connect();

  // Initially, do not track location
  bool isTracking = false;

  // Receive signal to start tracking
  service.on('startLocationTracking').listen((event) {
    isTracking = true;
    debugPrint("📍 Start location tracking command received.");
  });

  socket.on("delivery_request", (data) {
    _handleDeliveryRequest(data, service);
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (!isTracking) return; // Do not send location if not tracking

    if (!(await Geolocator.isLocationServiceEnabled())) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      final lat = position.latitude;
      final lon = position.longitude;
      final now = DateTime.now().toIso8601String();

      socket.emit('location', {"lat": lat, "lon": lon, "time": now});
      debugPrint("📤 Location sent: $lat, $lon");

      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        notification.show(
          888,
          "Location Update",
          "Lat: $lat, Lon: $lon",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'location_channel',
              'Location Tracking',
              icon: '@mipmap/ic_launcher',
              ongoing: true,
            ),
          ),
        );
      }

      final logs = prefs.getStringList('logs') ?? [];
      logs.add("[$now] -> $lat, $lon");
      await prefs.setStringList('logs', logs);
    } catch (e) {
      debugPrint("❌ Location Error: $e");
    }
  });
}

// void _handleDeliveryRequest(dynamic data) {
//   print("📦 Delivery request received: ${data['restaurantName'] ?? 'Unknown'}");
//   // deliveryRequestNotifier.value = data;
//
// }
// MODIFIED: This function now accepts the service instance
void _handleDeliveryRequest(dynamic data, ServiceInstance service) {
  print("📦 Delivery request received: ${data['restaurantName'] ?? 'Unknown'}");

  // This sends a message to the UI thread.
  // We use a key ('showDialog') to identify the event and pass the data.
  service.invoke(
    'showDialog',
    {
      "title": "New Delivery Request!",
      "body": "From ${data['restaurantName'] ?? 'Unknown Restaurant'}",
    },
  );
}
