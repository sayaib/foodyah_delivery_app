// lib/order_in_progress_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import the services
import 'package:foodyah_delivery_app/services/location_permission_service.dart';
import 'package:foodyah_delivery_app/services/tracking_status_service.dart';
import 'package:foodyah_delivery_app/services/api_client.dart';
import 'package:foodyah_delivery_app/services/shared_preferences_manager.dart';
import 'package:foodyah_delivery_app/Card/OrderDetailsCard.dart';

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
  bool _isLoadingOrder = false;
  bool _hasOrderData = false;
  Map<String, dynamic> _orderData = {};
  final FlutterBackgroundService _service = FlutterBackgroundService();
  final SharedPreferencesManager _prefsManager = SharedPreferencesManager();
  final _storage = const FlutterSecureStorage();
  String _driverId = "";
  String _orderId = "";
  final TrackingStatusService _trackingStatusService = TrackingStatusService();

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupServiceListener();
    _loadDriverId();
    _loadOrderId();

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

  // Load order ID from SharedPreferences
  Future<void> _loadOrderId() async {
    final orderId = _prefsManager.currentOrderId;

    if (orderId != null && orderId.isNotEmpty) {
      setState(() {
        _orderId = orderId;
      });

      // Fetch order details from API
      _fetchOrderDetails(orderId);
    }
  }

  // Fetch order details from API
  Future<void> _fetchOrderDetails(String orderId) async {
    if (orderId.isEmpty) return;

    setState(() {
      _isLoadingOrder = true;
    });

    try {
      // Call the API to get order details
      final response = await ApiClient.get(
        '/getCurrentOrderForDeliveryBoy/$orderId',
      );
      debugPrint('API Response: $response');
      debugPrint('Response type: ${response.runtimeType}');
      
      if (mounted) {
        // Handle different response formats
        Map<String, dynamic> orderData;
        
        if (response is String) {
          // If response is a string, try to parse it as JSON
          try {
            orderData = jsonDecode(response);
            debugPrint('Parsed string response to JSON: $orderData');
          } catch (e) {
            debugPrint('Failed to parse string response: $e');
            orderData = {'error': 'Invalid response format'};
          }
        } else if (response is Map) {
          // Check if the response has a nested 'order' object
          if (response['success'] == true && response['order'] != null) {
            if (response['order'] is Map) {
              orderData = Map<String, dynamic>.from(response['order']);
            } else {
              debugPrint('Order is not a Map: ${response['order']}');
              orderData = {'error': 'Invalid order format'};
            }
          } else {
            orderData = Map<String, dynamic>.from(response);
          }
        } else {
          debugPrint('Response is neither String nor Map: $response');
          orderData = {'error': 'Unknown response format'};
        }
        
        debugPrint('Final orderData: $orderData');
        debugPrint('orderData type: ${orderData.runtimeType}');
        debugPrint('orderData keys: ${orderData.keys.toList()}');
            
        setState(() {
          _orderData = orderData;
          _hasOrderData = true;
          _isLoadingOrder = false;
        });
        debugPrint(
          'Order details fetched successfully: ${orderData['_id'] ?? 'Unknown ID'}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOrder = false;
        });
        debugPrint('Error fetching order details: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load order details: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _forceRefreshTrackingStatus() async {
    // This ensures the UI shows the correct tracking status when the app is reopened
    final status = _prefsManager.isTracking;

    // Update both local state and service
    if (mounted) {
      setState(() {
        isTracking = status;
        debugPrint(
          'OrderInProgressPage: Force refreshed tracking status to $isTracking',
        );
      });
    }

    // Also check if service is actually running
    final isRunning = await _service.isRunning();
    if (mounted) {
      setState(() {
        serviceRunning = isRunning;
        debugPrint(
          'OrderInProgressPage: Force refreshed service status to $serviceRunning',
        );
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
    // Removed showDialog listener to prevent duplicate popups
    // The delivery request popups are already handled in dashboard_page.dart
  }

  Future<void> _initialize() async {
    await _loadTrackingStatus();
    await _checkServiceStatus();
  }

  Future<void> _loadTrackingStatus() async {
    if (!mounted) return;
    final status = _prefsManager.isTracking;
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
        await _prefsManager.setIsTracking(true);

        // Update tracking status service
        await _trackingStatusService.updateTrackingStatus(true);

        // Save driver ID to shared preferences for background service
        await _prefsManager.setDriverId(_driverId);

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
        await _prefsManager.setIsTracking(false);

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
    await _prefsManager.setIsTracking(false);

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
    // Store order information using global state manager
    final orderData = _orderData;
    
    await _prefsManager.setOrderData(
      orderId: orderData['_id'],
      restaurantId: orderData['restaurantId'],
      restaurantAddress: orderData['restaurantFullAddress'],
      customerAddress: orderData['userFullAddress'],
    );

    // Start location tracking if not already started
    if (!isTracking) {
      _toggleTracking(true);
    } else {
      // If tracking is already on, just make sure driver ID is set
      await _prefsManager.setDriverId(_driverId);
    }

    // Signal background to start emitting location with driver ID and order info
    // Make sure we're passing the correct order data to the background service
    _service.invoke("startLocationTracking", {
      'orderId': orderData['_id'] ?? '',
      'restaurantId': orderData['restaurantId'] ?? '',
      'restaurantAddress': orderData['restaurantFullAddress'] ?? '',
      'customerAddress': orderData['userFullAddress'] ?? ''
    });

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
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isTracking
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isTracking ? Colors.green : Colors.grey).withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  gradient: LinearGradient(
                                    colors: [
                                      (isTracking ? Colors.green : Colors.grey).withOpacity(0.2),
                                      (isTracking ? Colors.green : Colors.grey).withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Icon(
                                  isTracking
                                      ? Icons.delivery_dining
                                      : Icons.do_not_disturb,
                                  color: isTracking
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  const Text(
                                    'Delivery Status',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: isTracking ? Colors.green : Colors.grey,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isTracking ? Colors.green : Colors.grey).withOpacity(0.3),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isTracking
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isTracking
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isTracking ? Colors.green : Colors.grey).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  (isTracking ? Colors.green : Colors.grey).withOpacity(0.2),
                                  (isTracking ? Colors.green : Colors.grey).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isTracking ? Colors.green : Colors.grey).withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isTracking
                                        ? Icons.check_circle
                                        : Icons.offline_bolt,
                                    color: isTracking
                                        ? Colors.green
                                        : Colors.grey,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    isTracking
                                        ? 'You are currently ONLINE'
                                        : 'You are currently OFFLINE',
                                    style: TextStyle(
                                      color: isTracking
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
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
                // Order details or waiting for orders section
                Expanded(
                  child: _isLoadingOrder
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.deepOrange,
                          ),
                        )
                      : _hasOrderData
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Current Order Details",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[700],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.refresh,
                                        color: Colors.deepOrange,
                                      ),
                                      onPressed: () {
                                        if (_orderId.isNotEmpty) {
                                          _fetchOrderDetails(_orderId);
                                        }
                                      },
                                      tooltip: 'Refresh order details',
                                    ),
                                  ],
                                ),
                              ),
                              OrderDetailsCard(
                                orderData: _orderData,
                                onOrderDelivered: () {
                                  // Refresh the page after order is delivered
                                  setState(() {
                                    _orderId = "";
                                    _orderData = {};
                                    _hasOrderData = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_orderData.containsKey('userFullAddress') &&
                                  _orderData['userFullAddress'] != null)
                                GestureDetector(
                                  onTap: () {
                                    // Get customer coordinates if available
                                    double? lat;
                                    double? lng;
                                    
                                    // Check if userLocation coordinates exist (primary key for customer location)
                                    if (_orderData.containsKey('userLocation') && 
                                        _orderData['userLocation'] != null &&
                                        _orderData['userLocation']['coordinates'] != null &&
                                        _orderData['userLocation']['coordinates'].length >= 2) {
                                      // Format: {type: Point, coordinates: [longitude, latitude]}
                                      lng = _orderData['userLocation']['coordinates'][0];
                                      lat = _orderData['userLocation']['coordinates'][1];
                                    }
                                    // If no userLocation coordinates, check customerLocation coordinates
                                    else if (_orderData.containsKey('customerLocation') && 
                                        _orderData['customerLocation'] != null &&
                                        _orderData['customerLocation']['coordinates'] != null &&
                                        _orderData['customerLocation']['coordinates'].length >= 2) {
                                      // Format: {type: Point, coordinates: [longitude, latitude]}
                                      lng = _orderData['customerLocation']['coordinates'][0];
                                      lat = _orderData['customerLocation']['coordinates'][1];
                                    }
                                    // If no customer coordinates, check delivery coordinates
                                    else if (_orderData.containsKey('deliveryLocation') && 
                                        _orderData['deliveryLocation'] != null &&
                                        _orderData['deliveryLocation']['coordinates'] != null &&
                                        _orderData['deliveryLocation']['coordinates'].length >= 2) {
                                      lng = _orderData['deliveryLocation']['coordinates'][0];
                                      lat = _orderData['deliveryLocation']['coordinates'][1];
                                    }

                                    if (lat != null && lng != null) {
                                      _openGoogleMapDirections(lat: lat, lng: lng);
                                    } else {
                                      // Fallback to default coordinates or show error
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No location coordinates available for this address',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Card(
                                    elevation: 6,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: Colors.deepOrange.withOpacity(0.3), width: 1),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [Colors.white, Colors.orange.withOpacity(0.15)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.person_pin_circle,
                                                  color: Colors.deepOrange,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  "Customer Address",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.deepOrange.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.deepOrange.withOpacity(0.1),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    children: const [
                                                      Icon(
                                                        Icons.directions,
                                                        color: Colors.deepOrange,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Directions",
                                                        style: TextStyle(
                                                          color: Colors.deepOrange,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              _orderData['userFullAddress'] ??
                                                  'No address provided',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_orderData.containsKey('restaurantFullAddress') &&
                                  _orderData['restaurantFullAddress'] != null)
                                GestureDetector(
                                  onTap: () {
                                    // Get restaurant coordinates if available
                                    double? lat;
                                    double? lng;
                                    
                                    // Check if restaurantLocation coordinates exist
                                    if (_orderData.containsKey('restaurantLocation') && 
                                        _orderData['restaurantLocation'] != null &&
                                        _orderData['restaurantLocation']['coordinates'] != null &&
                                        _orderData['restaurantLocation']['coordinates'].length >= 2) {
                                      // Format: {type: Point, coordinates: [longitude, latitude]}
                                      lng = _orderData['restaurantLocation']['coordinates'][0];
                                      lat = _orderData['restaurantLocation']['coordinates'][1];
                                    }
                                    
                                    if (lat != null && lng != null) {
                                      _openGoogleMapDirections(lat: lat, lng: lng);
                                    } else {
                                      // Fallback to default coordinates or show error
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'No location coordinates available for this restaurant',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Card(
                                    elevation: 6,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: Colors.deepOrange.withOpacity(0.3), width: 1),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [Colors.white, Colors.orange.withOpacity(0.15)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.restaurant,
                                                  color: Colors.deepOrange,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  "Restaurant Address",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.deepOrange.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.deepOrange.withOpacity(0.1),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    children: const [
                                                      Icon(
                                                        Icons.directions,
                                                        color: Colors.deepOrange,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Directions",
                                                        style: TextStyle(
                                                          color: Colors.deepOrange,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              _orderData['restaurantFullAddress'] ??
                                                  'No address provided',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepOrange.withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepOrange.withOpacity(0.2),
                                      Colors.deepOrange.withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delivery_dining,
                                  size: 72,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepOrange.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  "Waiting for new delivery requests...",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isTracking ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isTracking ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isTracking
                                      ? "You're online and ready to receive orders"
                                      : "Go online to start receiving delivery requests",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isTracking ? Colors.green.shade800 : Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Floating action button removed as directions are now available in the address cards
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
