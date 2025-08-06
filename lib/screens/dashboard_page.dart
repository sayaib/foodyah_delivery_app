import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'order_in_progress_page.dart';
import 'PayoutPage.dart';
import 'ProfilePage.dart';
import '../SettingsPage.dart';
import '../services/location_permission_service.dart';
import '../services/tracking_status_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool isTracking = false;
  bool serviceRunning = false;
  bool _isCheckingPermission = false;
  String _driverId = "";
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic> _orderData = {};
  bool _showNewOrderPopup = false;
  final TrackingStatusService _trackingStatusService = TrackingStatusService();

  final List<Widget> _pages = const [
    OrderInProgressPage(),
    PayoutPage(),
    ProfilePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Start listening for events from the background service as soon as
    // the dashboard is visible.
    _initialize();
    listenToBackgroundService();
    _loadDriverId();
    
    // Ensure tracking status is properly initialized
    _forceRefreshTrackingStatus();
    
    // Listen to tracking status changes
    _trackingStatusService.trackingStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          isTracking = status;
          debugPrint('Dashboard: isTracking updated from stream to $isTracking');
        });
      }
    });
    
    // Listen to service running status changes
    _trackingStatusService.serviceRunningStream.listen((status) {
      if (mounted) {
        setState(() {
          serviceRunning = status;
          debugPrint('Dashboard: serviceRunning updated from stream to $serviceRunning');
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
        debugPrint('Dashboard: Force refreshed tracking status to $isTracking');
      });
    }
    
    // Also check if service is actually running
    final isRunning = await _service.isRunning();
    if (mounted) {
      setState(() {
        serviceRunning = isRunning;
        debugPrint('Dashboard: Force refreshed service status to $serviceRunning');
      });
    }
    
    // Update tracking status service
    await _trackingStatusService.updateTrackingStatus(status);
    _trackingStatusService.updateServiceRunningStatus(isRunning);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh status when dashboard becomes visible
    _loadTrackingStatus();
    _checkServiceStatus();
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh status when widget updates
    _loadTrackingStatus();
    _checkServiceStatus();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh tracking status when switching tabs
    _loadTrackingStatus();
    _checkServiceStatus();
    debugPrint('Dashboard: Tab switched to $index, refreshing status');
    
    // Force refresh the status after a short delay to ensure UI is updated
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _checkServiceStatus();
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
      debugPrint('Dashboard: isTracking updated to $isTracking');
    });
    // Also update the tracking status service
    await _trackingStatusService.updateTrackingStatus(status);
  }

  // Add a timestamp to track when we last checked the service status
  DateTime _lastServiceCheck = DateTime.now().subtract(const Duration(seconds: 1));
  
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
        debugPrint('Dashboard: serviceRunning updated to $serviceRunning');
      });
      // Also update the service running status in the tracking status service
      _trackingStatusService.updateServiceRunningStatus(isRunning);
    }
  }

  Future<void> _loadDriverId() async {
    final id = await _storage.read(key: 'user_id') ?? 'driver_007';
    setState(() {
      _driverId = id;
    });
  }

  void listenToBackgroundService() {
    // Listen for the 'showDialog' event from the background service
    FlutterBackgroundService().on('showDialog').listen((event) {
      if (event == null) return;

      // When the event is received, set state to show the popup
      setState(() {
        _showNewOrderPopup = true;
        _orderData = event;
      });
    });
  }

  Future<void> _toggleTracking(bool value) async {
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
        }

        debugPrint("Invoking startLocationTracking...");
        _service.invoke("startLocationTracking");
        setState(() => isTracking = true);
      } else {
        // If turning OFF, stop both location tracking and background service
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isTracking', false);
        
        // Update tracking status service
        await _trackingStatusService.updateTrackingStatus(false);

        // First stop location tracking
        _service.invoke("stopLocationTracking");
        debugPrint("UI: Invoked stopLocationTracking");

        // Then stop the entire background service
        if (serviceRunning) {
          _service.invoke("stopService");
          debugPrint("UI: Invoked stopService");
          // Wait a moment for the service to fully stop
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() => serviceRunning = false);
        }

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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.deepOrange,
            elevation: 4,
            shadowColor: Colors.deepOrange.withOpacity(0.5),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 32,
                    // If the logo image doesn't exist, use an icon instead
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.delivery_dining,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Foodyah Delivery',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Location tracking toggle switch with improved design
              Container(
                margin: const EdgeInsets.only(right: 16, bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isTracking
                      ? const Color.fromARGB(
                          255,
                          110,
                          245,
                          115,
                        ).withOpacity(0.2)
                      : const Color.fromARGB(
                          255,
                          213,
                          213,
                          213,
                        ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isTracking ? Colors.green : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        isTracking ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: isTracking ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isTracking,
                      onChanged: _isCheckingPermission
                          ? null
                          : (value) => _toggleTracking(value),
                      activeColor: Colors.green,
                      activeTrackColor: Colors.green.withOpacity(0.5),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              if (_isCheckingPermission)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          body: _pages[_selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: Colors.white,
                selectedItemColor: Colors.deepOrange,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 14,
                unselectedFontSize: 12,
                iconSize: 24,
                elevation: 0,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 0
                            ? Colors.deepOrange.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.home_rounded),
                    ),
                    label: "Home",
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 1
                            ? Colors.deepOrange.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded),
                    ),
                    label: "Payout",
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 2
                            ? Colors.deepOrange.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded),
                    ),
                    label: "Profile",
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 3
                            ? Colors.deepOrange.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.settings_rounded),
                    ),
                    label: "Setting",
                  ),
                ],
              ),
            ),
          ),
        ),

        // New Order Popup Overlay with improved design
        if (_showNewOrderPopup)
          Container(
            color: Colors.black.withOpacity(0.54),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.orange.shade50],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated icon container
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
                        const SizedBox(height: 24),
                        // Title with decorative elements
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.deepOrange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _orderData['title'] ?? "New Delivery Request",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Order details
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _orderData['body'] ??
                                    "You have a new delivery offer.",
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_orderData['restaurantName'] != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.restaurant,
                                      size: 18,
                                      color: Colors.deepOrange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Restaurant: ${_orderData['restaurantName']}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_orderData['restaurantAddress'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 18,
                                      color: Colors.deepOrange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Pickup: ${_orderData['restaurantAddress']}",
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_orderData['customerAddress'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.pin_drop,
                                      size: 18,
                                      color: Colors.deepOrange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Delivery: ${_orderData['customerAddress']}",
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Action buttons with improved design
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _rejectOrder,
                              icon: const Icon(Icons.close),
                              label: const Text("Reject"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.red),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _acceptOrder,
                              icon: const Icon(Icons.check),
                              label: const Text("Accept"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
          ),
      ],
    );
  }
}
