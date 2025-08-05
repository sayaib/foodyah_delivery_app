// lib/order_in_progress_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Import the new permission service
import 'package:foodyah_delivery_app/services/location_permission_service.dart'; // Update with your project name

class OrderInProgressPage extends StatefulWidget {
  const OrderInProgressPage({Key? key}) : super(key: key);

  @override
  State<OrderInProgressPage> createState() => _OrderInProgressPageState();
}

class _OrderInProgressPageState extends State<OrderInProgressPage> {
  bool isTracking = false;
  bool serviceRunning = false;
  bool _isCheckingPermission = false;
  final FlutterBackgroundService _service = FlutterBackgroundService();

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupServiceListener();
  }

  void _setupServiceListener() {
    // ... (This part remains the same as the previous fix)
    _service.on('showDialog').listen((event) {
      if (event != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(event['title'] ?? 'Notification'),
            content: Text(event['body'] ?? 'You have a new message.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _initialize() async {
    await _loadTrackingStatus();
    await _checkServiceStatus();
  }

  Future<void> _loadTrackingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => isTracking = prefs.getBool('isTracking') ?? false);
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await _service.isRunning();
    setState(() => serviceRunning = isRunning);
  }

  // MODIFIED: Integrated the permission flow with improved iOS handling.
  Future<void> _toggleTracking(bool? value) async {
    if (value == null) return;
    setState(() {
      _isCheckingPermission = true;
    });
    try {
      if (value) {
        // If turning ON, first request permission.
        debugPrint("Requesting location permission...");
        final hasPermission = await LocationPermissionService
            .requestLocationPermission(context);

        if (!hasPermission) {
          // If permission is not granted, do not proceed.
          // The UI will not change to "ON".
          debugPrint("Location permission denied");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required for tracking')),
          );
          return;
        }

        debugPrint("Location permission granted, starting service...");
        // If permission is granted, proceed to start the service and tracking
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isTracking', true);

        if (!serviceRunning) {
          debugPrint("Starting background service...");
          await _service.startService();
          // Wait a moment for the service to fully start
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() => serviceRunning = true);
        }
        
        debugPrint("Invoking startLocationTracking...");
        _service.invoke("startLocationTracking");
        setState(() => isTracking = true);
      } else {
        // If turning OFF, no permission needed. Just stop.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isTracking', false);
        _service.invoke("stopLocationTracking");
        debugPrint("UI: Invoked stopLocationTracking");
        setState(() => isTracking = false);
      }
    } catch (e) {
      debugPrint("Error toggling tracking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  // (The rest of the file: _stopService, _openGoogleMapDirections, build method remains the same)
  // ...
  Future<void> _stopService() async {
    // Stop tracking within the service first
    _service.invoke("stopLocationTracking");

    // Then, stop the entire service itself
    if (await _service.isRunning()) {
      _service.invoke("stopService"); // Use invoke to tell the service to stop itself
    }

    // Update preferences and UI state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTracking', false);

    setState(() {
      serviceRunning = false;
      isTracking = false;
    });
  }

  Future<void> _openGoogleMapDirections(
      {required double lat, required double lng}) async {
    final Uri googleMapUrl =
    Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

    if (!await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch Google Maps.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        title: const Text('Location Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _stopService,
            tooltip: 'Stop Background Service',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location Tracking Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RadioListTile<bool>(
                      title: const Text('ON - Sending Location'),
                      value: true,
                      groupValue: isTracking,
                      onChanged: _isCheckingPermission ? null : _toggleTracking,
                      activeColor: Colors.green,
                    ),
                    RadioListTile<bool>(
                      title: const Text('OFF - Not Sending Location'),
                      value: false,
                      groupValue: isTracking,
                      onChanged: _isCheckingPermission ? null : _toggleTracking,
                      activeColor: Colors.red,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      serviceRunning
                          ? 'Background service is RUNNING'
                          : 'Background service is STOPPED',
                      style: TextStyle(
                        color: serviceRunning ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isCheckingPermission)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    SizedBox(width: 10),
                    Text("Checking permissions..."),
                  ],
                ),
              ),
            Text(
              serviceRunning
                  ? 'Background service is RUNNING'
                  : 'Background service is STOPPED',
              // (The rest of the widget build remains the same)
              // ...
            ),
            const Expanded(
              child: Center(
                  child: Text(
                    "Delivery Content Goes Here",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  )),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.directions),
        label: const Text("Get Directions"),
        onPressed: () {
          _openGoogleMapDirections(lat: 22.5726, lng: 88.3639);
        },
      ),
    );
  }
}