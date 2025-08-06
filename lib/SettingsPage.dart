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
        final hasPermission =
            await LocationPermissionService.requestLocationPermission(context);

        if (!hasPermission) {
          // If permission is not granted, do not proceed.
          debugPrint("Location permission denied");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for tracking'),
            ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
      _service.invoke(
        "stopService",
      ); // Use invoke to tell the service to stop itself
    }

    // Update preferences and UI state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTracking', false);

    setState(() {
      serviceRunning = false;
      isTracking = false;
    });
  }

  Future<void> _openGoogleMapDirections({
    required double lat,
    required double lng,
  }) async {
    final Uri googleMapUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
    );

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
      backgroundColor: Colors.grey[50],
      // appBar: AppBar(
      //   title: const Text("Foodyah Settings"),
      //   automaticallyImplyLeading: false, // Hides the back button
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.stop_circle_outlined),
      //       onPressed: _stopService,
      //       tooltip: 'Stop Background Service',
      //     ),
      //   ],
      // ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Note about location tracking moved to dashboard
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location Controls',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Location tracking controls are now available in the main dashboard for easier access.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // App Information Card
              Card(
                elevation: 4,
                shadowColor: Colors.deepOrange.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.orange.withOpacity(0.05)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.deepOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'App Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Version',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      '1.1.0',
                                      style: TextStyle(
                                        color: Colors.deepOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  // Launch privacy policy URL
                                  launchUrl(
                                    Uri.parse(
                                      'https://foodyah.com/privacy-policy',
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 4),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Terms of Service',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.deepOrange,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  // Launch terms of service URL
                                  launchUrl(
                                    Uri.parse(
                                      'https://foodyah.com/terms-of-service',
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Support Card
              Card(
                elevation: 4,
                shadowColor: Colors.deepOrange.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.green.withOpacity(0.05)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.support_agent,
                                color: Colors.green,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Support',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.headset_mic,
                                    color: Colors.blue,
                                  ),
                                ),
                                title: const Text(
                                  'Contact Support',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Get help with your account or deliveries',
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  // Launch support email or form
                                  launchUrl(
                                    Uri.parse('mailto:support@foodyah.com'),
                                  );
                                },
                              ),
                              const Divider(height: 24),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.bug_report,
                                    color: Colors.red,
                                  ),
                                ),
                                title: const Text(
                                  'Report an Issue',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Let us know if something isn\'t working',
                                ),
                                trailing: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  // Launch issue reporting form
                                  launchUrl(
                                    Uri.parse(
                                      'https://foodyah.com/report-issue',
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isCheckingPermission)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16.0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Checking permissions...",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.deepOrange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© ${DateTime.now().year} Foodyah. All rights reserved.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepOrange.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
