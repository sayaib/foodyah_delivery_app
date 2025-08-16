import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:foodyah_delivery_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'order_in_progress_page.dart';
import 'PayoutPage.dart';
import 'ProfilePage.dart';
import '../SettingsPage.dart';
import '../services/location_permission_service.dart';
import '../services/tracking_status_service.dart';
import '../services/shared_preferences_manager.dart';

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
  final SharedPreferencesManager _prefsManager = SharedPreferencesManager();

  late List<Widget> _pages;

  void _initializePages() {
    _pages = [
      const OrderInProgressPage(),
      const PayoutPage(),
      const ProfilePage(),
      const SettingsPage(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _initializePages();
    // Start listening for events from the background service as soon as
    // the dashboard is visible.
    _initialize();
    listenToBackgroundService();
    _loadDriverId();

    // Ensure tracking status is properly initialized
    _forceRefreshTrackingStatus();

    // Listen to tracking status changes with debouncing
    _trackingStatusService.trackingStatusStream.distinct().listen((status) {
      if (mounted && isTracking != status) {
        setState(() {
          isTracking = status;
          debugPrint(
            'Dashboard: isTracking updated from stream to $isTracking',
          );
        });
      }
    });

    // Listen to service running status changes with debouncing
    _trackingStatusService.serviceRunningStream.distinct().listen((status) {
      if (mounted && serviceRunning != status) {
        setState(() {
          serviceRunning = status;
          debugPrint(
            'Dashboard: serviceRunning updated from stream to $serviceRunning',
          );
        });
      }
    });
  }

  Future<void> _forceRefreshTrackingStatus() async {
    // This ensures the UI shows the correct tracking status when the app is reopened
    final status = _prefsManager.isTracking;

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
        debugPrint(
          'Dashboard: Force refreshed service status to $serviceRunning',
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
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
        // Reinitialize pages to force refresh, especially for OrderInProgressPage
        _initializePages();
      });
      // Refresh tracking status when switching tabs
      _loadTrackingStatus();
      _checkServiceStatus();
      debugPrint(
        'Dashboard: Tab switched to $index, refreshing status and pages',
      );

      // Force refresh the status after a short delay to ensure UI is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _checkServiceStatus();
        }
      });
    }
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
      debugPrint('Dashboard: isTracking updated to $isTracking');
    });
    // Also update the tracking status service
    await _trackingStatusService.updateTrackingStatus(status);
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
        }

        debugPrint("Invoking startLocationTracking...");
        _service.invoke("startLocationTracking");
        setState(() => isTracking = true);
      } else {
        // If turning OFF, stop both location tracking and background service
        await _prefsManager.setIsTracking(false);

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
    // Store order information using global state manager
    await _prefsManager.setOrderData(
      orderId: _orderData['orderId'],
      restaurantId:
          _orderData['restaurantName'], // Note: using restaurantName as restaurantId for compatibility
      restaurantAddress: _orderData['restaurantAddress'],
      customerAddress: _orderData['customerAddress'],
    );

    // Start location tracking if not already started
    if (!isTracking) {
      _toggleTracking(true);
    } else {
      // If tracking is already on, just make sure driver ID is set
      await _prefsManager.setDriverId(_driverId);
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
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.textOnPrimary,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 28,
                    // If the logo image doesn't exist, use an icon instead
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.delivery_dining,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Flexible(
                  child: Text(
                    'Foodyah Delivery',
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.textOnPrimary,
                      fontWeight: FontWeight.w700,
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
                margin: const EdgeInsets.only(
                  right: AppTheme.spacingM,
                  bottom: AppTheme.spacingS,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                decoration: BoxDecoration(
                  color: isTracking
                      ? AppTheme.successColor.withOpacity(0.2)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCircular),
                  border: Border.all(
                    color: isTracking
                        ? AppTheme.successColor
                        : Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTracking
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isTracking
                          ? AppTheme.successColor
                          : Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      isTracking ? 'Online' : 'Offline',
                      style: AppTheme.labelMedium.copyWith(
                        color: isTracking
                            ? AppTheme.successColor
                            : Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Switch(
                      value: isTracking,
                      onChanged: _isCheckingPermission
                          ? null
                          : (value) => _toggleTracking(value),
                      activeColor: AppTheme.successColor,
                      activeTrackColor: AppTheme.successColor.withOpacity(0.3),
                      inactiveThumbColor: Colors.white.withOpacity(0.8),
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusXL),
                topRight: Radius.circular(AppTheme.radiusXL),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusXL),
                topRight: Radius.circular(AppTheme.radiusXL),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: AppTheme.surfaceColor,
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: AppTheme.textSecondary,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 12,
                unselectedFontSize: 10,
                iconSize: 20,
                elevation: 0,
                selectedLabelStyle: AppTheme.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
                unselectedLabelStyle: AppTheme.labelSmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
                items: [
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 0
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: _selectedIndex == 0
                            ? Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        color: _selectedIndex == 0
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                    label: "Home",
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 1
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: _selectedIndex == 1
                            ? Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: _selectedIndex == 1
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                    label: "Payout",
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 2
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: _selectedIndex == 2
                            ? Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: _selectedIndex == 2
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                    label: "Profile",
                  ),
                  BottomNavigationBarItem(
                    icon: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 3
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: _selectedIndex == 3
                            ? Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        color: _selectedIndex == 3
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                    label: "Settings",
                  ),
                ],
              ),
            ),
          ),
        ),

        // New Order Popup Overlay with improved design
        if (_showNewOrderPopup)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(AppTheme.spacingM),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                ),
                elevation: AppTheme.elevationXL,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.surfaceColor,
                        AppTheme.secondaryColor.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated icon container
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          decoration: BoxDecoration(
                            gradient: AppTheme.secondaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.secondaryColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.delivery_dining,
                            size: 48,
                            color: AppTheme.textOnPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        // Title with decorative elements
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingL,
                            vertical: AppTheme.spacingM,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusL,
                            ),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _orderData['title'] ?? "New Delivery Request",
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        // Order details
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          decoration: AppTheme.elevatedCardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _orderData['body'] ??
                                    "You have a new delivery offer.",
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_orderData['restaurantName'] != null) ...[
                                const SizedBox(height: AppTheme.spacingM),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.restaurant,
                                        size: 16,
                                        color: AppTheme.secondaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: Text(
                                        "Restaurant: ${_orderData['restaurantName']}",
                                        style: AppTheme.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_orderData['restaurantAddress'] != null) ...[
                                const SizedBox(height: AppTheme.spacingM),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: Text(
                                        "Pickup: ${_orderData['restaurantAddress']}",
                                        style: AppTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (_orderData['customerAddress'] != null) ...[
                                const SizedBox(height: AppTheme.spacingM),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppTheme.spacingS,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.infoColor.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusS,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.pin_drop,
                                        size: 16,
                                        color: AppTheme.infoColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spacingM),
                                    Expanded(
                                      child: Text(
                                        "Delivery: ${_orderData['customerAddress']}",
                                        style: AppTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXL),
                        // Action buttons with improved design
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _rejectOrder,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text("Reject"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.surfaceColor,
                                  foregroundColor: AppTheme.errorColor,
                                  elevation: AppTheme.elevationS,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingL,
                                    vertical: AppTheme.spacingM,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                    side: BorderSide(
                                      color: AppTheme.errorColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  textStyle: AppTheme.labelLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _acceptOrder,
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text("Accept"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.successColor,
                                  foregroundColor: AppTheme.textOnPrimary,
                                  elevation: AppTheme.elevationM,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingL,
                                    vertical: AppTheme.spacingM,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusM,
                                    ),
                                  ),
                                  textStyle: AppTheme.labelLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
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
