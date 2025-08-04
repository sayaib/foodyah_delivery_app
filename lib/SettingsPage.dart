import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'services/background_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _checkAndStartService();
  }

  Future<void> _checkAndStartService() async {
    // await initializeService();

    final service = FlutterBackgroundService();
    bool running = await service.isRunning();

    if (!running) {
      await service.startService();
      running = true;
    }

    setState(() {
      isServiceRunning = running;
    });
  }

  Future<void> _toggleService() async {
    final service = FlutterBackgroundService();
    bool running = await service.isRunning();

    if (running) {
      service.invoke("stopService"); // No await or assignment
      setState(() {
        isServiceRunning = false;
      });
    } else {
      await service.startService();
      setState(() {
        isServiceRunning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Foodya Home"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isServiceRunning ? Icons.play_circle : Icons.pause_circle,
              color: isServiceRunning ? Colors.green : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isServiceRunning
                  ? "Background Service is Running"
                  : "Background Service is Stopped",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleService,
              child: Text(isServiceRunning ? "Stop Service" : "Start Service"),
            ),
          ],
        ),
      ),
    );
  }
}
