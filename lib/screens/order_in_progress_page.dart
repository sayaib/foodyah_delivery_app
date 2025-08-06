// lib/order_in_progress_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import the services
import 'package:foodyah_delivery_app/services/location_permission_service.dart';
import 'package:foodyah_delivery_app/services/tracking_status_service.dart';

class OrderInProgressPage extends StatefulWidget {
  const OrderInProgressPage({super.key});

  @override
  State<OrderInProgressPage> createState() => _OrderInProgressPageState();
}

class _OrderInProgressPageState extends State<OrderInProgressPage> {
  bool isTracking = false;
  bool serviceRunning = false;
  bool _isCheckingPermission = false;
  bool _showNewOrderPopup = false;
  Map<String, dynamic> _orderData = {};
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final _storage = const FlutterSecureStorage();
  String _driverId = "";
  final TrackingStatusService _trackingStatusService = TrackingStatusService();

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupServiceListener();
    _loadDriverId();
    
    // Force refresh tracking status when page initializes
    _forceRefreshTrackingStatus();

    // Listen to tracking status changes
    _trackingStatusService.trackingStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          isTracking = status;
          debugPrint(
            'OrderInProgressPage: isTracking updated from stream to $isTracking',
          );
        });
      }
    });

    // Listen to service running status changes
    _trackingStatusService.serviceRunningStream.listen((status) {
      if (mounted) {
        setState(() {
          serviceRunning = status;
          debugPrint(
            'OrderInProgressPage: serviceRunning updated from stream to $serviceRunning',
          );
        });
      }
    });
  }
  
  Future<void> _forceRefreshTrackingStatus() async {
    // This ensures the UI shows the correct tracking status when the app is reopened
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getBool('isTracking') ?? false;
    
    // Update both local state and service
    if (mounted) {
      setState(() {
        isTracking = status;
        debugPrint('OrderInProgressPage: Force refreshed tracking status to $isTracking');
      });
    }
    
    // Also check if service is actually running
    final isRunning = await _service.isRunning();
    if (mounted) {
      setState(() {
        serviceRunning = isRunning;
        debugPrint('OrderInProgressPage: Force refreshed service status to $serviceRunning');
      });
    }
    
    // Update tracking status service
    await _trackingStatusService.updateTrackingStatus(status);
    _trackingStatusService.updateServiceRunningStatus(isRunning);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh status when page becomes visible
    _loadTrackingStatus();
    _checkServiceStatus();
    debugPrint(
      'OrderInProgressPage: didChangeDependencies called, refreshing status',
    );
  }

  @override
  void didUpdateWidget(OrderInProgressPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh status when widget updates
    _loadTrackingStatus();
    _checkServiceStatus();
  }

  Future<void> _loadDriverId() async {
    final id = await _storage.read(key: 'user_id') ?? 'driver_007';
    setState(() {
      _driverId = id;
    });
  }

  void _setupServiceListener() {
    _service.on('showDialog').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _showNewOrderPopup = true;
          _orderData = event;
        });
      }
    });
  }

  Future<void> _initialize() async {
    await _loadTrackingStatus();
    await _checkServiceStatus();
  }

  Future<void> _loadTrackingStatus() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getBool('isTracking') ?? false;
    setState(() {
      isTracking = status;
      debugPrint('OrderInProgressPage: isTracking updated to $isTracking');
    });
  }

  // Add a timestamp to track when we last checked the service status
  DateTime _lastServiceCheck = DateTime.now().subtract(
    const Duration(seconds: 1),
  );

  Future<void> _checkServiceStatus() async {
    if (!mounted) return;

    // Debounce the service status check to prevent too many calls
    final now = DateTime.now();
    if (now.difference(_lastServiceCheck).inMilliseconds < 300) {
      return; // Skip if we checked too recently
    }
    _lastServiceCheck = now;

    final isRunning = await _service.isRunning();
    if (mounted && serviceRunning != isRunning) {
      setState(() {
        serviceRunning = isRunning;
        debugPrint(
          'OrderInProgressPage: serviceRunning updated to $serviceRunning',
        );
      });
      // Update the service running status in the tracking status service
      _trackingStatusService.updateServiceRunningStatus(isRunning);
    }
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
        final hasPermission =
            await LocationPermissionService.requestLocationPermission(context);

        if (!hasPermission) {
          // If permission is not granted, do not proceed.
          // The UI will not change to "ON".
          debugPrint("Location permission denied");
          if (!mounted) return;
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

        // Update tracking status service
        await _trackingStatusService.updateTrackingStatus(true);

        // Save driver ID to shared preferences for background service
        await prefs.setString('driverId', _driverId);

        if (!serviceRunning) {
          debugPrint("Starting background service...");
          await _service.startService();
          // Wait a moment for the service to fully start
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() => serviceRunning = true);
          // Update the service running status in the tracking status service
          _trackingStatusService.updateServiceRunningStatus(true);
        }

        debugPrint("Invoking startLocationTracking...");
        _service.invoke("startLocationTracking");
        setState(() => isTracking = true);
      } else {
        // If turning OFF, no permission needed. Just stop.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isTracking', false);

        // Update tracking status service
        await _trackingStatusService.updateTrackingStatus(false);
        _service.invoke("stopLocationTracking");
        debugPrint("UI: Invoked stopLocationTracking");
        setState(() => isTracking = false);
      }
    } catch (e) {
      debugPrint("Error toggling tracking: $e");
      if (!mounted) return;
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

  // (The rest of the file: _stopService, _openGoogleMapDirections, build method remains the same)
  // ...
  Future<void> _stopService() async {
    // Stop tracking within the service first
    _service.invoke("stopLocationTracking");

    // Then, stop the entire service itself
    if (await _service.isRunning()) {
      _service.invoke(
        "stopService",
      ); // Use invoke to tell the service to stop itself

      // Update the service running status in the tracking status service
      setState(() => serviceRunning = false);
      _trackingStatusService.updateServiceRunningStatus(false);
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

  void _acceptOrder() async {
    // Save the order data if needed
    final prefs = await SharedPreferences.getInstance();

    // Store order information in SharedPreferences for persistence
    if (_orderData['orderId'] != null) {
      await prefs.setString('currentOrderId', _orderData['orderId']);
    }
    if (_orderData['restaurantName'] != null) {
      await prefs.setString(
        'currentRestaurantName',
        _orderData['restaurantName'],
      );
    }
    if (_orderData['restaurantAddress'] != null) {
      await prefs.setString(
        'currentRestaurantAddress',
        _orderData['restaurantAddress'],
      );
    }
    if (_orderData['customerAddress'] != null) {
      await prefs.setString(
        'currentCustomerAddress',
        _orderData['customerAddress'],
      );
    }

    // Start location tracking if not already started
    if (!isTracking) {
      _toggleTracking(true);
    } else {
      // If tracking is already on, just make sure driver ID is set
      await prefs.setString('driverId', _driverId);
    }

    // Signal background to start emitting location with driver ID and order info
    _service.invoke("startLocationTracking", _orderData);

    setState(() {
      _showNewOrderPopup = false;
    });

    // Show confirmation to user
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order accepted! Starting delivery tracking.'),
      ),
    );
  }

  void _rejectOrder() {
    setState(() {
      _showNewOrderPopup = false;
    });

    // Show confirmation to user
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order rejected')));
  }

  @override
  Widget build(BuildContext context) {
    // Check service status when building the UI
    _checkServiceStatus();
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          // appBar: AppBar(
          //   title: const Text("Order In Progress"),
          //   automaticallyImplyLeading: false, // Hides the back button
          //   actions: [
          //     IconButton(
          //       icon: const Icon(Icons.stop_circle_outlined),
          //       onPressed: _stopService,
          //       tooltip: 'Stop Background Service',
          //     ),
          //   ],
          // ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card with improved design
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
                        colors: [
                          Colors.white,
                          isTracking
                              ? Colors.green.withOpacity(0.05)
                              : Colors.grey.withOpacity(0.05),
                        ],
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isTracking
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isTracking
                                      ? Icons.delivery_dining
                                      : Icons.do_not_disturb,
                                  color: isTracking
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Delivery Status',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isTracking
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isTracking
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isTracking
                                      ? Icons.check_circle
                                      : Icons.offline_bolt,
                                  color: isTracking
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    isTracking
                                        ? 'You are currently ONLINE'
                                        : 'You are currently OFFLINE',
                                    style: TextStyle(
                                      color: isTracking
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Container(
                          //   padding: const EdgeInsets.symmetric(
                          //     horizontal: 16,
                          //     vertical: 10,
                          //   ),
                          //   decoration: BoxDecoration(
                          //     color: serviceRunning
                          //         ? Colors.green.withOpacity(0.1)
                          //         : Colors.red.withOpacity(0.1),
                          //     borderRadius: BorderRadius.circular(12),
                          //     border: Border.all(
                          //       color: serviceRunning
                          //           ? Colors.green.withOpacity(0.3)
                          //           : Colors.red.withOpacity(0.3),
                          //       width: 1,
                          //     ),
                          //   ),
                          // child: Row(
                          //   children: [
                          // Icon(
                          //   serviceRunning
                          //       ? Icons.cloud_done
                          //       : Icons.cloud_off,
                          //   color: serviceRunning
                          //       ? Colors.green
                          //       : Colors.red,
                          //   size: 20,
                          // ),
                          // const SizedBox(width: 10),
                          // Flexible(
                          //   child: Text(
                          //     serviceRunning
                          //         ? 'Background service is RUNNING'
                          //         : 'Background service is STOPPED',
                          //     style: TextStyle(
                          //       color: serviceRunning
                          //           ? Colors.green
                          //           : Colors.red,
                          //       fontWeight: FontWeight.bold,
                          //     ),
                          //     overflow: TextOverflow.ellipsis,
                          //   ),
                          // ),
                          // ],
                          // ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_isCheckingPermission)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 16.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            "Checking permissions...",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 30),
                // Waiting for orders section with improved design
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            size: 64,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Waiting for new delivery requests...",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTracking
                              ? "You're online and ready to receive orders"
                              : "Go online to start receiving delivery requests",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.deepOrange,
            elevation: 6,
            highlightElevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            icon: const Icon(Icons.directions, size: 24),
            label: const Text(
              "Get Directions",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: () {
              _openGoogleMapDirections(lat: 22.5726, lng: 88.3639);
            },
          ),
        ),

        // New Order Popup Overlay
        if (_showNewOrderPopup)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.orange.withOpacity(0.1)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Icon Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          size: 64,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title with decorative elements
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 2,
                            width: 40,
                            color: Colors.deepOrange.withOpacity(0.5),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _orderData['title'] ?? "New Delivery Request",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 2,
                            width: 40,
                            color: Colors.deepOrange.withOpacity(0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                        child: Text(
                          _orderData['body'] ??
                              "You have a new delivery offer.",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _rejectOrder,
                            icon: const Icon(Icons.close),
                            label: const Text("Reject"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                              shadowColor: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _acceptOrder,
                            icon: const Icon(Icons.check),
                            label: const Text("Accept"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                              shadowColor: Colors.green.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
