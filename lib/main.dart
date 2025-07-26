import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodyah_delivery_app/screens/DashboardPage.dart';
import 'package:foodyah_delivery_app/screens/auth/otp_verification_page.dart';
import 'screens/Landing_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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
        '/otp': (context) => const OTPVerificationPage(type: '', value: ''), // default dummy; real one passed with Navigator
      },
    );
  }
}

