import 'package:flutter/material.dart';
import 'screens/Landing_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(FoodyaApp());
}
class FoodyaApp extends StatelessWidget {
  const FoodyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foodya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const LandingPage(),
    );
  }
}
