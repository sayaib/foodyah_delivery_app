// lib/order_in_progress_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderInProgressPage extends StatefulWidget {
  const OrderInProgressPage({Key? key}) : super(key: key);

  @override
  State<OrderInProgressPage> createState() => _OrderInProgressPageState();
}

class _OrderInProgressPageState extends State<OrderInProgressPage> {
  bool isTracking = false;
  bool serviceRunning = false;
  final FlutterBackgroundService _service = FlutterBackgroundService();

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupServiceListener();
  }

  // MODIFIED: Added a listener to handle events from the background service
  void _setupServiceListener() {
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

  // FIXED: Corrected the logic for toggling tracking.
  Future<void> _toggleTracking(bool? value) async {
    if (value == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTracking', value);

    if (value) {
      // If turning ON
      if (!serviceRunning) {
        await _service.startService();
        setState(() => serviceRunning = true);
      }
      _service.invoke("startLocationTracking");
      debugPrint("UI: Invoked startLocationTracking");
    } else {
      // If turning OFF
      _service.invoke("stopLocationTracking");
      debugPrint("UI: Invoked stopLocationTracking");
    }
    setState(() => isTracking = value);
  }

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

  // FIXED: The URL for Google Maps was incorrect.
  Future<void> _openGoogleMapDirections(
      {required double lat, required double lng}) async {
    // This is the correct, standard URL format for Google Maps directions
    final Uri googleMapUrl =
    Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

    if (!await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication)) {
      // Consider showing a snackbar or dialog on failure
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
                      onChanged: _toggleTracking,
                      activeColor: Colors.green,
                    ),
                    RadioListTile<bool>(
                      title: const Text('OFF - Not Sending Location'),
                      value: false,
                      groupValue: isTracking,
                      onChanged: _toggleTracking,
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
          // Example coordinates for Kolkata, India
          _openGoogleMapDirections(lat: 22.5726, lng: 88.3639);
        },
      ),
    );
  }
}