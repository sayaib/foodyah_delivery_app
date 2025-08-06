import 'dart:async';
import 'dart:ui';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// Screens
import 'package:foodyah_delivery_app/screens/dashboard_page.dart';
import 'package:foodyah_delivery_app/screens/auth/otp_verification_page.dart';
import 'package:foodyah_delivery_app/screens/Landing_page.dart';
import 'SettingsPage.dart'; // Assuming it's moved to /screens//
import 'services/background_service.dart';
import 'services/tracking_status_service.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load once in main isolate

  // ✅ Save socket URL for background isolate
  final prefs = await SharedPreferences.getInstance();
  
  // Set Android-specific URL - use HTTPS for production, HTTP only for local development
  final isDebug = kDebugMode;
  final androidSocketUrl = isDebug 
      ? (dotenv.env['SOCKET_SERVER_URL_ANDROID'] ?? 'http://10.0.2.2:5050')
      : (dotenv.env['SOCKET_SERVER_URL_ANDROID_PROD'] ?? 'https://api.foodyah.com');
  
  await prefs.setString('SOCKET_SERVER_URL_ANDROID', androidSocketUrl);
  
  // Set iOS-specific URL - use HTTPS for production, HTTP only for local development
  final iosSocketUrl = isDebug
      ? (dotenv.env['SOCKET_SERVER_URL_IOS'] ?? 'http://localhost:5050')
      : (dotenv.env['SOCKET_SERVER_URL_IOS_PROD'] ?? 'https://api.foodyah.com');
      
  await prefs.setString('SOCKET_SERVER_URL_IOS', iosSocketUrl);
  
  // Set generic SOCKET_SERVER_URL based on platform
  await prefs.setString(
    'SOCKET_SERVER_URL',
    Platform.isAndroid ? androidSocketUrl : iosSocketUrl,
  );

  await initializeService();

  // Initialize the TrackingStatusService
  await TrackingStatusService().initialize();

  final storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');

  runApp(FoodyaApp(isLoggedIn: token != null));
}

class FoodyaApp extends StatefulWidget {
  final bool isLoggedIn;

  const FoodyaApp({super.key, required this.isLoggedIn});

  @override
  State<FoodyaApp> createState() => _FoodyaAppState();
}

class _FoodyaAppState extends State<FoodyaApp> with WidgetsBindingObserver {
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final TrackingStatusService _trackingStatusService = TrackingStatusService();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndResetTrackingStatus();
  }
  
  Future<void> _checkAndResetTrackingStatus() async {
    // When app starts, check if we need to reset tracking status
    final prefs = await SharedPreferences.getInstance();
    final wasTracking = prefs.getBool('isTracking') ?? false;
    
    if (wasTracking) {
      // If tracking was on when app was closed, reset it to off
      await prefs.setBool('isTracking', false);
      await _trackingStatusService.updateTrackingStatus(false);
      debugPrint('App restarted: Reset tracking status to offline');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.detached) {
      // App is fully closed (terminated)
      _setOfflineStatus();
    }
  }

  Future<void> _setOfflineStatus() async {
    // Set tracking status to false in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTracking', false);
    
    // Update tracking status service
    await _trackingStatusService.updateTrackingStatus(false);
    
    // Stop location tracking in background service
    _service.invoke("stopLocationTracking");
    
    // Stop the background service
    _service.invoke("stopService");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foodya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      initialRoute: widget.isLoggedIn ? '/dashboard' : '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/otp': (context) => const OTPVerificationPage(type: '', value: ''),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

