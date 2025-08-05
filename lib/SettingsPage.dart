import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Import the location permission service
import 'services/location_permission_service.dart';
import 'services/background_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
        title: const Text('Foodyah Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _stopService,
            tooltip: 'Stop Background Service',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Tracking Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.deepOrange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Location Tracking',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Control whether your location is being shared with the Foodyah platform',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      RadioListTile<bool>(
                        title: const Text('ON - Sending Location'),
                        subtitle: const Text('Your location will be shared with the platform'),
                        value: true,
                        groupValue: isTracking,
                        onChanged: _isCheckingPermission ? null : _toggleTracking,
                        activeColor: Colors.green,
                      ),
                      RadioListTile<bool>(
                        title: const Text('OFF - Not Sending Location'),
                        subtitle: const Text('Your location will not be shared'),
                        value: false,
                        groupValue: isTracking,
                        onChanged: _isCheckingPermission ? null : _toggleTracking,
                        activeColor: Colors.red,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: serviceRunning ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              serviceRunning ? Icons.check_circle : Icons.error,
                              color: serviceRunning ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
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
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // App Information Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.deepOrange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'App Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const ListTile(
                        title: Text('Version'),
                        trailing: Text('1.1.0'),
                        dense: true,
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        dense: true,
                        onTap: () {
                          // Launch privacy policy URL
                          launchUrl(Uri.parse('https://foodyah.com/privacy-policy'));
                        },
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Terms of Service'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        dense: true,
                        onTap: () {
                          // Launch terms of service URL
                          launchUrl(Uri.parse('https://foodyah.com/terms-of-service'));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Support Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.support_agent,
                            color: Colors.deepOrange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Support',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Contact Support'),
                        subtitle: const Text('Get help with your account or deliveries'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        dense: true,
                        onTap: () {
                          // Launch support email or form
                          launchUrl(Uri.parse('mailto:support@foodyah.com'));
                        },
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Report an Issue'),
                        subtitle: const Text('Let us know if something isn\'t working'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        dense: true,
                        onTap: () {
                          // Launch issue reporting form
                          launchUrl(Uri.parse('https://foodyah.com/report-issue'));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              if (_isCheckingPermission)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
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
              
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '© ${DateTime.now().year} Foodyah. All rights reserved.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
