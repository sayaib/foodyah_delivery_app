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

  // Define the notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_channel',
    'Location Tracking',
    description: 'Used for tracking background location',
    importance: Importance.low, // Use low importance to make it less intrusive
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false, // Must be false to prevent auto-start on boot
      notificationChannelId: 'location_channel',
      initialNotificationTitle: 'Delivery Service',
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
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final socketUrl =
      prefs.getString('SOCKET_SERVER_URL') ?? 'http://127.0.0.1:5050';
  final notification = FlutterLocalNotificationsPlugin();
  Timer? locationTimer;
  bool isTracking = prefs.getBool('isTracking') ?? false;

  final socket = IO.io(socketUrl, <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false, // Connect manually
  });

  // --- Socket Event Listeners for Debugging ---
  socket.onConnect((_) => debugPrint('✅ SOCKET: Connected'));
  socket.onDisconnect((_) => debugPrint('❌ SOCKET: Disconnected'));
  socket.onError((data) => debugPrint('SOCKET ERROR: $data'));

  // --- FIXED: Added listener for new delivery requests ---
  socket.on('new_delivery_request', (data) {
    _handleDeliveryRequest(data, service);
  });

  socket.connect();

  // --- Service Command Listeners from UI ---
  service.on('startLocationTracking').listen((event) {
    isTracking = true;
    prefs.setBool('isTracking', true);
    debugPrint("📍 BG_SERVICE: Start location tracking command received.");
  });

  service.on('stopLocationTracking').listen((event) {
    isTracking = false;
    prefs.setBool('isTracking', false);
    debugPrint("🛑 BG_SERVICE: Stop location tracking command received.");
  });

  // FIXED: Added a graceful stop mechanism
  service.on('stopService').listen((event) async {
    isTracking = false;
    await prefs.setBool('isTracking', false);
    locationTimer?.cancel();
    socket.disconnect();
    await service.stopSelf();
    debugPrint("🛑 BG_SERVICE: Service has been stopped.");
  });

  // --- Main Location Sending Logic ---
  locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (!isTracking) {
      // If tracking is off, do nothing.
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        forceAndroidLocationManager: true, // Recommended for background
      );

      final driverId = prefs.getString('driverId') ?? 'driver_007';

      // FIXED: Implemented the missing location emit logic
      if (socket.connected) {
        socket.emit('updateLocation', {
          'driverId': driverId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
        debugPrint(
            '📍 BG_SERVICE: Location sent: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint('⚠️ BG_SERVICE: Cannot send location, socket not connected.');
      }
    } catch (e) {
      debugPrint('BG_SERVICE: Error getting/sending location: $e');
    }

    // Update the notification to show the service is active
    notification.show(
      888,
      'Delivery Service',
      'Tracking location in background... ${DateTime.now()}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'location_channel',
          'Location Tracking',
          icon: '@mipmap/ic_launcher',
          ongoing: true,
        ),
      ),
    );
  });
}

// FIXED: This function now correctly invokes the UI to show a dialog.
void _handleDeliveryRequest(dynamic data, ServiceInstance service) {
  debugPrint(
      "📦 BG_SERVICE: Delivery request received: ${data['restaurantName'] ?? 'Unknown'}");

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