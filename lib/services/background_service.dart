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
import 'dart:io' show Platform;

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
  final notification = FlutterLocalNotificationsPlugin();

  // --- Use a StreamSubscription instead of a Timer ---
  StreamSubscription<Position>? locationSubscription;

  // Get the appropriate socket URL based on platform
  final socketUrl = Platform.isAndroid
      ? prefs.getString('SOCKET_SERVER_URL_ANDROID') ?? 'http://10.0.2.2:5050'
      : prefs.getString('SOCKET_SERVER_URL_IOS') ?? 'http://localhost:5050';

  final socket = IO.io(socketUrl, <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
  });

  socket.onConnect((_) => debugPrint('✅ SOCKET: Connected'));
  socket.onDisconnect((_) => debugPrint('❌ SOCKET: Disconnected'));
  socket.onError((data) => debugPrint('SOCKET ERROR: $data'));
  socket.on('new_delivery_request', (data) {
    _handleDeliveryRequest(data, service);
  });

  socket.connect();

  // Function to start listening to location updates
  void startLocationStream() {
    // If already listening, do nothing
    if (locationSubscription != null) return;

    final locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
            forceLocationManager: true,
            intervalDuration: const Duration(seconds: 10), // Update every 10s
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.automotiveNavigation,
            distanceFilter: 10, // Update every 10 meters
            pauseLocationUpdatesAutomatically: true,
            // IMPORTANT: These allow background updates on iOS
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );

    locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
          final driverId = prefs.getString('driverId') ?? 'driver_007';

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

          // Update notification on both platforms
          notification.show(
            888,
            'Delivery Service Active',
            'Tracking... Last update: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'location_channel',
                'Location Tracking',
                icon: '@mipmap/ic_launcher',
                ongoing: true,
              ),
            ),
          );
        }, onError: (error) {
          debugPrint('BG_SERVICE: Error in location stream: $error');
          locationSubscription?.cancel();
          locationSubscription = null;
        });
  }

  // Check initial tracking status and start stream if needed
  if (prefs.getBool('isTracking') ?? false) {
    startLocationStream();
  }

  service.on('startLocationTracking').listen((event) {
    prefs.setBool('isTracking', true);
    startLocationStream(); // Start the stream
    debugPrint("📍 BG_SERVICE: Start location tracking command received.");
  });

  service.on('stopLocationTracking').listen((event) {
    prefs.setBool('isTracking', false);
    locationSubscription?.cancel(); // Stop the stream
    locationSubscription = null;
    debugPrint("🛑 BG_SERVICE: Stop location tracking command received.");
  });

  service.on('stopService').listen((event) async {
    await prefs.setBool('isTracking', false);
    locationSubscription?.cancel(); // Stop the stream
    locationSubscription = null;
    socket.disconnect();
    await service.stopSelf();
    debugPrint("🛑 BG_SERVICE: Service has been stopped.");
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