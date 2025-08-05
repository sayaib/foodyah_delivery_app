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
import 'package:foodyah_delivery_app/screens/DashboardPage.dart';
import 'package:foodyah_delivery_app/screens/auth/otp_verification_page.dart';
import 'package:foodyah_delivery_app/screens/Landing_page.dart';
import 'SettingsPage.dart'; // Assuming it's moved to /screens//
import 'services/background_service.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // Load once in main isolate

  // ✅ Save socket URL for background isolate
  final prefs = await SharedPreferences.getInstance();
  
  // Set Android-specific URL
  await prefs.setString(
    'SOCKET_SERVER_URL_ANDROID',
    dotenv.env['SOCKET_SERVER_URL_ANDROID'] ?? 'http://10.0.2.2:5050',
  );
  
  // Set iOS-specific URL
  await prefs.setString(
    'SOCKET_SERVER_URL_IOS',
    dotenv.env['SOCKET_SERVER_URL_IOS'] ?? 'http://localhost:5050',
  );
  
  // Set generic SOCKET_SERVER_URL based on platform
  await prefs.setString(
    'SOCKET_SERVER_URL',
    Platform.isAndroid 
      ? (dotenv.env['SOCKET_SERVER_URL_ANDROID'] ?? 'http://10.0.2.2:5050')
      : (dotenv.env['SOCKET_SERVER_URL_IOS'] ?? 'http://localhost:5050'),
  );

  await initializeService();


  final storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');

  runApp(FoodyaApp(isLoggedIn: token != null));
}

class FoodyaApp extends StatelessWidget {
  final bool isLoggedIn;

  const FoodyaApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foodya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      initialRoute: isLoggedIn ? '/dashboard' : '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/otp': (context) => const OTPVerificationPage(type: '', value: ''),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

